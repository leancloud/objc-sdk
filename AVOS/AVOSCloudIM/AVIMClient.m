//
//  AVIM.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMClient.h"
#import "AVIMClient_Internal.h"
#import "AVIMClientOpenOption.h"
#import "AVIMConversation_Internal.h"
#import "AVIMBlockHelper.h"
#import "UserAgent.h"
#import "AVIMConversation.h"
#import "AVIMRuntimeHelper.h"
#import "AVIMTypedMessage.h"
#import "AVIMTypedMessage_Internal.h"
#import "AVIMErrorUtil.h"
#import "AVIMConversationQuery.h"
#import "AVIMConversationQuery_Internal.h"
#import "AVObjectUtils.h"
#import "AVUtils.h"
#import "LCIMMessageCacheStoreSQL.h"
#import "LCIMMessageCacheStore.h"
#import "LCIMConversationCache.h"
#import "LCIMClientSessionTokenCacheStore.h"
#import "AVIMCommandCommon.h"
#import "LCObserver.h"
#import "SDMacros.h"
#import "AVIMUserOptions.h"
#import "AVPaasClient.h"

#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

static const int kMaxClientIdLength = 64;

static dispatch_queue_t imClientQueue = NULL;

static const NSUInteger kDistinctMessageIdArraySize = 10;

typedef NS_ENUM(NSInteger, LCIMClientLoginMethod) {
    LCIMClientLoginMethodID = 0,
    LCIMClientLoginMethodUser
};

typedef NS_ENUM(NSUInteger, LCIMClientSessionOptions) {
    LCIMClientSessionEnableMessagePatch = 1 << 0
};

NS_INLINE
BOOL isValidTag(NSString *tag) {
    return tag && ![tag isEqualToString:LCIMTagDefault];
}

@interface AVIMClient ()

@property (nonatomic, assign) LCIMClientLoginMethod loginMethod;
@property (nonatomic, copy) AVIMSignature *(^loginSignatureGetter)(AVIMClient *client);

@end

@implementation AVIMClient {
    NSMutableArray *_distinctMessageIdArray;
}

static BOOL AVIMClientHasInstantiated = NO;

+ (void)initialize {
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        imClientQueue = dispatch_queue_create("cn.leancloud.im", DISPATCH_QUEUE_SERIAL);
    });
}

+ (instancetype)alloc {
    AVIMClientHasInstantiated = YES;
    return [super alloc];
}

+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds {
    [AVIMWebSocketWrapper setTimeoutIntervalInSeconds:seconds];
}

+ (dispatch_queue_t)imClientQueue {
    return imClientQueue;
}

+ (BOOL)checkErrorForSignature:(AVIMSignature *)signature command:(AVIMGenericCommand *)command {
    if (signature.error) {
        AVIMCommandResultBlock callback = command.callback;
        if (callback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(command, nil, signature.error);
            });
        }
        return YES;
    } else {
        return NO;
    }
}

+ (void)_assertClientIdsIsValid:(NSArray *)clientIds {
    for (id item in clientIds) {
        if (![item isKindOfClass:[NSString class]]) {
            [NSException raise:NSInternalInconsistencyException format:@"ClientId should be NSString but %@ found.", NSStringFromClass([item class])];
            return;
        }
        if ([item length] == 0 || [item length] > kMaxClientIdLength) {
            [NSException raise:NSInternalInconsistencyException format:@"ClientId length should be in range [1, 64] but found '%@' length %lu.", item, (unsigned long)[item length]];
            return;
        }
    }
}

- (instancetype)init {
    self = [super init];

    if (self) {
        [self doInitialization];
    }

    return self;
}

- (instancetype)initWithClientId:(NSString *)clientId {
    return [self initWithClientId:clientId tag:nil];
}

- (instancetype)initWithClientId:(NSString *)clientId tag:(NSString *)tag {
    self = [super init];

    if (self) {
        _clientId = [clientId copy];
        _tag = [tag copy];

        [self doInitialization];
    }

    return self;
}

- (instancetype)initWithUser:(AVUser *)user {
    return [self initWithUser:user tag:nil];
}

- (instancetype)initWithUser:(AVUser *)user tag:(NSString *)tag {
    self = [super init];

    if (self) {
        _user = user;
        _tag = [tag copy];
        _loginMethod = LCIMClientLoginMethodUser;

        self.loginSignatureGetter = ^AVIMSignature *(AVIMClient *client) {
            return [AVIMClient getSignatureForSessionToken:client.user.sessionToken];
        };

        [self doInitialization];
    }

    return self;
}

- (void)doInitialization {
    _status = AVIMClientStatusNone;
    _conversations = [[NSMutableDictionary alloc] init];
    _stagedMessages = [[NSMutableDictionary alloc] init];
    _messageQueryCacheEnabled = YES;

    _distinctMessageIdArray = [NSMutableArray arrayWithCapacity:kDistinctMessageIdArraySize + 1];

    /* Observe push notification device token and websocket open event. */

    LCObserver *selfObserver = LCObserverMake(self);

    @weakify(self);

    [selfObserver
     addTarget:[AVInstallation currentInstallation]
     forKeyPath:NSStringFromSelector(@selector(deviceToken))
     options:0
     block:^(id object, id target, NSDictionary *change) {
         @strongify(self);
         [self registerPushChannelInBackground];
     }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        LCIMConversationCache *cache = [self conversationCache];
        [cache cleanAllExpiredConversations];
    });
}

- (LCIMConversationCache *)conversationCache {
    if (_conversationCache)
        return _conversationCache;

    @synchronized (self) {
        if (_conversationCache)
            return _conversationCache;

        _conversationCache = [[LCIMConversationCache alloc] initWithClientId:self.clientId];
        _conversationCache.client = self;

        return _conversationCache;
    }
}

- (NSString *)clientId {
    NSString *clientId = nil;

    switch (self.loginMethod) {
    case LCIMClientLoginMethodID:
        clientId = _clientId;
        break;
    case LCIMClientLoginMethodUser:
        clientId = self.user.objectId;
        break;
    }

    return clientId;
}

- (void)dealloc {
    AVLoggerInfo(AVLoggerDomainIM, @"AVIMClient dealloc.");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_socketWrapper decreaseObserverCount];
}

- (void)addConversation:(AVIMConversation *)conversation {
    return [_conversations setObject:conversation forKey:conversation.conversationId];
}

