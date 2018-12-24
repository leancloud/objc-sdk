//
//  AVIM.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMClient_Internal.h"
#import "AVIMClientInternalConversationManager_Internal.h"
#import "AVIMClientPushManager.h"
#import "AVIMConversation_Internal.h"
#import "AVIMKeyedConversation_internal.h"
#import "AVIMConversationMemberInfo_Internal.h"
#import "AVIMConversationQuery_Internal.h"
#import "AVIMTypedMessage_Internal.h"
#import "AVIMSignature.h"
#import "AVIMGenericCommand+AVIMMessagesAdditions.h"

#import "LCIMConversationCache.h"
#import "AVIMErrorUtil.h"

#import "UserAgent.h"
#import "AVUtils.h"
#import "AVPaasClient.h"
#import "AVErrorUtils.h"

#if DEBUG
void assertContextOfQueue(dispatch_queue_t queue, BOOL isRunIn)
{
    assert(queue);
    void *key = (__bridge void *)queue;
    if (isRunIn) {
        assert(dispatch_get_specific(key) == key);
    } else {
        assert(dispatch_get_specific(key) != key);
    }
}
#endif

@implementation AVIMClient {
    // public
    __weak id<AVIMClientDelegate> _delegate;
    __weak id<AVIMSignatureDataSource> _signatureDataSource;
    NSString *_clientId;
    NSString *_tag;
    AVUser *_user;
    AVIMClientStatus _status;
    BOOL _messageQueryCacheEnabled;
    
    // session
    int64_t _sessionConfigBitmap;
    NSString *_sessionToken;
    NSTimeInterval _sessionTokenExpireTimestamp;
    int64_t _lastPatchTimestamp;
    int64_t _lastUnreadTimestamp;
    BOOL _isInSessionOpenHandshaking;
}

static BOOL clientHasInstantiated = false;

+ (instancetype)alloc
{
#if DEBUG
    assert([kAVIMCodeKey isEqualToString:keyPath(AVIMErrorCommand.alloc, code)]);
    assert([kAVIMAppCodeKey isEqualToString:keyPath(AVIMErrorCommand.alloc, appCode)]);
    assert([kAVIMDetailKey isEqualToString:keyPath(AVIMErrorCommand.alloc, detail)]);
    assert([kAVIMReasonKey isEqualToString:keyPath(AVIMErrorCommand.alloc, reason)]);
    assert([AVIMConversationUpdatedKeyLastMessage isEqualToString:keyPath(AVIMConversation.alloc, lastMessage)]);
    assert([AVIMConversationUpdatedKeyLastMessageAt isEqualToString:keyPath(AVIMConversation.alloc, lastMessageAt)]);
    assert([AVIMConversationUpdatedKeyLastReadAt isEqualToString:keyPath(AVIMConversation.alloc, lastReadAt)]);
    assert([AVIMConversationUpdatedKeyLastDeliveredAt isEqualToString:keyPath(AVIMConversation.alloc, lastDeliveredAt)]);
    assert([AVIMConversationUpdatedKeyUnreadMessagesCount isEqualToString:keyPath(AVIMConversation.alloc, unreadMessagesCount)]);
    assert([AVIMConversationUpdatedKeyUnreadMessagesMentioned isEqualToString:keyPath(AVIMConversation.alloc, unreadMessagesMentioned)]);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    assert([kAVIMUserOptionUseUnread isEqualToString:AVIMUserOptionUseUnread]);
#pragma clang diagnostic pop
#endif
    clientHasInstantiated = YES;
    return [super alloc];
}

+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds
{
    [AVIMWebSocketWrapper setTimeoutIntervalInSeconds:seconds];
}

+ (instancetype)new
{
    [NSException raise:NSInternalInconsistencyException format:@"not allow."];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException format:@"not allow."];
    return nil;
}

// MARK: - Init

- (instancetype)initWithClientId:(NSString *)clientId
{
    return [self initWithClientId:clientId tag:nil];
}

- (instancetype)initWithClientId:(NSString *)clientId tag:(NSString *)tag
{
    return [self initWithClientId:clientId tag:tag installation:AVInstallation.defaultInstallation];
}

- (instancetype)initWithClientId:(NSString *)clientId tag:(NSString *)tag installation:(AVInstallation *)installation
{
    self = [super init];
    if (self) {
        self->_user = nil;
        [self doInitializationWithClientId:clientId tag:tag installation:installation];
    }
    return self;
}

- (instancetype)initWithUser:(AVUser *)user
{
    return [self initWithUser:user tag:nil];
}

- (instancetype)initWithUser:(AVUser *)user tag:(NSString *)tag
{
    return [self initWithUser:user tag:tag installation:AVInstallation.defaultInstallation];
}

- (instancetype)initWithUser:(AVUser *)user tag:(NSString *)tag installation:(AVInstallation *)installation
{
    self = [super init];
    if (self) {
        self->_user = user;
        [self doInitializationWithClientId:user.objectId tag:tag installation:installation];
    }
    return self;
}

- (void)doInitializationWithClientId:(NSString *)clientId
                                 tag:(NSString *)tag
                        installation:(AVInstallation *)installation
{
    self->_clientId = ({
        if (!clientId || clientId.length > kClientIdLengthLimit || clientId.length == 0) {
            [NSException raise:NSInvalidArgumentException
                        format:@"clientId invalid or length not in range [1 %lu].", kClientIdLengthLimit];
        }
        clientId.copy;
    });
    
    self->_tag = ({
        if ([tag isEqualToString:kClientTagDefault]) {
            [NSException raise:NSInvalidArgumentException
                        format:@"%@ is reserved.", kClientTagDefault];
        }
        (tag ? tag.copy : nil);
    });
    
    self->_status = AVIMClientStatusNone;
    
    self->_sessionConfigBitmap = ({
        (LCIMSessionConfigOptions_Patch |
         LCIMSessionConfigOptions_TempConv |
         LCIMSessionConfigOptions_TransientACK |
         LCIMSessionConfigOptions_CallbackResultSlice);
    });
    self->_sessionToken = nil;
    self->_sessionTokenExpireTimestamp = 0;
    self->_lastPatchTimestamp = 0;
    self->_lastUnreadTimestamp = 0;
    self->_isInSessionOpenHandshaking = false;
    
    self->_messageQueryCacheEnabled = true;
    
    self->_internalSerialQueue = ({
        NSString *className = NSStringFromClass(self.class);
        NSString *ivarName = ivarName(self, _internalSerialQueue);
        NSString *label = [NSString stringWithFormat:@"%@.%@", className, ivarName];
        dispatch_queue_t queue = dispatch_queue_create(label.UTF8String, DISPATCH_QUEUE_SERIAL);
#if DEBUG
        void *key = (__bridge void *)queue;
        dispatch_queue_set_specific(queue, key, key, NULL);
#endif
        queue;
    });
    self->_signatureQueue = ({
        NSString *className = NSStringFromClass(self.class);
        NSString *ivarName = ivarName(self, _signatureQueue);
        NSString *label = [NSString stringWithFormat:@"%@.%@", className, ivarName];
        dispatch_queue_t queue = dispatch_queue_create(label.UTF8String, DISPATCH_QUEUE_CONCURRENT);
#if DEBUG
        void *key = (__bridge void *)queue;
        dispatch_queue_set_specific(queue, key, key, NULL);
#endif
        queue;
    });
    self->_userInteractQueue = dispatch_get_main_queue();
    
    self->_socketWrapper = [[AVIMWebSocketWrapper alloc] initWithDelegate:self];
    
    self->_conversationManager = [[AVIMClientInternalConversationManager alloc] initWithClient:self];
    
    self->_pushManager = [[AVIMClientPushManager alloc] initWithInstallation:installation client:self];
    
    self->_conversationCache = ({
        LCIMConversationCache *cache = [[LCIMConversationCache alloc] initWithClientId:self->_clientId];
        cache.client = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [cache cleanAllExpiredConversations];
        });
        cache;
    });
}