- (void)cacheConversations:(NSArray *)conversations {
    for (AVIMConversation *conversation in conversations) {
        [self addConversation:conversation];
    }
}

- (void)cacheConversationsIfNeeded:(NSArray *)conversations {
    for (AVIMConversation *conversation in conversations) {
        if (self.conversations[conversation.conversationId] == nil) {
            [self addConversation:conversation];
        }
    }
}

- (AVIMConversation *)conversationForId:(NSString *)conversationId {
    AVIMConversation *conversation = [_conversations objectForKey:conversationId];

    /* Disable conversation cache for consistent */

    /*
    if (!conversation) {
        conversation = [[self conversationCache] conversationForId:conversationId];

        if (conversation) {
            [self addConversation:conversation];
        }
    }
    */

    return conversation;
}

- (void)stageMessage:(AVIMMessage *)message {
    NSString *messageId = message.messageId;

    if (!messageId)
        return;

    [_stagedMessages setObject:message forKey:messageId];
}

- (AVIMMessage *)stagedMessageForId:(NSString *)messageId {
    if (!messageId)
        return nil;

    return [_stagedMessages objectForKey:messageId];
}

- (void)unstageMessageForId:(NSString *)messageId {
    if (!messageId)
        return;

    [_stagedMessages removeObjectForKey:messageId];
}

- (AVIMConversation *)conversationWithId:(NSString *)conversationId {
    if (!conversationId)
        return nil;

    @synchronized (self) {
        AVIMConversation *conversation = [self conversationForId:conversationId];

        if (!conversation) {
            conversation = [[AVIMConversation alloc] initWithConversationId:conversationId];
            conversation.imClient = self;
            [self addConversation:conversation];
        }

        return conversation;
    }
}

- (void)sendCommand:(AVIMGenericCommand *)command {
    [self sendCommand:command withBeforeSendingBlock:nil];
}

- (void)sendCommand:(AVIMGenericCommand *)command withBeforeSendingBlock:(void(^)(void))beforeSendingBlock {
    do {
        if (!_socketWrapper)
            break;

        if (_status == AVIMClientStatusClosing || _status == AVIMClientStatusClosed) {
            /* Allow to login in any case. */
            BOOL isSessionOpen = command.cmd == AVIMCommandType_Session && command.op == AVIMOpType_Open;

            if (!isSessionOpen)
                break;
        }

        if (beforeSendingBlock)
            beforeSendingBlock();

        [_socketWrapper sendCommand:command];

        return;
    } while(0);

    AVIMCommandResultBlock callback = command.callback;

    if (callback) {
        NSError *error = [AVIMErrorUtil errorWithCode:kAVIMErrorClientNotOpen
                                               reason:@"Client not open when send a message."];

        dispatch_async(dispatch_get_main_queue(), ^{
            callback(command, nil, error);
        });
    }
}

- (void)changeStatus:(AVIMClientStatus)status {
    AVIMClientStatus oldStatus = self.status;
    self.status = status;
    
    switch (status) {
        case AVIMClientStatusPaused:
            [self receivePaused];
            break;
            
        case AVIMClientStatusResuming:
            [self receiveResuming];
            break;
            
        case AVIMClientStatusOpened: {
            if (oldStatus == AVIMClientStatusResuming) {
                [self receiveResumed];
            }
        }
            break;
            
        default:
            break;
    }
}

+ (AVIMSignature *)getSignatureForSessionToken:(NSString *)sessionToken {
    AVIMSignature *signature = [[AVIMSignature alloc] init];
    AVPaasClient *RESTClient = [AVPaasClient sharedInstance];

    NSDictionary *parameters = @{ @"session_token" : sessionToken };
    NSURLRequest *request = [RESTClient requestWithPath:@"rtm/sign" method:@"POST" headers:nil parameters:parameters];

    [RESTClient
     performRequest:request
     success:^(NSHTTPURLResponse *response, id result) {
         signature.nonce = result[@"nonce"];
         signature.signature = result[@"signature"];
         signature.timestamp = [result[@"timestamp"] unsignedIntegerValue];
     }
     failure:^(NSHTTPURLResponse *response, id result, NSError *error) {
         signature.error = error;
     }
     wait:YES];

    return signature;
}

- (AVIMSignature *)signatureWithClientId:(NSString *)clientId conversationId:(NSString *)conversationId action:(NSString *)action actionOnClientIds:(NSArray *)clientIds {
    if ([action isEqualToString:@"open"] && self.loginSignatureGetter)
        return self.loginSignatureGetter(self);

    AVIMSignature *signature = nil;
    if ([_signatureDataSource respondsToSelector:@selector(signatureWithClientId:conversationId:action:actionOnClientIds:)]) {
        signature = [_signatureDataSource signatureWithClientId:clientId conversationId:conversationId action:action actionOnClientIds:clientIds];
    }
    return signature;
}

- (AVIMWebSocketWrapper *)socketWrapperForSecurity:(BOOL)security {
    AVIMWebSocketWrapper *socketWrapper = nil;
    
    if (security) {
        socketWrapper = [AVIMWebSocketWrapper sharedSecurityInstance];
    } else {
        socketWrapper = [AVIMWebSocketWrapper sharedInstance];
    }
    
    if (socketWrapper) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(websocketOpened:) name:AVIM_NOTIFICATION_WEBSOCKET_OPENED object:socketWrapper];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(websocketClosed:) name:AVIM_NOTIFICATION_WEBSOCKET_CLOSED object:socketWrapper];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(websocketReconnect:) name:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT object:socketWrapper];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveCommand:) name:AVIM_NOTIFICATION_WEBSOCKET_COMMAND object:socketWrapper];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveError:) name:AVIM_NOTIFICATION_WEBSOCKET_ERROR object:socketWrapper];
        
        [socketWrapper increaseObserverCount];
    }
    
    return socketWrapper;
}

- (void)updateLastPatchTimestamp:(int64_t)patchTimestamp {
    @synchronized (self) {
        if (patchTimestamp > _lastPatchTimestamp)
            _lastPatchTimestamp = patchTimestamp;
    }
}

- (void)updateLastUnreadTimestamp:(int64_t)unreadTimestamp {
    @synchronized (self) {
        if (unreadTimestamp > _lastUnreadTimestamp)
            _lastUnreadTimestamp = unreadTimestamp;
    }
}

- (AVIMGenericCommand *)openCommandWithAppId:(NSString *)appId
                                    clientId:(NSString *)clientId
                                         tag:(NSString *)tag
                                       force:(BOOL)force
                                    callback:(AVIMCommandResultBlock)callback
{
    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
    genericCommand.needResponse = YES;
    genericCommand.cmd = AVIMCommandType_Session;
    genericCommand.op = AVIMOpType_Open;
    genericCommand.appId = appId;
    genericCommand.peerId = clientId ?: _clientId;

    objc_setAssociatedObject(genericCommand, @selector(tag), tag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(genericCommand, @selector(force), @(force), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    AVIMSessionCommand *sessionCommand = [[AVIMSessionCommand alloc] init];
    NSString *sessionToken = [[LCIMClientSessionTokenCacheStore sharedInstance] sessionTokenForClientId:clientId tag:tag];

    /* When client is opened by user actively, ignore session token. */
    if (sessionToken && self.openTimes > 0) {
        sessionCommand.st = sessionToken;
    } else {
        sessionCommand.ua = @"ios" @"/" SDK_VERSION;
        sessionCommand.deviceToken = [AVInstallation currentInstallation].deviceToken ?: [AVUtils deviceUUID];

        if (!tag)
            tag = _tag;

        /* If tag is setted and not default, send it to server. */
        if (isValidTag(tag)) {
            sessionCommand.tag = tag;
        }
    }

    sessionCommand.configBitmap = LCIMClientSessionEnableMessagePatch;

    genericCommand.sessionMessage = sessionCommand;
    genericCommand.callback = callback;

    return genericCommand;
}

- (void)sendOpenCommand {
    AVIMGenericCommand *command = self.openCommand;

    if (!command) {
        AVLoggerError(AVLoggerDomainIM, @"Command not found, can not open client.");
        return;
    }

    int64_t lastPatchTimestamp  = self.lastPatchTimestamp;
    int64_t lastUnreadTimestamp = self.lastUnreadTimestamp;

    if (lastPatchTimestamp)
        command.sessionMessage.lastPatchTime = lastPatchTimestamp;
    if (lastUnreadTimestamp)
        command.sessionMessage.lastUnreadNotifTime = lastUnreadTimestamp;

    NSString *actionString = [AVIMCommandFormatter signatureActionForKey:command.op];
    AVIMSignature *signature = [self signatureWithClientId:command.peerId conversationId:nil action:actionString actionOnClientIds:nil];

    if ([AVIMClient checkErrorForSignature:signature command:command]) {
        AVLoggerError(AVLoggerDomainIM, @"Signature error, can not open client.");
        return;
    }
    /* NOTE: this will trigger an action that `command.sessionMessage.st = nil;` */
    [command avim_addRequiredKeyForSessionMessageWithSignature:signature];

    /* By default, we make non-initiative connection. */
    BOOL force = NO;

    if (self.openTimes == 0) {
        /* If force, we make an initiative login. */
        if ([objc_getAssociatedObject(command, @selector(force)) boolValue]) {
            force = YES;
        } else {
            /* However, if client has tag, we make a passive connection for the first time.
             * This connection may be rejected by server because of gone offline by the same client on other device.
             */
            BOOL hasTag = isValidTag(objc_getAssociatedObject(command, @selector(tag)));

            if (hasTag) {
                force = NO;
            } else {
                force = YES;
            }
        }
    }

    command.sessionMessage.r = !force;

    NSString *deviceToken = [AVInstallation currentInstallation].deviceToken;

    if (deviceToken)
        command.sessionMessage.deviceToken = deviceToken;

    OSAtomicIncrement32(&_openTimes);

    [self sendCommand:command];
}

- (void)registerPushChannelInBackground {
    dispatch_async(imClientQueue, ^{
        [self registerPushChannel];
    });
}

- (void)registerPushChannel {
    AVInstallation *currentInstallation = [AVInstallation currentInstallation];
    NSString *deviceToken = currentInstallation.deviceToken;

    if (deviceToken && self.onceOpened && (self.status == AVIMClientStatusOpened) && self.clientId) {
        /* Report current device token to cloud. */
        [self reportDeviceToken:deviceToken];

        /* Add client id to installation channels. */
        NSError *error = nil;
        [currentInstallation addUniqueObject:self.clientId forKey:@"channels"];
        [currentInstallation save:&error];

        if (error) {
            AVLoggerError(AVLoggerDomainIM, @"Register push channel failed: %@", error);
        }
    }
}

- (void)reportDeviceToken:(NSString *)deviceToken {
    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
    genericCommand.cmd = AVIMCommandType_Report;
    genericCommand.op = AVIMOpType_Upload;
    genericCommand.peerId = _clientId;

    AVIMReportCommand *reportCommand = [[AVIMReportCommand alloc] init];
    reportCommand.initiative = YES;
    reportCommand.type = @"token";
    reportCommand.data_p = deviceToken;

    [genericCommand avim_addRequiredKeyWithCommand:reportCommand];

    [self sendCommand:genericCommand];
}

- (void)cacheClientSessionTokenForCommand:(AVIMGenericCommand *)command tag:(NSString *)tag {
    LCIMClientSessionTokenCacheStore *cacheStore = [LCIMClientSessionTokenCacheStore sharedInstance];
    [cacheStore setSessionToken:command.sessionMessage.st TTL:command.sessionMessage.stTtl forClientId:command.peerId tag:tag];
}

- (void)clearClientSessionTokenForClientId:(NSString *)clientId {
    LCIMClientSessionTokenCacheStore *cacheStore = [LCIMClientSessionTokenCacheStore sharedInstance];
    [cacheStore clearForClientId:clientId];
}

- (BOOL)shouldRetryForCommand:(AVIMGenericCommand *)command {
    if ([command hasErrorMessage]) {
        AVIMErrorCommand *errorCommand = command.errorMessage;

        if (errorCommand.code == LCIMErrorCodeSessionTokenExpired) {
            [self clearClientSessionTokenForClientId:command.peerId];
            return YES;
        }
    }

    return NO;
}

- (void)openWithCallback:(AVIMBooleanResultBlock)callback {
    [self openWithOption:nil callback:callback];
}

- (void)openWithOption:(AVIMClientOpenOption *)option callback:(AVIMBooleanResultBlock)callback {
    BOOL force = NO;

    if (option)
        force = option.force;

    [self openWithClientId:self.clientId tag:self.tag force:force callback:callback];
}

- (void)openWithClientId:(NSString *)clientId tag:(NSString *)tag force:(BOOL)force callback:(AVIMBooleanResultBlock)callback {
    // Validate client id
    if (!clientId) {
        [NSException raise:NSInternalInconsistencyException format:@"Client id can not be nil."];
    } else if ([clientId length] > kMaxClientIdLength) {
        [NSException raise:NSInvalidArgumentException format:@"Client id length should less than %d characters.", kMaxClientIdLength];
    }

    // Validate application id
    NSString *appId = [AVOSCloud getApplicationId];

    if (!appId) {
        [NSException raise:NSInternalInconsistencyException format:@"Application id can not be nil."];
    }

    callback = [AVIMBlockHelper calledOnceBlockWithBooleanResultBlock:callback];

    @weakify(self);
    dispatch_async(imClientQueue, ^{
        @strongify(self);

        if (self.status != AVIMClientStatusOpened) {
            self.socketWrapper = [self socketWrapperForSecurity:YES];
            self.openTimes = 0;
            self.openCommand = [self openCommandWithAppId:appId
                                                 clientId:clientId
                                                      tag:tag
                                                    force:force
                                                 callback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error)
            {
                if (!error) {
                    self.onceOpened = YES;

                    [self changeStatus:AVIMClientStatusOpened];

                    [self registerPushChannel];

                    [AVIMBlockHelper callBooleanResultBlock:callback error:nil];

                    [self cacheClientSessionTokenForCommand:(AVIMGenericCommand *)inCommand tag:tag];
                } else {
                    [self changeStatus:AVIMClientStatusClosed];

                    if ([self shouldRetryForCommand:inCommand]) {
                        [self openWithClientId:clientId tag:tag force:force callback:callback];
                    } else {
                        [AVIMBlockHelper callBooleanResultBlock:callback error:error];
                    }
                }

                outCommand.callback = nil;
            }];

            [self changeStatus:AVIMClientStatusOpening];

            if ([self.socketWrapper isConnectionOpen]) {
                [self sendOpenCommand];
            } else {
                [self.socketWrapper openWebSocketConnectionWithCallback:^(BOOL succeeded, NSError *error) {
                    [self changeStatus:AVIMClientStatusNone];
                    [AVIMBlockHelper callBooleanResultBlock:callback error:error];
                    self.openCommand.callback = nil;
                }];
            }
        } else {
            [AVIMBlockHelper callBooleanResultBlock:callback error:nil];
        }
    });
}

- (void)removeWebSocketNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVIM_NOTIFICATION_WEBSOCKET_OPENED object:_socketWrapper];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVIM_NOTIFICATION_WEBSOCKET_COMMAND object:_socketWrapper];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT object:_socketWrapper];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVIM_NOTIFICATION_WEBSOCKET_CLOSED object:_socketWrapper];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVIM_NOTIFICATION_WEBSOCKET_ERROR object:_socketWrapper];
}