- (void)dealloc
{
    [self->_socketWrapper setActivatingReconnectionEnabled:false];
    [self->_socketWrapper close];
}

// MARK: - Queue

- (void)addOperationToInternalSerialQueue:(void (^)(AVIMClient *client))block
{
    dispatch_async(self->_internalSerialQueue, ^{
        block(self);
    });
}

- (void)invokeInUserInteractQueue:(void (^)(void))block
{
    NSParameterAssert(self->_userInteractQueue);
    dispatch_async(self->_userInteractQueue, ^{
        block();
    });
}

// MARK: - Public Property

- (NSString *)clientId
{
    return self->_clientId;
}

- (NSString *)tag
{
    return self->_tag;
}

- (AVUser *)user
{
    return self->_user;
}

- (id <AVIMClientDelegate>)delegate
{
    return self->_delegate;
}

- (void)setDelegate:(id <AVIMClientDelegate>)delegate
{
    self->_delegate = delegate;
}

- (id <AVIMSignatureDataSource>)signatureDataSource
{
    return self->_signatureDataSource;
}

- (void)setSignatureDataSource:(id <AVIMSignatureDataSource>)signatureDataSource
{
    self->_signatureDataSource = signatureDataSource;
}

- (AVIMClientStatus)status
{
    return self->_status;
}

- (BOOL)messageQueryCacheEnabled
{
    return self->_messageQueryCacheEnabled;
}

- (void)setMessageQueryCacheEnabled:(BOOL)messageQueryCacheEnabled
{
    self->_messageQueryCacheEnabled = messageQueryCacheEnabled;
}

// MARK: - Client Open

- (void)openWithCallback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self openWithOption:AVIMClientOpenOptionForceOpen callback:callback];
}

- (void)openWithOption:(AVIMClientOpenOption)openOption
              callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self getSessionOpenSignatureWithCallback:^(AVIMSignature *signature) {
        
        AssertRunInQueue(self->_internalSerialQueue);
        
        if (signature && signature.error) {
            [self invokeInUserInteractQueue:^{
                callback(false, signature.error);
            }];
            return;
        }
        if (self->_status == AVIMClientStatusOpened) {
            [self invokeInUserInteractQueue:^{
                callback(true, nil);
            }];
            return;
        }
        if (self->_status == AVIMClientStatusOpening) {
            [self invokeInUserInteractQueue:^{
                callback(false, LCErrorInternal(@"in opening, do not open repeatedly."));
            }];
            return;
        }
        
        self->_status = AVIMClientStatusOpening;
        
        [self->_socketWrapper openWithCallback:^(BOOL succeeded, NSError *error) {
            [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
                
                if (error) {
                    if (client->_status == AVIMClientStatusOpening) {
                        client->_status = AVIMClientStatusClosed;
                        [client clearSessionTokenAndTTL];
                    }
                    [client invokeInUserInteractQueue:^{
                        callback(false, error);
                    }];
                    return;
                }
                
                LCIMProtobufCommandWrapper *commandWrapper = ({
                    
                    AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
                    AVIMSessionCommand *sessionCommand = [AVIMSessionCommand new];
                    
                    outCommand.cmd = AVIMCommandType_Session;
                    outCommand.op = AVIMOpType_Open;
                    outCommand.appId = [AVOSCloud getApplicationId];
                    outCommand.peerId = client->_clientId;
                    outCommand.sessionMessage = sessionCommand;
                    
                    if (client->_sessionConfigBitmap) {
                        sessionCommand.configBitmap = client->_sessionConfigBitmap;
                    }
                    if (client->_lastPatchTimestamp) {
                        sessionCommand.lastPatchTime = client->_lastPatchTimestamp;
                    }
                    if (client->_lastUnreadTimestamp) {
                        sessionCommand.lastUnreadNotifTime = client->_lastUnreadTimestamp;
                    }
                    if (openOption == AVIMClientOpenOptionReopen) {
                        sessionCommand.r = true;
                    }
                    if (client->_tag) {
                        sessionCommand.tag = client->_tag;
                    }
                    if (signature && signature.signature && signature.timestamp && signature.nonce) {
                        sessionCommand.s = signature.signature;
                        sessionCommand.t = signature.timestamp;
                        sessionCommand.n = signature.nonce;
                    }
                    sessionCommand.deviceToken = client->_pushManager.deviceToken ?: AVUtils.deviceUUID;
                    sessionCommand.ua = @"ios/" SDK_VERSION;
                    
                    LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
                    commandWrapper.outCommand = outCommand;
                    commandWrapper;
                });
                
                [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
                    
                    client->_isInSessionOpenHandshaking = false;
                    
                    if (commandWrapper.error) {
                        if (client->_status == AVIMClientStatusOpening) {
                            client->_status = AVIMClientStatusClosed;
                            [client clearSessionTokenAndTTL];
                        }
                        [client invokeInUserInteractQueue:^{
                            callback(false, commandWrapper.error);
                        }];
                        return;
                    }
                    
                    AVIMGenericCommand *inCommand = commandWrapper.inCommand;
                    AVIMSessionCommand *sessionCommand = (inCommand.hasSessionMessage ? inCommand.sessionMessage : nil);
                    NSString *sessionToken = (sessionCommand.hasSt ? sessionCommand.st : nil);
                    if (!sessionToken) {
                        if (client->_status == AVIMClientStatusOpening) {
                            client->_status = AVIMClientStatusClosed;
                            [client clearSessionTokenAndTTL];
                        }
                        [client invokeInUserInteractQueue:^{
                            callback(false, ({
                                AVIMErrorCode code = AVIMErrorCodeInvalidCommand;
                                LCError(code, AVIMErrorMessage(code), nil);
                            }));
                        }];
                        return;
                    }
                    
                    client->_status = AVIMClientStatusOpened;
                    [client setSessionToken:sessionToken ttl:(sessionCommand.hasStTtl ? sessionCommand.stTtl : 0)];
                    [client->_pushManager uploadingDeviceToken];
                    [client->_pushManager addingClientIdToChannels];
                    [client->_socketWrapper setActivatingReconnectionEnabled:true];
                    
                    [client invokeInUserInteractQueue:^{
                        callback(true, nil);
                    }];
                }];
                
                client->_isInSessionOpenHandshaking = true;
                [client->_socketWrapper sendCommandWrapper:commandWrapper];
            }];
        }];
    }];
}