- (void)processClientStatusAfterWebSocketOffline {
    [self removeWebSocketNotification];
    [[AVInstallation currentInstallation] removeObject:_clientId forKey:@"channels"];
    if ([[AVInstallation currentInstallation] deviceToken]) {
        [[AVInstallation currentInstallation] saveInBackground];
    }
    [self changeStatus:AVIMClientStatusClosed];
}

- (void)closeWithCallback:(AVIMBooleanResultBlock)callback {
    dispatch_async(imClientQueue, ^{
        if (self.status == AVIMClientStatusClosed) {
            [AVIMBlockHelper callBooleanResultBlock:callback error:nil];
            return;
        }

        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
        genericCommand.needResponse = YES;
        genericCommand.cmd = AVIMCommandType_Session;
        genericCommand.peerId = _clientId;
        genericCommand.op = AVIMOpType_Close;
        AVIMSessionCommand *sessionCommand = [[AVIMSessionCommand alloc] init];
        [genericCommand avim_addRequiredKeyWithCommand:sessionCommand];
        [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
            if (!error) {
                [self processClientStatusAfterWebSocketOffline];
            }
            [AVIMBlockHelper callBooleanResultBlock:callback error:error];
        }];
        [self sendCommand:genericCommand withBeforeSendingBlock:^{
            [self changeStatus:AVIMClientStatusClosing];
        }];
    });
}

- (void)createConversationWithName:(NSString *)name clientIds:(NSArray *)clientIds callback:(AVIMConversationResultBlock)callback {
    [self createConversationWithName:name clientIds:clientIds attributes:nil options:AVIMConversationOptionNone callback:callback];
}

- (void)createConversationWithName:(NSString *)name clientIds:(NSArray *)clientIds attributes:(NSDictionary *)attr options:(AVIMConversationOption)options callback:(AVIMConversationResultBlock)callback {
    [[self class] _assertClientIdsIsValid:clientIds];
    dispatch_async(imClientQueue, ^{
        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
        genericCommand.needResponse = YES;
        NSMutableDictionary *attributes = nil;
        
        if (name || attr) {
            attributes = [[NSMutableDictionary alloc] init];
            
            if (name) [attributes setObject:name forKey:KEY_NAME];
            if (attr) [attributes setObject:attr forKey:KEY_ATTR];
        }
        
        BOOL transient = options & AVIMConversationOptionTransient;
        BOOL unique    = options & AVIMConversationOptionUnique;
        genericCommand.cmd = AVIMCommandType_Conv;
        genericCommand.peerId = _clientId;
        genericCommand.op = AVIMOpType_Start;

        AVIMConvCommand *convCommand = [[AVIMConvCommand alloc] init];

        if (attributes)
            convCommand.attr = [AVIMCommandFormatter JSONObjectWithDictionary:attributes];

        if (transient) {
            convCommand.transient = YES;
        } else {
            /* If conversation is non-transient, we insert creator to member list. */
            convCommand.mArray = [NSMutableArray arrayWithArray:({
                NSMutableSet *members = [NSMutableSet setWithArray:clientIds ?: @[]];
                [members addObject:self.clientId];
                [members allObjects];
            })];
        }
        
        if (unique) {
            convCommand.unique = YES;
        }

        [genericCommand avim_addRequiredKeyWithCommand:convCommand];
        
        NSString *acition = [AVIMCommandFormatter signatureActionForKey:genericCommand.op];
        AVIMSignature *signature = [self signatureWithClientId:genericCommand.peerId conversationId:nil action:acition actionOnClientIds:[convCommand.mArray copy]];
        [genericCommand avim_addRequiredKeyForConvMessageWithSignature:signature];
        if ([AVIMClient checkErrorForSignature:signature command:genericCommand]) {
            return;
        }
        [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
            if (!error) {
                AVIMConvCommand *conversationInCommand = inCommand.convMessage;
                AVIMConvCommand *conversationOutCommand = outCommand.convMessage;
                AVIMConversation *conversation = [self conversationWithId:conversationInCommand.cid];
                conversation.name = name;
                conversation.attributes = attr;
                conversation.creator = self.clientId;
                conversation.createAt = [AVObjectUtils dateFromString:[conversationInCommand cdate]];
                conversation.transient = conversationOutCommand.transient;
                [conversation addMembers:[conversationOutCommand.mArray copy]];
                [conversation addMember:outCommand.peerId];
                [self addConversation:conversation];
                [AVIMBlockHelper callConversationResultBlock:callback conversation:conversation error:nil];
            } else {
                [AVIMBlockHelper callConversationResultBlock:callback conversation:nil error:error];
            }
        }];

        [self sendCommand:genericCommand];
    });
}

- (AVIMConversation *)conversationWithKeyedConversation:(AVIMKeyedConversation *)keyedConversation {
    NSString *conversationId = keyedConversation.conversationId;
    AVIMConversation *conversation = [self conversationForId:conversationId];
    
    if (!conversation) {
        conversation = [self conversationWithId:conversationId];
        [conversation setKeyedConversation:keyedConversation];
    }
    
    return conversation;
}

- (AVIMConversationQuery *)conversationQuery {
    AVIMConversationQuery *query = [[AVIMConversationQuery alloc] init];
    query.client = self;
    return query;
}

- (void)queryOnlineClientsInClients:(NSArray<NSString *> *)clients callback:(AVIMArrayResultBlock)callback {
    dispatch_async(imClientQueue, ^{
        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];

        genericCommand.needResponse = YES;
        genericCommand.cmd = AVIMCommandType_Session;
        genericCommand.op = AVIMOpType_Query;
        genericCommand.peerId = _clientId;

        [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
            if (!error) {
                AVIMSessionCommand *sessionMessage = inCommand.sessionMessage;
                NSArray *onlineClients = sessionMessage.onlineSessionPeerIdsArray ?: @[];

                [AVIMBlockHelper callArrayResultBlock:callback array:onlineClients error:nil];
            } else {
                [AVIMBlockHelper callArrayResultBlock:callback array:@[] error:error];
            }
        }];

        AVIMSessionCommand *sessionCommand = [[AVIMSessionCommand alloc] init];
        sessionCommand.sessionPeerIdsArray = clients ?: @[];

        [genericCommand avim_addRequiredKeyWithCommand:sessionCommand];

        [self sendCommand:genericCommand];
    });
}

- (void)websocketOpened:(NSNotification *)notification {
    dispatch_async(imClientQueue, ^{
        [self sendOpenCommand];
    });
    [self changeStatus:AVIMClientStatusOpened];
}

- (void)websocketClosed:(NSNotification *)notification {
    [self changeStatus:AVIMClientStatusPaused];
}

- (void)websocketReconnect:(NSNotification *)notification {
    [self changeStatus:AVIMClientStatusResuming];
}

#pragma mark - process received messages

- (void)receiveCommand:(NSNotification *)notification {
    NSDictionary *dict = notification.userInfo;

    AVIMGenericCommand *command = [dict objectForKey:@"command"];
    // 因为是 notification ，可能收到其它 client 的广播
    // 根据文档，每条消息都带有 peerId
    /* Filter out other client's command */
    if ([command.peerId isEqualToString:self.clientId] == NO) {
        return;
    }
    
    AVIMCommandType commandType = command.cmd;
    switch (commandType) {
        case AVIMCommandType_Session:
            [self processSessionCommand:command];
            break;
        case AVIMCommandType_Direct:
            [self processDirectCommand:command];
            break;
        case AVIMCommandType_Unread:
            [self processUnreadCommand:command];
            break;
        case AVIMCommandType_Conv:
            [self processConvCommand:command];
            break;
        case AVIMCommandType_Rcp:
            [self processReceiptCommand:command];
            break;
        case AVIMCommandType_Patch:
            [self processPatchCommand:command];
            break;
            
        default:
            break;
    }
}

- (BOOL)insertDistinctMessageId:(NSString *)messageId {
    if ([_distinctMessageIdArray containsObject:messageId])
        return NO;

    [_distinctMessageIdArray addObject:messageId];

    NSUInteger count = _distinctMessageIdArray.count;

    if (count > kDistinctMessageIdArraySize)
        [_distinctMessageIdArray removeObjectsInRange:NSMakeRange(0, count - kDistinctMessageIdArraySize)];

    return YES;
}

- (void)processDirectCommand:(AVIMGenericCommand *)genericCommand {
    AVIMDirectCommand *directCommand = genericCommand.directMessage;

    /* Filter out the duplicated message. */
    if (directCommand.id_p && ![self insertDistinctMessageId:directCommand.id_p])
        return;

    AVIMMessage *message = nil;
    if (![directCommand.msg isKindOfClass:[NSString class]]) {
        AVLoggerError(AVOSCloudIMErrorDomain, @"Received an invalid message.");
        [self sendAckCommandAccordingToDirectCommand:directCommand andGenericCommand:genericCommand];
        return;
    }
    AVIMTypedMessageObject *messageObject = [[AVIMTypedMessageObject alloc] initWithJSON:directCommand.msg];
    if ([messageObject isValidTypedMessageObject]) {
        message = [AVIMTypedMessage messageWithMessageObject:messageObject];
    } else {
        message = [[AVIMMessage alloc] init];
    }
    message.content = directCommand.msg;
    message.sendTimestamp = directCommand.timestamp;
    message.conversationId = directCommand.cid;
    message.clientId = directCommand.fromPeerId;
    message.messageId = directCommand.id_p;
    message.status = AVIMMessageStatusDelivered;
    message.offline = directCommand.offline;
    message.hasMore = directCommand.hasMore;
    message.localClientId = self.clientId;
    message.transient = directCommand.transient;
    message.mentionAll = directCommand.mentionAll;
    message.mentionList = [directCommand.mentionPidsArray copy];

    if (directCommand.hasPatchTimestamp)
        message.updatedAt = [NSDate dateWithTimeIntervalSince1970:(directCommand.patchTimestamp / 1000.0)];
    
    [self receiveMessage:message];
    [self sendAckCommandAccordingToDirectCommand:directCommand andGenericCommand:genericCommand];
}