- (void)resumeWithSessionToken:(NSString *)sessionToken callback:(void (^)(BOOL succeeded, NSError *error))callback
{
    AssertRunInQueue(self->_internalSerialQueue);
    if (self->_status == AVIMClientStatusOpened) {
        callback(true, nil);
        return;
    }
    
    LCIMProtobufCommandWrapper * (^ newReopenCommandBlock)(AVIMSignature *, NSString *) = ^(AVIMSignature *signature, NSString *sessionToken) {
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMSessionCommand *sessionCommand = [AVIMSessionCommand new];
        outCommand.cmd = AVIMCommandType_Session;
        outCommand.op = AVIMOpType_Open;
        outCommand.appId = [AVOSCloud getApplicationId];
        outCommand.peerId = self->_clientId;
        outCommand.sessionMessage = sessionCommand;
        sessionCommand.r = true;
        if (sessionToken) {
            sessionCommand.st = sessionToken;
        } else {
            if (signature && signature.signature && signature.timestamp && signature.nonce) {
                sessionCommand.s = signature.signature;
                sessionCommand.t = signature.timestamp;
                sessionCommand.n = signature.nonce;
            }
            if (self->_tag) {
                sessionCommand.tag = self->_tag;
            }
            if (self->_sessionConfigBitmap) {
                sessionCommand.configBitmap = self->_sessionConfigBitmap;
            }
            sessionCommand.deviceToken = self->_pushManager.deviceToken ?: AVUtils.deviceUUID;
            sessionCommand.ua = @"ios" @"/" SDK_VERSION;
        }
        if (self->_lastPatchTimestamp) {
            sessionCommand.lastPatchTime = self->_lastPatchTimestamp;
        }
        if (self->_lastUnreadTimestamp) {
            sessionCommand.lastUnreadNotifTime = self->_lastUnreadTimestamp;
        }
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        return commandWrapper;
    };
    
    void(^ handleInCommandBlock)(LCIMProtobufCommandWrapper *) = ^(LCIMProtobufCommandWrapper *commandWrapper) {
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMSessionCommand *sessionCommand = (inCommand.hasSessionMessage ? inCommand.sessionMessage : nil);
        if (!(sessionCommand && inCommand.cmd == AVIMCommandType_Session && inCommand.op == AVIMOpType_Opened)) {
            callback(false, ({
                AVIMErrorCode code = AVIMErrorCodeInvalidCommand;
                LCError(code, AVIMErrorMessage(code), nil);
            }));
            return;
        }
        NSString *sessionToken = (sessionCommand.hasSt ? sessionCommand.st : nil);
        int32_t ttl = (sessionCommand.hasStTtl ? sessionCommand.stTtl : 0);
        if (sessionToken && ttl) {
            [self setSessionToken:sessionToken ttl:ttl];
        }
        self->_status = AVIMClientStatusOpened;
        [self->_pushManager uploadingDeviceToken];
        [self->_pushManager addingClientIdToChannels];
        callback(true, nil);
    };
    
    LCIMProtobufCommandWrapper *commandWrapper1 = newReopenCommandBlock(nil, sessionToken);
    [commandWrapper1 setCallback:^(LCIMProtobufCommandWrapper *commandWrapper1) {
        if (commandWrapper1.error) {
            NSError *error = commandWrapper1.error;
            if (error.code == AVIMErrorCodeSessionTokenExpired && [error.domain isEqualToString:kLeanCloudErrorDomain]) {
                [self getSessionOpenSignatureWithCallback:^(AVIMSignature *signature) {
                    AssertRunInQueue(self->_internalSerialQueue);
                    if (signature.error) {
                        callback(false, signature.error);
                    } else {
                        LCIMProtobufCommandWrapper *commandWrapper2 = newReopenCommandBlock(signature, nil);
                        [commandWrapper2 setCallback:^(LCIMProtobufCommandWrapper *commandWrapper2) {
                            if (commandWrapper2.error) {
                                callback(false, commandWrapper2.error);
                            } else {
                                handleInCommandBlock(commandWrapper2);
                            }
                        }];
                        [self->_socketWrapper sendCommandWrapper:commandWrapper2];
                    }
                }];
            } else {
                callback(false, commandWrapper1.error);
            }
        } else {
            handleInCommandBlock(commandWrapper1);
        }
    }];
    [self->_socketWrapper sendCommandWrapper:commandWrapper1];
}

// MARK: - Client Close

- (void)closeWithCallback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        if (client->_status == AVIMClientStatusClosed) {
            [client clearSessionTokenAndTTL];
            [client invokeInUserInteractQueue:^{
                callback(true, nil);
            }];
            return;
        }
        
        if (client->_status != AVIMClientStatusOpened) {
            [client invokeInUserInteractQueue:^{
                callback(false, ({
                    AVIMErrorCode code = AVIMErrorCodeClientNotOpen;
                    LCError(code, AVIMErrorMessage(code), nil);
                }));
            }];
            return;
        }
        
        client->_status = AVIMClientStatusClosing;
        
        LCIMProtobufCommandWrapper *commandWrapper = ({
            
            AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
            AVIMSessionCommand *sessionCommand = [AVIMSessionCommand new];
            
            outCommand.cmd = AVIMCommandType_Session;
            outCommand.op = AVIMOpType_Close;
            outCommand.sessionMessage = sessionCommand;
            
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = outCommand;
            commandWrapper;
        });
        
        [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                if (client->_status == AVIMClientStatusClosing) {
                    client->_status = AVIMClientStatusOpened;
                }
                [client invokeInUserInteractQueue:^{
                    callback(false, commandWrapper.error);
                }];
                return;
            }
            
            client->_status = AVIMClientStatusClosed;
            [client clearSessionTokenAndTTL];
            [client->_pushManager removingClientIdFromChannels];
            [client->_socketWrapper setActivatingReconnectionEnabled:false];
            [client->_socketWrapper close];
            
            [client invokeInUserInteractQueue:^{
                callback(true, nil);
            }];
        }];
        
        [client->_socketWrapper sendCommandWrapper:commandWrapper];
    }];
}

// MARK: - Session Token

- (void)setSessionToken:(NSString *)sessionToken ttl:(int32_t)ttl
{
    AssertRunInQueue(self->_internalSerialQueue);
    NSParameterAssert(sessionToken);
    self->_sessionToken = sessionToken;
    self->_sessionTokenExpireTimestamp = NSDate.date.timeIntervalSince1970 + (NSTimeInterval)ttl;
}

- (void)clearSessionTokenAndTTL
{
    AssertRunInQueue(self->_internalSerialQueue);
    self->_sessionToken = nil;
    self->_sessionTokenExpireTimestamp = 0;
}

- (void)getSessionTokenWithForcingRefresh:(BOOL)forcingRefresh
                                 callback:(void (^)(NSString *, NSError *))callback
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        NSString *oldSessionToken = client->_sessionToken;
        
        if (!oldSessionToken || self->_status != AVIMClientStatusOpened) {
            callback(nil, ({
                AVIMErrorCode code = AVIMErrorCodeClientNotOpen;
                LCError(code, AVIMErrorMessage(code), nil);
            }));
            return;
        }
        
        if (forcingRefresh || (NSDate.date.timeIntervalSince1970 > client->_sessionTokenExpireTimestamp)) {
            
            LCIMProtobufCommandWrapper *commandWrapper = ({
                
                AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
                AVIMSessionCommand *sessionCommand = [AVIMSessionCommand new];
                
                outCommand.cmd = AVIMCommandType_Session;
                outCommand.op = AVIMOpType_Refresh;
                outCommand.sessionMessage = sessionCommand;
                
                sessionCommand.st = oldSessionToken; /* let server to clear old session token */
                
                LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
                commandWrapper.outCommand = outCommand;
                commandWrapper;
            });
            
            [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
                
                if (commandWrapper.error) {
                    callback(nil, commandWrapper.error);
                    return;
                }
                
                if (!client->_sessionToken) {
                    callback(nil, LCErrorInternal(@"session has not opened or did close."));
                    return;
                }
                
                AVIMGenericCommand *inCommand = commandWrapper.inCommand;
                AVIMSessionCommand *sessionCommand = (inCommand.hasSessionMessage ? inCommand.sessionMessage : nil);
                NSString *sessionToken = (sessionCommand.hasSt ? sessionCommand.st : nil);
                if (!sessionToken) {
                    callback(nil, ({
                        AVIMErrorCode code = AVIMErrorCodeInvalidCommand;
                        LCError(code, AVIMErrorMessage(code), nil);
                    }));
                }
                
                [client setSessionToken:sessionToken ttl:(sessionCommand.hasStTtl ? sessionCommand.stTtl : 0)];
                callback(sessionToken, nil);
            }];
            
            [client sendCommandWrapper:commandWrapper];
            
        } else {
            
            callback(oldSessionToken, nil);
        }
    }];
}