- (void)sendAckCommandAccordingToDirectCommand:(AVIMDirectCommand *)directCommand andGenericCommand:(AVIMGenericCommand *)genericCommand {
    if (directCommand.id_p && !directCommand.transient && ![directCommand.fromPeerId isEqualToString:_clientId]) {
        AVIMGenericCommand *genericAckCommand = [[AVIMGenericCommand alloc] init];
        genericCommand.needResponse = YES;
        genericAckCommand.cmd = AVIMCommandType_Ack;
        genericAckCommand.peerId = _clientId;

        AVIMAckCommand *ackCommand = [[AVIMAckCommand alloc] init];
        ackCommand.cid = directCommand.cid;
        ackCommand.mid = directCommand.id_p;
        [genericAckCommand avim_addRequiredKeyWithCommand:ackCommand];
        [self sendCommand:genericAckCommand];
    }
}

/*!
 * Fetch conversation if conversation not filled.
 * @param conversation Conversation which should be fetched.
 * @param block        Callback block.
 * @note  Block will be dispatched to main thread.
 */
- (void)fetchConversationIfNeeded:(AVIMConversation *)conversation withBlock:(void(^)(AVIMConversation *conversation))block {
    /* FIX: Check whether conversation unfaulting has been fired or not */
    if (conversation.createAt) {
        dispatch_async(dispatch_get_main_queue(), ^{
            block(conversation);
        });
    } else {
        __weak typeof(self) ws = self;
        [conversation fetchWithCallback:^(BOOL succeeded, NSError *error) {
            if (error) {
                AVLoggerError(AVLoggerDomainIM, @"Fetching conversation failed: %@", error);
            } else {
                [ws addConversation:conversation];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                block(conversation);
            });
        }];
    }
}

- (AVIMMessage *)messageWithUnreadTuple:(AVIMUnreadTuple *)unreadTuple {
    AVIMMessage *message = nil;

    NSString *messageId = unreadTuple.mid;
    NSString *messageBody = unreadTuple.data_p;
    NSString *conversationId = unreadTuple.cid;

    if (!messageId || !messageBody || !conversationId)
        return nil;

    NSString *fromPeerId = unreadTuple.from;
    int64_t timestemp = unreadTuple.timestamp;

    AVIMTypedMessageObject *messageObject = [[AVIMTypedMessageObject alloc] initWithJSON:messageBody];

    if ([messageObject isValidTypedMessageObject])
        message = [AVIMTypedMessage messageWithMessageObject:messageObject];
    else
        message = [[AVIMMessage alloc] init];

    message.content = messageBody;
    message.sendTimestamp = timestemp;
    message.conversationId = conversationId;
    message.clientId = fromPeerId;
    message.messageId = messageId;
    message.status = AVIMMessageStatusDelivered;
    message.localClientId = self.clientId;

    if (unreadTuple.hasPatchTimestamp)
        message.updatedAt = [NSDate dateWithTimeIntervalSince1970:unreadTuple.patchTimestamp / 1000.0];

    return message;
}

- (void)processUnreadCommand:(AVIMGenericCommand *)genericCommand {
    AVIMUnreadCommand *unreadCommand = genericCommand.unreadMessage;

    [self updateLastUnreadTimestamp:unreadCommand.notifTime];

    for (AVIMUnreadTuple *unreadTuple in unreadCommand.convsArray)
        [self processUnreadTuple:unreadTuple];
}

- (void)processUnreadTuple:(AVIMUnreadTuple *)unreadTuple {
    NSString *conversationId = unreadTuple.cid;
    AVIMConversation *conversation = [self conversationWithId:conversationId];

    if (!conversation) return;
    
    [self fetchConversationIfNeeded:conversation withBlock:^(AVIMConversation *conversation) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

        dictionary[@"unreadMessagesCount"] = @(unreadTuple.unread);
        dictionary[@"lastMessage"] = [self messageWithUnreadTuple:unreadTuple];

        if (unreadTuple.hasMentioned)
            dictionary[@"unreadMessagesMentioned"] = @(unreadTuple.mentioned);

        [self updateConversation:conversationId withDictionary:dictionary];

        /* For compatibility, we reserve this callback. It should be removed in future. */
        if ([self.delegate respondsToSelector:@selector(conversation:didReceiveUnread:)])
            [self.delegate conversation:conversation didReceiveUnread:unreadTuple.unread];
    }];
}

- (void)updateConversation:(NSString *)conversationId withDictionary:(NSDictionary *)dictionary {
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        LCIM_NOTIFY_PROPERTY_UPDATE(self.clientId, conversationId, key, value);
    }];
}

- (void)resetUnreadMessagesCountForConversation:(AVIMConversation *)conversation {
    [self updateConversation:conversation withDictionary:@{@"unreadMessagesCount": @(0)}];
}

- (void)removeCachedConversationForId:(NSString *)conversationId {
    [[self conversationCache] removeConversationForId:conversationId];
}

- (void)removeCachedMessagesForId:(NSString *)conversationId {
    NSString *clientId = self.clientId;

    if (clientId && conversationId) {
        LCIMMessageCacheStore *messageCacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:clientId conversationId:conversationId];
        [messageCacheStore cleanCache];
    }
}

- (void)passConvCommand:(AVIMGenericCommand *)genericCommand toConversation:(AVIMConversation *)conversation {
    AVIMConvCommand *convCommand = genericCommand.convMessage;
    AVIMOpType op = genericCommand.op;
    NSString *conversationId = convCommand.cid;
    NSString *initBy = convCommand.initBy;
    NSArray *members = [convCommand.mArray copy];
    
    LCIMConversationCache *conversationCache = [self conversationCache];
    switch (op) {
            
            // AVIMOpType_Joined = 32,
        case AVIMOpType_Joined:
            [conversation addMember:self.clientId];
            [self receiveInvitedFromConversation:conversation byClientId:initBy];
            break;
            
            // AVIMOpType_MembersJoined = 33,
        case AVIMOpType_MembersJoined:
            [conversation addMembers:members];
            [self receiveMembersAddedFromConversation:conversation clientIds:members byClientId:initBy];
            break;
            
            // AVIMOpType_Left = 39,
        case AVIMOpType_Left:
            [conversation removeMember:self.clientId];
            [self receiveKickedFromConversation:conversation byClientId:initBy];
            // Remove conversation and it's message from cache.
            [conversationCache removeConversationAndItsMessagesForId:conversationId];
            break;
            
            // AVIMOpType_MembersLeft = 40,
        case AVIMOpType_MembersLeft:
            [conversation removeMembers:members];
            [self receiveMembersRemovedFromConversation:conversation clientIds:members byClientId:initBy];
            break;
            
        default:
            break;
    }
}

- (void)processConvCommand:(AVIMGenericCommand *)command {
    NSString *conversationId = command.convMessage.cid;
    AVIMConversation *conversation = [self conversationWithId:conversationId];

    @weakify(self, ws);
    [self fetchConversationIfNeeded:conversation withBlock:^(AVIMConversation *conversation) {
        [ws passConvCommand:command toConversation:conversation];
    }];
}

- (LCIMMessageCacheStore *)messageCacheStoreForConversationId:(NSString *)conversationId {
    if (!conversationId)
        return nil;

    LCIMMessageCacheStore *cacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:self.clientId conversationId:conversationId];
    return cacheStore;
}

/**
 Get local message for given message ID and conversation ID.

 @param messageId      The message ID.
 @param conversationId The conversation ID.

 It will first find message from memory, if not found, find in cache store.

 @return A local message, or nil if not found.
 */
- (AVIMMessage *)localMessageForId:(NSString *)messageId
                    conversationId:(NSString *)conversationId
{
    if (!messageId)
        return nil;

    AVIMMessage *message = [self stagedMessageForId:messageId];

    if (message)
        return message;

    LCIMMessageCacheStore *cacheStore = [self messageCacheStoreForConversationId:conversationId];
    message = [cacheStore messageForId:messageId];

    return message;
}

- (void)cacheMessageWithoutBreakpoint:(AVIMMessage *)message
                       conversationId:(NSString *)conversationId
{
    if (!message.messageId)
        return;

    LCIMMessageCacheStore *cacheStore = [self messageCacheStoreForConversationId:conversationId];
    [cacheStore updateMessageWithoutBreakpoint:message];
}

- (void)processReceiptCommand:(AVIMGenericCommand *)genericCommand {
    AVIMRcpCommand *rcpCommand = genericCommand.rcpMessage;

    int64_t timestamp = rcpCommand.t;
    NSString *messageId = rcpCommand.id_p;
    NSString *conversationId = rcpCommand.cid;

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp / 1000.0];
    AVIMMessage *message = [self localMessageForId:messageId conversationId:conversationId];
    AVIMConversation *conversation = [self conversationWithId:conversationId];

    [self fetchConversationIfNeeded:conversation withBlock:^(AVIMConversation *conversation) {
        NSString *receiptKey = nil;

        /*
         NOTE:
         We need check the nullability of message.
         User may relaunch application before ack and receipt did receive, in which case,
         the sent message will be lost.
         */

        if (rcpCommand.read) {
            if (message) {
                message.readTimestamp = timestamp;
                message.status = AVIMMessageStatusRead;
                [self cacheMessageWithoutBreakpoint:message conversationId:conversationId];
            }

            receiptKey = NSStringFromSelector(@selector(lastReadAt));
        } else {
            if (message) {
                message.deliveredTimestamp = timestamp;
                message.status = AVIMMessageStatusDelivered;

                [self cacheMessageWithoutBreakpoint:message conversationId:conversationId];
                [self receiveMessageDelivered:message];
            }

            receiptKey = NSStringFromSelector(@selector(lastDeliveredAt));
        }

        [self updateReceipt:date
             ofConversation:conversation
                     forKey:receiptKey];
    }];
}

- (void)updateReceipt:(NSDate *)date
       ofConversation:(AVIMConversation *)conversation
               forKey:(NSString *)key
{
    if (!date || !conversation || !key)
        return;

    NSDate *oldDate = [conversation valueForKey:key];

    if (!oldDate || [oldDate compare:date] == NSOrderedAscending) {
        LCIM_NOTIFY_PROPERTY_UPDATE(self.clientId, conversation.conversationId, key, date);
    }
}

- (void)processSessionCommand:(AVIMGenericCommand *)genericCommand {
    AVIMOpType op = genericCommand.op;
    AVIMSessionCommand *sessionCommand = genericCommand.sessionMessage;
    if (op == AVIMOpType_Closed) {
        [self changeStatus:AVIMClientStatusClosed];
        /* If the closed command has a code, it's an offline command. */
        if (sessionCommand.code > 0) {
            if ([self.delegate respondsToSelector:@selector(client:didOfflineWithError:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self processClientStatusAfterWebSocketOffline];
                    [self.delegate client:self didOfflineWithError:[genericCommand avim_errorObject]];
                });
            }
        }
    }
}

- (void)processPatchCommand:(AVIMGenericCommand *)command {
    AVIMOpType op = command.op;

    if (op == AVIMOpType_Modify) {
        [self processMessagePatchCommand:command.patchMessage];
        [self sendACKForPatchCommand:command];
    }
}

- (void)processMessagePatchCommand:(AVIMPatchCommand *)command {
    NSArray<AVIMPatchItem *> *patchItems = command.patchesArray;

    for (AVIMPatchItem *patchItem in patchItems) {
        [self updateLastPatchTimestamp:patchItem.patchTimestamp];
        [self updateMessageCacheForPatchItem:patchItem];
        [self postNotificationForPatchItem:patchItem];
    }
}

- (void)updateMessageCacheForPatchItem:(AVIMPatchItem *)patchItem {
    NSString *conversationId = patchItem.cid;
    NSString *messageId      = patchItem.mid;

    LCIMMessageCacheStore *messageCacheStore = [self messageCacheStoreForConversationId:conversationId];
    AVIMMessage *message = [messageCacheStore messageForId:messageId];

    if (!message)
        return;

    NSDictionary<NSString *, id> *entries = @{
        LCIM_FIELD_PAYLOAD: patchItem.data_p,
        LCIM_FIELD_PATCH_TIMESTAMP: @((double)patchItem.patchTimestamp),
        @"mention_all": @(patchItem.mentionAll),
        @"mention_list": patchItem.mentionPidsArray ? [NSKeyedArchiver archivedDataWithRootObject:patchItem.mentionPidsArray] : [NSNull null],
    };

    [messageCacheStore updateEntries:entries
                        forMessageId:messageId];
}