// MARK: - Signature

- (void)getSessionOpenSignatureWithCallback:(void (^)(AVIMSignature *signature))callback
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        AVUser *user = client->_user;
        
        if (user) {
            
            NSString *userSessionToken = user.sessionToken;
            if (!userSessionToken) {
                AVIMSignature *signature = [AVIMSignature new];
                signature.error = LCErrorInternal(@"user sessionToken invalid.");
                callback(signature);
                return;
            }
            
            AVPaasClient *paasClient = AVPaasClient.sharedInstance;
            
            NSURLRequest *request = ({
                NSDictionary *parameters = @{ @"session_token" : userSessionToken };
                [paasClient requestWithPath:@"rtm/sign" method:@"POST" headers:nil parameters:parameters];
            });
        
            [paasClient performRequest:request success:^(NSHTTPURLResponse *response, id result) {
                if ([NSDictionary lc__checkingType:result]) {
                    NSString *sign = [NSString lc__decodingDictionary:result key:@"signature"];
                    int64_t timestamp = [[NSNumber lc__decodingDictionary:result key:@"timestamp"] longLongValue];
                    NSString *nonce = [NSString lc__decodingDictionary:result key:@"nonce"];
                    if (sign && timestamp && nonce) {
                        AVIMSignature *signature = ({
                            AVIMSignature *signature = [AVIMSignature new];
                            signature.signature = sign;
                            signature.timestamp = timestamp;
                            signature.nonce = nonce;
                            signature;
                        });
                        [client addOperationToInternalSerialQueue:^(AVIMClient *client) {
                            callback(signature);
                        }];
                        return;
                    }
                }
                AVIMSignature *signature = [AVIMSignature new];
                signature.error = LCErrorInternal([NSString stringWithFormat:@"response data: %@ is invalid.", result]);
                [client addOperationToInternalSerialQueue:^(AVIMClient *client) {
                    callback(signature);
                }];
            } failure:^(NSHTTPURLResponse *response, id result, NSError *error) {
                AVIMSignature *signature = [AVIMSignature new];
                signature.error = error;
                [client addOperationToInternalSerialQueue:^(AVIMClient *client) {
                    callback(signature);
                }];
            }];
            
        } else {
            
            [client getSignatureWithConversationId:nil action:AVIMSignatureActionOpen actionOnClientIds:nil callback:^(AVIMSignature *signature) {
                AssertRunInQueue(client->_internalSerialQueue);
                callback(signature);
            }];
        }
    }];
}

- (void)getSignatureWithConversationId:(NSString *)conversationId
                                action:(AVIMSignatureAction)action
                     actionOnClientIds:(NSArray<NSString *> *)actionOnClientIds
                              callback:(void (^)(AVIMSignature *))callback
{
    dispatch_async(self->_signatureQueue, ^{
        id <AVIMSignatureDataSource> dataSource = self->_signatureDataSource;
        SEL sel = @selector(signatureWithClientId:conversationId:action:actionOnClientIds:);
        AVIMSignature *signature = nil;
        if (dataSource && [dataSource respondsToSelector:sel]) {
            signature = [dataSource signatureWithClientId:self->_clientId
                                           conversationId:conversationId
                                                   action:action
                                        actionOnClientIds:actionOnClientIds];
        }
        [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
            callback(signature);
        }];
    });
}

// MARK: - Command Send

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        if (self->_status != AVIMClientStatusOpened) {
            if (commandWrapper.hasCallback) {
                commandWrapper.error = ({
                    AVIMErrorCode code = AVIMErrorCodeClientNotOpen;
                    LCError(code, AVIMErrorMessage(code), nil);
                });
                [commandWrapper executeCallbackAndSetItToNil];
            }
            return;
        }
        [client->_socketWrapper sendCommandWrapper:commandWrapper];
    }];
}

// MARK: - WebSocket Delegate

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didReceiveCommandCallback:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        if (commandWrapper.hasCallback) {
            [commandWrapper executeCallbackAndSetItToNil];
        }
        
        if (commandWrapper.error && commandWrapper.error.code == AVIMErrorCodeSessionConflict) {
            client->_status = AVIMClientStatusClosed;
            [client clearSessionTokenAndTTL];
            [client->_pushManager removingClientIdFromChannels];
            [client->_socketWrapper setActivatingReconnectionEnabled:false];
            [client->_socketWrapper close];
            id <AVIMClientDelegate> delegate = client->_delegate;
            SEL sel = @selector(client:didOfflineWithError:);
            if (delegate && [delegate respondsToSelector:sel]) {
                [client invokeInUserInteractQueue:^{
                    [delegate client:client didOfflineWithError:commandWrapper.error];
                }];
            }
        }
    }];
}

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didReceiveCommand:(LCIMProtobufCommandWrapper *)commandWrapper
{
    if (!commandWrapper.inCommand) { return; }
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMCommandType commandType = (inCommand.hasCmd ? inCommand.cmd : -1);
        AVIMOpType opType = (inCommand.hasOp ? inCommand.op : -1);
        switch (commandType)
        {
            case AVIMCommandType_Session:
            {
                switch (opType)
                {
                    case AVIMOpType_Closed:
                    {
                        [client process_session_closed:inCommand];
                    } break;
                    default: break;
                }
            } break;
            case AVIMCommandType_Conv:
            {
                switch (opType)
                {
                    case AVIMOpType_Joined:
                    {
                        [client process_conv_joined:inCommand];
                    } break;
                    case AVIMOpType_MembersJoined:
                    {
                        [client process_conv_members_joined:inCommand];
                    } break;
                    case AVIMOpType_Left:
                    {
                        [client process_conv_left:inCommand];
                    } break;
                    case AVIMOpType_MembersLeft:
                    {
                        [client process_conv_members_left:inCommand];
                    } break;
                    case AVIMOpType_Updated:
                    {
                        [client process_conv_updated:inCommand];
                    } break;
                    case AVIMOpType_MemberInfoChanged:
                    {
                        [client process_conv_member_info_changed:inCommand];
                    } break;
                    case AVIMOpType_Blocked:
                    {
                        [client process_conv_blocked:inCommand];
                    } break;
                    case AVIMOpType_MembersBlocked:
                    {
                        [client process_conv_members_blocked:inCommand];
                    } break;
                    case AVIMOpType_Unblocked:
                    {
                        [client process_conv_unblocked:inCommand];
                    } break;
                    case AVIMOpType_MembersUnblocked:
                    {
                        [client process_conv_members_unblocked:inCommand];
                    } break;
                    case AVIMOpType_Shutuped:
                    {
                        [client process_conv_shutuped:inCommand];
                    } break;
                    case AVIMOpType_MembersShutuped:
                    {
                        [client process_conv_members_shutuped:inCommand];
                    } break;
                    case AVIMOpType_Unshutuped:
                    {
                        [client process_conv_unshutuped:inCommand];
                    } break;
                    case AVIMOpType_MembersUnshutuped:
                    {
                        [client process_conv_members_unshutuped:inCommand];
                    } break;
                    default: break;
                }
            } break;
            case AVIMCommandType_Direct:
            {
                [client process_direct:inCommand];
            } break;
            case AVIMCommandType_Rcp:
            {
                [client process_rcp:inCommand];
            } break;
            case AVIMCommandType_Unread:
            {
                [client process_unread:inCommand];
            } break;
            case AVIMCommandType_Patch:
            {
                switch (opType)
                {
                    case AVIMOpType_Modify:
                    {
                        [client process_patch_modify:inCommand];
                    } break;
                    default: break;
                }
            } break;
            default: break;
        }
    }];
}

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didCommandEncounterError:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        if (commandWrapper.hasCallback && commandWrapper.error) {
            [commandWrapper executeCallbackAndSetItToNil];
        }
    }];
}