- (void)postNotificationForPatchItem:(AVIMPatchItem *)patchItem {
    NSDictionary *userInfo = @{ @"patchItem": patchItem };

    [[NSNotificationCenter defaultCenter] postNotificationName:LCIMConversationMessagePatchNotification
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)sendACKForPatchCommand:(AVIMGenericCommand *)inCommand {
    int64_t lastPatchTimestamp = self.lastPatchTimestamp;

    if (!lastPatchTimestamp)
        return;

    AVIMGenericCommand *command = [[AVIMGenericCommand alloc] init];

    command.peerId = self.clientId;

    command.cmd = AVIMCommandType_Patch;
    command.op  = AVIMOpType_Modified;

    AVIMPatchCommand *patchMessage = [[AVIMPatchCommand alloc] init];
    patchMessage.lastPatchTime = self.lastPatchTimestamp;

    command.patchMessage = patchMessage;

    [self sendCommand:command];
}

- (void)array:(NSMutableArray *)array addObject:(id)object {
    if (!object) {
        object = [NSNull null];
    }
    [array addObject:object];
}

- (void)receiveMessage:(AVIMMessage *)message {
    NSString *conversationId = message.conversationId;
    
    /* Only cache non-transient message */
    if (!message.transient && self.messageQueryCacheEnabled) {
        LCIMMessageCacheStore *cacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:self.clientId conversationId:conversationId];
        
        /* If cache contains message, update message only */
        if ([cacheStore containMessage:message]) {
            [cacheStore updateMessageWithoutBreakpoint:message];
            return;
        }
        
        /* Otherwise, add message to cache and notify it to user */
        [cacheStore insertOrUpdateMessage:message withBreakpoint:YES];
    }
    
    AVIMConversation *conversation = [self conversationWithId:conversationId];
    
    __weak typeof(self) ws = self;
    
    [self fetchConversationIfNeeded:conversation withBlock:^(AVIMConversation *conversation) {
        [ws passMessage:message toConversation:conversation];
        [ws postNotificationForMessage:message];
    }];
}

- (void)postNotificationForMessage:(AVIMMessage *)message {
    NSDictionary *userInfo = @{ @"message": message };

    [[NSNotificationCenter defaultCenter] postNotificationName:LCIMConversationDidReceiveMessageNotification
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)passMessage:(AVIMMessage *)message toConversation:(AVIMConversation *)conversation {
    NSArray *arguments = @[conversation, message];
    
    if ([message isKindOfClass:[AVIMTypedMessage class]]) {
        if ([_delegate respondsToSelector:@selector(conversation:didReceiveTypedMessage:)]) {
            [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(conversation:didReceiveTypedMessage:) arguments:arguments];
        } else {
            [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(conversation:didReceiveCommonMessage:) arguments:arguments];
        }
    } else if ([message isKindOfClass:[AVIMMessage class]]) {
        [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(conversation:didReceiveCommonMessage:) arguments:arguments];
    }
}

- (void)receiveMessageDelivered:(AVIMMessage *)message {
    AVIMConversation *conversation = [self conversationWithId:message.conversationId];
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
    [self array:arguments addObject:conversation];
    [self array:arguments addObject:message];
    [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(conversation:messageDelivered:) arguments:arguments];
}

- (void)receiveInvitedFromConversation:(AVIMConversation *)conversation byClientId:(NSString *)clientId {
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
    [self array:arguments addObject:conversation];
    [self array:arguments addObject:clientId];
    [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(conversation:invitedByClientId:) arguments:arguments];
}

- (void)receiveKickedFromConversation:(AVIMConversation *)conversation byClientId:(NSString *)clientId {
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
    [self array:arguments addObject:conversation];
    [self array:arguments addObject:clientId];
    [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(conversation:kickedByClientId:) arguments:arguments];
}

- (void)receiveMembersAddedFromConversation:(AVIMConversation *)conversation clientIds:(NSArray *)clientIds byClientId:(NSString *)clientId {
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
    [self array:arguments addObject:conversation];
    [self array:arguments addObject:clientIds];
    [self array:arguments addObject:clientId];
    [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(conversation:membersAdded:byClientId:) arguments:arguments];
}

- (void)receiveMembersRemovedFromConversation:(AVIMConversation *)conversation clientIds:(NSArray *)clientIds byClientId:(NSString *)clientId {
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
    [self array:arguments addObject:conversation];
    [self array:arguments addObject:clientIds];
    [self array:arguments addObject:clientId];
    [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(conversation:membersRemoved:byClientId:) arguments:arguments];
}

- (void)receivePaused {
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
    [self array:arguments addObject:self];
    [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(imClientPaused:) arguments:arguments];
}

- (void)receivePausedWithError:(NSError *)error {
    [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(imClientPaused:error:) arguments:@[self, error]];
}

- (void)receiveResuming {
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
    [self array:arguments addObject:self];
    [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(imClientResuming:) arguments:arguments];
}

- (void)receiveResumed {
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
    [self array:arguments addObject:self];
    [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(imClientResumed:) arguments:arguments];
}

- (void)receiveError:(NSNotification *)notification {
    if ([_delegate respondsToSelector:@selector(imClientPaused:error:)]) {
        NSError *error = [notification.userInfo objectForKey:@"error"];
        
        [self receivePausedWithError:error];
    } else if ([_delegate respondsToSelector:@selector(imClientPaused:)]) {
        [self receivePaused];
    }
}

+ (NSMutableDictionary *)userOptions {
    static dispatch_once_t onceToken;
    static NSMutableDictionary *userOptions;

    dispatch_once(&onceToken, ^{
        userOptions = [NSMutableDictionary dictionary];
    });

    return userOptions;
}

+ (void)setUserOptions:(NSDictionary *)userOptions {
    if (AVIMClientHasInstantiated) {
        [NSException raise:NSInternalInconsistencyException format:@"AVIMClient user options should be set before instantiation"];
    }

    if (!userOptions)
        return;

    [[self userOptions] addEntriesFromDictionary:userOptions];
}

+ (void)setUnreadNotificationEnabled:(BOOL)enabled {
    [self setUserOptions:@{
        AVIMUserOptionUseUnread: @(enabled)
    }];
}

@end