- (void)webSocketWrapperDidReopen:(AVIMWebSocketWrapper *)socketWrapper
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        NSString *sessionToken = client->_sessionToken;
        if (!sessionToken) { return; }
        if (client->_isInSessionOpenHandshaking) { return; }
        [client resumeWithSessionToken:sessionToken callback:^(BOOL succeeded, NSError *error) {
            id<AVIMClientDelegate> delegate = client->_delegate;
            [client invokeInUserInteractQueue:^{
                if (error) {
                    AVLoggerError(AVLoggerDomainIM, @"session resuming failed with error: %@", error);
                    if ([error.domain isEqualToString:kLeanCloudErrorDomain] &&
                        error.code == AVIMErrorCodeCommandTimeout) {
                        [client webSocketWrapperDidReopen:socketWrapper];
                    }
                } else {
                    [delegate imClientResumed:client];
                }
            }];
        }];
    }];
}

- (void)webSocketWrapperInReconnecting:(AVIMWebSocketWrapper *)socketWrapper
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        if (!client->_sessionToken || client->_status == AVIMClientStatusResuming) {
            return;
        }
        client->_status = AVIMClientStatusResuming;
        [client invokeInUserInteractQueue:^{
            [client->_delegate imClientResuming:client];
        }];
    }];
}

- (void)webSocketWrapperDidPause:(AVIMWebSocketWrapper *)socketWrapper
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        if (!client->_sessionToken || client->_status == AVIMClientStatusPaused) {
            return;
        }
        client->_status = AVIMClientStatusPaused;
        [client invokeInUserInteractQueue:^{
            [client->_delegate imClientPaused:client];
        }];
    }];
}

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didCloseWithError:(NSError *)error
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        if (!client->_sessionToken) { return; }
        client->_status = AVIMClientStatusClosed;
        [client clearSessionTokenAndTTL];
        [client->_socketWrapper setActivatingReconnectionEnabled:false];
        [client->_socketWrapper close];
        id<AVIMClientDelegate> delegate = client->_delegate;
        [client invokeInUserInteractQueue:^{
            [delegate imClientClosed:client error:error];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            if ([delegate respondsToSelector:@selector(imClientPaused:error:)]) {
                [delegate imClientPaused:client error:error];
            }
#pragma clang diagnostic pop
        }];
    }];
}

// MARK: - Command Process

- (void)process_session_closed:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMSessionCommand *sessionCommand = (inCommand.hasSessionMessage ? inCommand.sessionMessage : nil);
    if (!sessionCommand) {
        return;
    }
    
    self->_status = AVIMClientStatusClosed;
    [self clearSessionTokenAndTTL];
    
    int32_t code = (sessionCommand.hasCode ? sessionCommand.code : 0);
    
    if (code == AVIMErrorCodeSessionConflict) {
        [self->_pushManager removingClientIdFromChannels];
        [self->_socketWrapper setActivatingReconnectionEnabled:false];
        [self->_socketWrapper close];
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(client:didOfflineWithError:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                NSError *aError = ({
                    LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
                    commandWrapper.inCommand = inCommand;
                    commandWrapper.error;
                });
                [delegate client:self didOfflineWithError:aError];
            }];
        }
    }
}

- (void)process_conv_joined:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation addMembers:@[self->_clientId]];
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:invitedByClientId:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation invitedByClientId:initById];
            }];
        }
    }];
}

- (void)process_conv_members_joined:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation addMembers:memberIds];
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:membersAdded:byClientId:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation membersAdded:memberIds byClientId:initById];
            }];
        }
    }];
}

- (void)process_conv_left:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation removeMembers:@[self->_clientId]];
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:kickedByClientId:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation kickedByClientId:initById];
            }];
        }
    }];
}

- (void)process_conv_members_left:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation removeMembers:memberIds];
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:membersRemoved:byClientId:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation membersRemoved:memberIds byClientId:initById];
            }];
        }
    }];
}

- (void)process_conv_updated:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    
    NSDictionary *attr = ({
        AVIMJsonObjectMessage *jsonObjectMessage = (convCommand.hasAttr ? convCommand.attr : nil);
        NSString *jsonString = (jsonObjectMessage.hasData_p ? jsonObjectMessage.data_p : nil);
        NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        if (!data) {
            return;
        }
        NSError *error = nil;
        NSDictionary *attr = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error || ![NSDictionary lc__checkingType:attr]) {
            return;
        }
        attr;
    });
    
    NSDictionary *attrModified = ({
        AVIMJsonObjectMessage *jsonObjectMessage = (convCommand.hasAttrModified ? convCommand.attrModified : nil);
        NSString *jsonString = (jsonObjectMessage.hasData_p ? jsonObjectMessage.data_p : nil);
        NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        if (!data) {
            return;
        }
        NSError *error = nil;
        NSDictionary *attrModified = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error || ![NSDictionary lc__checkingType:attrModified]) {
            return;
        }
        attrModified;
    });
    
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    NSDate *updateDate = LCDateFromString((convCommand.hasUdate ? convCommand.udate : nil));
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation process_conv_updated_attr:attr attrModified:attrModified];
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:didUpdateAt:byClientId:updatedData:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didUpdateAt:updateDate byClientId:initById updatedData:attrModified];
            }];
        }
    }];
}

- (void)process_conv_member_info_changed:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    AVIMConvMemberInfo *convMemberInfo = (convCommand.hasInfo ? convCommand.info : nil);
    NSString *memberId = (convMemberInfo.hasPid ? convMemberInfo.pid : nil);
    NSString *roleKey = (convMemberInfo.hasRole ? convMemberInfo.role : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation process_member_info_changed:memberId role:roleKey];
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:didMemberInfoUpdateBy:memberId:role:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                AVIMConversationMemberRole role = AVIMConversationMemberInfo_key_to_role(roleKey);
                [delegate conversation:conversation didMemberInfoUpdateBy:initById memberId:memberId role:role];
            }];
        }
    }];
}

- (void)process_conv_blocked:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:didBlockBy:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didBlockBy:initById];
            }];
        }
    }];
}

- (void)process_conv_members_blocked:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:didMembersBlockBy:memberIds:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didMembersBlockBy:initById memberIds:memberIds];
            }];
        }
    }];
}

- (void)process_conv_unblocked:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:didUnblockBy:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didUnblockBy:initById];
            }];
        }
    }];
}

- (void)process_conv_members_unblocked:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:didMembersUnblockBy:memberIds:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didMembersUnblockBy:initById memberIds:memberIds];
            }];
        }
    }];
}

- (void)process_conv_shutuped:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:didMuteBy:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didMuteBy:initById];
            }];
        }
    }];
}

- (void)process_conv_members_shutuped:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:didMembersMuteBy:memberIds:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didMembersMuteBy:initById memberIds:memberIds];
            }];
        }
    }];
}

- (void)process_conv_unshutuped:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:didUnmuteBy:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didUnmuteBy:initById];
            }];
        }
    }];
}

- (void)process_conv_members_unshutuped:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:didMembersUnmuteBy:memberIds:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didMembersUnmuteBy:initById memberIds:memberIds];
            }];
        }
    }];
}

- (void)process_patch_modify:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMPatchCommand *patchCommand = (inCommand.hasPatchMessage ? inCommand.patchMessage : nil);
    if (!patchCommand) {
        return;
    }
    
    NSMutableDictionary<NSString *, AVIMPatchItem *> *patchItemMap = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *conversationIds = [NSMutableArray array];
    ({
        for (AVIMPatchItem *patchItem in patchCommand.patchesArray) {
            if (patchItem.hasPatchTimestamp && patchItem.patchTimestamp > self->_lastPatchTimestamp) {
                self->_lastPatchTimestamp = patchItem.patchTimestamp;
            }
            NSString *conversationId = (patchItem.hasCid ? patchItem.cid : nil);
            if (conversationId) {
                [conversationIds addObject:conversationId];
                patchItemMap[conversationId] = patchItem;
            }
        }
    });
    
    [self->_conversationManager queryConversationsWithIds:conversationIds callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        AVIMPatchItem *patchItem = patchItemMap[conversation.conversationId];
        AVIMMessage *patchMessage = [conversation process_patch_modified:patchItem];
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:messageHasBeenUpdated:);
        if (patchMessage && delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation messageHasBeenUpdated:patchMessage];
            }];
        }
    }];
    
    ({
        LCIMProtobufCommandWrapper *ackCommandWrapper = ({
            AVIMGenericCommand *outCommand = [[AVIMGenericCommand alloc] init];
            AVIMPatchCommand *patchMessage = [[AVIMPatchCommand alloc] init];
            outCommand.cmd = AVIMCommandType_Patch;
            outCommand.op = AVIMOpType_Modified;
            outCommand.patchMessage = patchMessage;
            patchMessage.lastPatchTime = self->_lastPatchTimestamp;
            LCIMProtobufCommandWrapper *commandWrapper = [[LCIMProtobufCommandWrapper alloc] init];
            commandWrapper.outCommand = outCommand;
            commandWrapper;
        });
        [self sendCommandWrapper:ackCommandWrapper];
    });
}

- (void)process_rcp:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMRcpCommand *rcpCommand = (inCommand.hasRcpMessage ? inCommand.rcpMessage : nil);
    NSString *conversationId = (rcpCommand.hasCid ? rcpCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    BOOL isReadRcp = (rcpCommand.hasRead ? rcpCommand.read : false);
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        AVIMMessage *message = [conversation process_rcp:rcpCommand isReadRcp:isReadRcp];
        if (!isReadRcp && message) {
            id <AVIMClientDelegate> delegate = self->_delegate;
            SEL sel = @selector(conversation:messageDelivered:);
            if (delegate && [delegate respondsToSelector:sel]) {
                [self invokeInUserInteractQueue:^{
                    [delegate conversation:conversation messageDelivered:message];
                }];
            }
        }
    }];
}

- (void)process_unread:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMUnreadCommand *unreadCommand = (inCommand.hasUnreadMessage ? inCommand.unreadMessage : nil);
    if (!unreadCommand) {
        return;
    }
    
    int64_t notifTime = (unreadCommand.hasNotifTime ? unreadCommand.notifTime : 0);
    if (notifTime > self->_lastUnreadTimestamp) {
        self->_lastUnreadTimestamp = notifTime;
    }
    
    NSMutableDictionary<NSString *, AVIMUnreadTuple *> *unreadTupleMap = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *conversationIds = [NSMutableArray array];
    ({
        for (AVIMUnreadTuple *unreadTuple in unreadCommand.convsArray) {
            NSString *conversationId = (unreadTuple.hasCid ? unreadTuple.cid : nil);
            if (conversationId) {
                [conversationIds addObject:conversationId];
                unreadTupleMap[conversationId] = unreadTuple;
            }
        }
    });
    
    [self->_conversationManager queryConversationsWithIds:conversationIds callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        AVIMUnreadTuple *unreadTuple = unreadTupleMap[conversation.conversationId];
        NSInteger unreadCount = [conversation process_unread:unreadTuple];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL selector = @selector(conversation:didReceiveUnread:);
        if (unreadCount >= 0 && delegate && [delegate respondsToSelector:selector]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didReceiveUnread:unreadCount];
            }];
        }
#pragma clang diagnostic pop
    }];
}

- (void)process_direct:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    AVIMDirectCommand *directCommand = (inCommand.hasDirectMessage ? inCommand.directMessage : nil);
    
    NSString *conversationId = (directCommand.hasCid ? directCommand.cid : nil);
    NSString *messageId = (directCommand.hasId_p ? directCommand.id_p : nil);
    if (!conversationId || !messageId) {
        return;
    }
    BOOL isTransientMsg = (directCommand.hasTransient ? directCommand.transient : false);
    
    if (!isTransientMsg) {
        LCIMProtobufCommandWrapper *ackCommandWrapper = ({
            AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
            AVIMAckCommand *ackCommand = [AVIMAckCommand new];
            outCommand.cmd = AVIMCommandType_Ack;
            outCommand.ackMessage = ackCommand;
            ackCommand.cid = conversationId;
            ackCommand.mid = messageId;
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = outCommand;
            commandWrapper;
        });
        [self sendCommandWrapper:ackCommandWrapper];
    }
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        AVIMMessage *message = [conversation process_direct:directCommand messageId:messageId isTransientMsg:isTransientMsg];
        id <AVIMClientDelegate> delegate = self->_delegate;
        if (message && delegate) {
            SEL selType = @selector(conversation:didReceiveTypedMessage:);
            SEL selCommon = @selector(conversation:didReceiveCommonMessage:);
            if ([message isKindOfClass:AVIMTypedMessage.class] && [delegate respondsToSelector:selType]) {
                [self invokeInUserInteractQueue:^{
                    [delegate conversation:conversation didReceiveTypedMessage:(AVIMTypedMessage *)message];
                }];
            } else if ([message isKindOfClass:AVIMMessage.class] && [delegate respondsToSelector:selCommon]) {
                [self invokeInUserInteractQueue:^{
                    [delegate conversation:conversation didReceiveCommonMessage:message];
                }];
            }
        }
    }];
}

// MARK: - Conversation Create

- (void)createConversationWithName:(NSString * _Nullable)name
                         clientIds:(NSArray<NSString *> *)clientIds
                          callback:(void (^)(AVIMConversation * _Nullable, NSError * _Nullable))callback
{
    [self createConversationWithName:name clientIds:clientIds attributes:nil options:(AVIMConversationOptionNone) temporaryTTL:0 callback:callback];
}

- (void)createChatRoomWithName:(NSString * _Nullable)name
                    attributes:(NSDictionary * _Nullable)attributes
                      callback:(void (^)(AVIMChatRoom * _Nullable, NSError * _Nullable))callback
{
    [self createConversationWithName:name clientIds:@[] attributes:attributes options:(AVIMConversationOptionTransient) temporaryTTL:0 callback:^(AVIMConversation * _Nullable conversation, NSError * _Nullable error) {
        callback((AVIMChatRoom *)conversation, error);
    }];
}

- (void)createTemporaryConversationWithClientIds:(NSArray<NSString *> *)clientIds
                                      timeToLive:(int32_t)ttl
                                        callback:(void (^)(AVIMTemporaryConversation * _Nullable, NSError * _Nullable))callback
{
    [self createConversationWithName:nil clientIds:clientIds attributes:nil options:(AVIMConversationOptionTemporary) temporaryTTL:ttl callback:^(AVIMConversation * _Nullable conversation, NSError * _Nullable error) {
        callback((AVIMTemporaryConversation *)conversation, error);
    }];
}

- (void)createConversationWithName:(NSString * _Nullable)name
                         clientIds:(NSArray<NSString *> *)clientIds
                        attributes:(NSDictionary * _Nullable)attributes
                           options:(AVIMConversationOption)options
                          callback:(void (^)(AVIMConversation * _Nullable, NSError * _Nullable))callback
{
    [self createConversationWithName:name clientIds:clientIds attributes:attributes options:options temporaryTTL:0 callback:callback];
}

- (void)createConversationWithName:(NSString * _Nullable)name
                         clientIds:(NSArray<NSString *> *)clientIds
                        attributes:(NSDictionary * _Nullable)attributes
                           options:(AVIMConversationOption)options
                      temporaryTTL:(int32_t)temporaryTTL
                          callback:(void (^)(AVIMConversation * _Nullable, NSError * _Nullable))callback
{
    for (NSString *item in clientIds) {
        if (item.length > kClientIdLengthLimit || item.length == 0) {
            [self invokeInUserInteractQueue:^{
                callback(nil, LCErrorInternal([NSString stringWithFormat:@"client id's length should in range [1 %lu].", kClientIdLengthLimit]));
            }];
            return;
        }
    }
    
    BOOL unique = options & AVIMConversationOptionUnique;
    BOOL transient = options & AVIMConversationOptionTransient;
    BOOL temporary = options & AVIMConversationOptionTemporary;
    
    if ((unique && transient) || (unique && temporary) || (transient && temporary)) {
        [self invokeInUserInteractQueue:^{
            callback(nil, LCErrorInternal(@"options invalid."));
        }];
        return;
    }
    
    NSMutableArray<NSString *> *members = ({
        NSMutableSet<NSString *> *set = [NSMutableSet setWithArray:(clientIds ?: @[])];
        [set addObject:self->_clientId];
        set.allObjects.mutableCopy;
    });
    
    [self getSignatureWithConversationId:nil action:AVIMSignatureActionStart actionOnClientIds:members.copy callback:^(AVIMSignature *signature) {
        
        AssertRunInQueue(self->_internalSerialQueue);
        
        if (signature && signature.error) {
            [self invokeInUserInteractQueue:^{
                callback(nil, signature.error);
            }];
            return;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = ({
            
            AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
            AVIMConvCommand *convCommand = [AVIMConvCommand new];
            
            outCommand.cmd = AVIMCommandType_Conv;
            outCommand.op = AVIMOpType_Start;
            outCommand.convMessage = convCommand;
            
            convCommand.attr = ({
                AVIMJsonObjectMessage *jsonObjectMessage = nil;
                NSMutableDictionary *dic = [NSMutableDictionary dictionary];
                if (name) {
                    dic[AVIMConversationKeyName] = name;
                }
                if (attributes) {
                    dic[AVIMConversationKeyAttributes] = attributes;
                }
                if (dic.count > 0) {
                    NSString *jsonString = ({
                        NSError *error = nil;
                        NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:&error];
                        if (error) {
                            [self invokeInUserInteractQueue:^{
                                callback(nil, error);
                            }];
                            return;
                        }
                        [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    });
                    if (jsonString) {
                        jsonObjectMessage = [AVIMJsonObjectMessage new];
                        jsonObjectMessage.data_p = jsonString;
                    }
                }
                jsonObjectMessage;
            });
            
            if (transient) {
                convCommand.transient = transient;
            } else {
                if (temporary) {
                    convCommand.tempConv = temporary;
                    if (temporaryTTL > 0) {
                        convCommand.tempConvTtl = temporaryTTL;
                    }
                }
                else if (unique) {
                    convCommand.unique = unique;
                }
                convCommand.mArray = members;
            }
            
            if (signature && signature.signature && signature.timestamp && signature.nonce) {
                convCommand.s = signature.signature;
                convCommand.t = signature.timestamp;
                convCommand.n = signature.nonce;
            }
            
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = outCommand;
            commandWrapper;
        });
        
        [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                [self invokeInUserInteractQueue:^{
                    callback(nil, commandWrapper.error);
                }];
                return;
            }
            
            AVIMGenericCommand *inCommand = commandWrapper.inCommand;
            AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
            NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
            if (!conversationId) {
                [self invokeInUserInteractQueue:^{
                    callback(nil, ({
                        AVIMErrorCode code = AVIMErrorCodeInvalidCommand;
                        LCError(code, AVIMErrorMessage(code), nil);
                    }));
                }];
                return;
            }
            
            AVIMConversation *conversation = ({
                AVIMConversation *conversation = [self->_conversationManager conversationForId:conversationId];
                if (conversation) {
                    NSMutableDictionary *mutableDic = [NSMutableDictionary dictionary];
                    if (name) {
                        mutableDic[AVIMConversationKeyName] = name;
                    }
                    if (attributes) {
                        mutableDic[AVIMConversationKeyAttributes] = attributes.mutableCopy;
                    }
                    [conversation updateRawJSONDataWith:mutableDic];
                } else {
                    NSMutableDictionary *mutableDic = ({
                        NSMutableDictionary *mutableDic = [NSMutableDictionary dictionary];
                        if (name) {
                            mutableDic[AVIMConversationKeyName] = name;
                        }
                        if (attributes) {
                            mutableDic[AVIMConversationKeyAttributes] = attributes.mutableCopy;
                        }
                        if (convCommand.hasCdate) {
                            mutableDic[AVIMConversationKeyCreatedAt] = convCommand.cdate;
                        }
                        if (convCommand.hasTempConvTtl) {
                            mutableDic[AVIMConversationKeyTemporaryTTL] = @(convCommand.tempConvTtl);
                        }
                        if (convCommand.hasUniqueId) {
                            mutableDic[AVIMConversationKeyUniqueId] = convCommand.uniqueId;
                        }
                        mutableDic[AVIMConversationKeyUnique] = @(unique);
                        mutableDic[AVIMConversationKeyTransient] = @(transient);
                        mutableDic[AVIMConversationKeySystem] = @(false);
                        mutableDic[AVIMConversationKeyTemporary] = @(temporary);
                        mutableDic[AVIMConversationKeyCreator] = self->_clientId;
                        mutableDic[AVIMConversationKeyMembers] = members;
                        mutableDic[AVIMConversationKeyObjectId] = conversationId;
                        mutableDic;
                    });
                    conversation = [AVIMConversation conversationWithRawJSONData:mutableDic client:self];
                    if (conversation) {
                        [self->_conversationManager insertConversation:conversation];
                    }
                }
                conversation;
            });
            
            [self invokeInUserInteractQueue:^{
                callback(conversation, nil);
            }];
        }];
        
        [self sendCommandWrapper:commandWrapper];
    }];
}

// MARK: - Conversations Instance

- (AVIMConversation *)conversationForId:(NSString *)conversationId
{
    AssertNotRunInQueue(self->_internalSerialQueue);
    if (!conversationId) {
        return nil;
    }
    __block AVIMConversation *conv = nil;
    dispatch_sync(self->_internalSerialQueue, ^{
        conv = [self->_conversationManager conversationForId:conversationId];
    });
    return conv;
}

- (void)getConversationsFromMemoryWith:(NSArray<NSString *> *)conversationIds
                              callback:(void (^)(NSArray<AVIMConversation *> * _Nullable))callback
{
    if (!conversationIds || conversationIds.count == 0) {
        [self invokeInUserInteractQueue:^{
            callback(nil);
        }];
        return;
    }
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        NSMutableArray<AVIMConversation *> *array = [NSMutableArray array];
        for (NSString *conversationId in conversationIds) {
            AVIMConversation *conv = [client->_conversationManager conversationForId:conversationId];
            if (conv) {
                [array addObject:conv];
            }
        }
        [client invokeInUserInteractQueue:^{
            callback(array);
        }];
    }];
}

- (void)removeConversationsInMemoryWith:(NSArray<NSString *> *)conversationIds
                               callback:(void (^)(void))callback
{
    if (!conversationIds || conversationIds.count == 0) {
        [self invokeInUserInteractQueue:^{
            callback();
        }];
        return;
    }
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        [client->_conversationManager removeConversationsWithIds:conversationIds];
        [client invokeInUserInteractQueue:^{
            callback();
        }];
    }];
}

- (void)removeAllConversationsInMemoryWith:(void (^)(void))callback
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        [client->_conversationManager removeAllConversations];
        [client invokeInUserInteractQueue:^{
            callback();
        }];
    }];
}

// MARK: - Misc

- (void)queryOnlineClientsInClients:(NSArray<NSString *> *)clients
                           callback:(void (^)(NSArray<NSString *> *, NSError * _Nullable))callback
{
    ({
        if (!clients || clients.count == 0) {
            [self invokeInUserInteractQueue:^{
                callback(@[], nil);
            }];
            return;
        }
        NSUInteger clientsCountMax = 20;
        if (clients.count > clientsCountMax) {
            [self invokeInUserInteractQueue:^{
                callback(nil, LCErrorInternal([NSString stringWithFormat:@"clients count beyond max %lu", clientsCountMax]));
            }];
            return;
        }
    });
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMSessionCommand *sessionCommand = [AVIMSessionCommand new];
        
        outCommand.cmd = AVIMCommandType_Session;
        outCommand.op = AVIMOpType_Query;
        outCommand.sessionMessage = sessionCommand;
        sessionCommand.sessionPeerIdsArray = clients.mutableCopy;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [self invokeInUserInteractQueue:^{
                callback(nil, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMSessionCommand *sessionCommand = (inCommand.hasSessionMessage ? inCommand.sessionMessage : nil);
        if (!sessionCommand) {
            [self invokeInUserInteractQueue:^{
                callback(nil, ({
                    AVIMErrorCode code = AVIMErrorCodeInvalidCommand;
                    LCError(code, AVIMErrorMessage(code), nil);
                }));
            }];
            return;
        }
        
        [self invokeInUserInteractQueue:^{
            callback(sessionCommand.onlineSessionPeerIdsArray, nil);
        }];
    }];
    
    [self sendCommandWrapper:commandWrapper];
}

- (AVIMConversationQuery *)conversationQuery
{
    AVIMConversationQuery *query = [[AVIMConversationQuery alloc] init];
    query.client = self;
    return query;
}

- (AVIMConversation *)conversationWithKeyedConversation:(AVIMKeyedConversation *)keyedConversation
{
    AssertNotRunInQueue(self->_internalSerialQueue);
    NSString *conversationId = nil;
    NSMutableDictionary *rawDataDic = [keyedConversation.rawDataDic mutableCopy];
    if (rawDataDic) {
        conversationId = [NSString lc__decodingDictionary:rawDataDic key:AVIMConversationKeyObjectId];
    } else {
        rawDataDic = [NSMutableDictionary dictionary];
        if (keyedConversation.conversationId) {
            conversationId = keyedConversation.conversationId;
            rawDataDic[AVIMConversationKeyObjectId] = conversationId;
        }
        if (keyedConversation.creator) {
            rawDataDic[AVIMConversationKeyCreator] = keyedConversation.creator;
        }
        if (keyedConversation.createAt) {
            rawDataDic[AVIMConversationKeyCreatedAt] = keyedConversation.createAt;
        }
        if (keyedConversation.updateAt) {
            rawDataDic[AVIMConversationKeyUpdatedAt] = keyedConversation.updateAt;
        }
        if (keyedConversation.name) {
            rawDataDic[AVIMConversationKeyName] = keyedConversation.name;
        }
        if (keyedConversation.members) {
            rawDataDic[AVIMConversationKeyMembers] = keyedConversation.members;
        }
        if (keyedConversation.attributes) {
            rawDataDic[AVIMConversationKeyAttributes] = keyedConversation.attributes;
        }
        if (keyedConversation.uniqueId) {
            rawDataDic[AVIMConversationKeyUniqueId] = keyedConversation.uniqueId;
        }
        if (keyedConversation.unique) {
            rawDataDic[AVIMConversationKeyUnique] = @(keyedConversation.unique);
        }
        if (keyedConversation.transient) {
            rawDataDic[AVIMConversationKeyTransient] = @(keyedConversation.transient);
        }
        if (keyedConversation.system) {
            rawDataDic[AVIMConversationKeySystem] = @(keyedConversation.system);
        }
        if (keyedConversation.temporary) {
            rawDataDic[AVIMConversationKeyTemporary] = @(keyedConversation.temporary);
        }
        if (keyedConversation.temporaryTTL) {
            rawDataDic[AVIMConversationKeyTemporaryTTL] = @(keyedConversation.temporaryTTL);
        }
        if (keyedConversation.muted) {
            rawDataDic[AVIMConversationKeyMutedMembers] = @(keyedConversation.muted);
        }
    }
    if (keyedConversation.lastMessage) {
        AVIMMessage *message = keyedConversation.lastMessage;
        [rawDataDic removeObjectsForKeys:({
            @[AVIMConversationKeyLastMessageContent,
              AVIMConversationKeyLastMessageId,
              AVIMConversationKeyLastMessageFrom,
              AVIMConversationKeyLastMessageTimestamp,
              AVIMConversationKeyLastMessagePatchTimestamp,
              AVIMConversationKeyLastMessageMentionAll,
              AVIMConversationKeyLastMessageMentionPids];
        })];
        if (message.content) {
            rawDataDic[AVIMConversationKeyLastMessageContent] = message.content;
        }
        if (message.messageId) {
            rawDataDic[AVIMConversationKeyLastMessageId] = message.messageId;
        }
        if (message.clientId) {
            rawDataDic[AVIMConversationKeyLastMessageFrom] = message.clientId;
        }
        if (message.sendTimestamp) {
            rawDataDic[AVIMConversationKeyLastMessageTimestamp] = @(message.sendTimestamp);
        }
        if (message.updatedAt) {
            rawDataDic[AVIMConversationKeyLastMessagePatchTimestamp] = @(message.updatedAt.timeIntervalSince1970 * 1000.0);
        }
        if (message.mentionAll) {
            rawDataDic[AVIMConversationKeyLastMessageMentionAll] = @(message.mentionAll);
        }
        if (message.mentionList) {
            rawDataDic[AVIMConversationKeyLastMessageMentionPids] = message.mentionList;
        }
    }
    if (!conversationId) {
        return nil;
    }
    __block AVIMConversation *conv = nil;
    dispatch_sync(self->_internalSerialQueue, ^{
        conv = [self->_conversationManager conversationForId:conversationId];
        if (!conv) {
            conv = [AVIMConversation conversationWithRawJSONData:rawDataDic client:self];
            if (conv) {
                [self->_conversationManager insertConversation:conv];
            }
        }
    });
    return conv;
}

- (void)conversation:(AVIMConversation *)conversation didUpdateForKeys:(NSArray<AVIMConversationUpdatedKey> *)keys
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    if (keys.count == 0) {
        return;
    }
    
    id <AVIMClientDelegate> delegate = self->_delegate;
    SEL sel = @selector(conversation:didUpdateForKey:);
    if (delegate && [delegate respondsToSelector:sel]) {
        for (AVIMConversationUpdatedKey key in keys) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didUpdateForKey:key];
            }];
        }
    }
}

// MARK: - IM Protocol Options

+ (NSMutableDictionary *)sessionProtocolOptions
{
    static dispatch_once_t onceToken;
    static NSMutableDictionary *options;
    dispatch_once(&onceToken, ^{
        options = [NSMutableDictionary dictionary];
    });
    return options;
}

+ (void)setUnreadNotificationEnabled:(BOOL)enabled
{
    if (clientHasInstantiated) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"this method should be invoked before instantiation of AVIMClient."];
        return;
    }
    AVIMClient.sessionProtocolOptions[kAVIMUserOptionUseUnread] = @(enabled);
}

/// deprecated
+ (void)setUserOptions:(NSDictionary *)userOptions
{
    if (clientHasInstantiated) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"this method should be invoked before instantiation of AVIMClient."];
        return;
    }
    if (!userOptions) {
        return;
    }
    [AVIMClient.sessionProtocolOptions addEntriesFromDictionary:userOptions];
}

@end
