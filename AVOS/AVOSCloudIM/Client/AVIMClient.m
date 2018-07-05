//
//  AVIM.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMClient_Internal.h"
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
#import "SDMacros.h"
#import "AVIMUserOptions.h"
#import "AVPaasClient.h"
#import "AVIMKeyedConversation_internal.h"
#import "AVErrorUtils.h"
#import "AVIMConversationMemberInfo_Internal.h"

#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

static BOOL AVIMClientHasInstantiated = false;

NSUInteger const kLC_ClientId_MaxLength = 64;
static NSString * const kLC_SessionTag_Default = @"default";

static NSInteger const kLC_Code_SessionConflict = 4111;
NSInteger const kLC_Code_SessionTokenExpired = 4112;

NSString * const kTemporaryConversationIdPrefix = @"_tmp:";

AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastMessage = @"lastMessage";
AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastMessageAt = @"lastMessageAt";
AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastReadAt = @"lastReadAt";
AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastDeliveredAt = @"lastDeliveredAt";
AVIMConversationUpdatedKey AVIMConversationUpdatedKeyUnreadMessagesCount = @"unreadMessagesCount";
AVIMConversationUpdatedKey AVIMConversationUpdatedKeyUnreadMessagesMentioned = @"unreadMessagesMentioned";

// @see https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md 
typedef NS_OPTIONS(NSUInteger, LCIMSessionConfigOptions) {
    LCIMSessionConfigOptions_Patch = 1 << 0,
    LCIMSessionConfigOptions_TempConv = 1 << 1,
    LCIMSessionConfigOptions_AutoBindInstallation = 1 << 2,
    LCIMSessionConfigOptions_TransientACK = 1 << 3,
    LCIMSessionConfigOptions_ReliableNotification = 1 << 4,
    LCIMSessionConfigOptions_CallbackResultSlice = 1 << 5,
    LCIMSessionConfigOptions_GroupChatReadReceipt = 1 << 6
};

@implementation AVIMClient {
    // public
    __weak id<AVIMClientDelegate> _delegate;
    __weak id<AVIMSignatureDataSource> _signatureDataSource;
    NSString *_clientId;
    NSString *_tag;
    AVUser *_user;
    AVIMClientStatus _status;
    BOOL _messageQueryCacheEnabled;
    
    // web socket
    AVIMWebSocketWrapper *_socketWrapper;
    
    // session
    int64_t _sessionConfigBitmap;
    NSString *_sessionToken;
    NSTimeInterval _sessionTokenExpireTimestamp;
    int64_t _lastPatchTimestamp;
    int64_t _lastUnreadTimestamp;
    
    // APNs
    AVInstallation *_installation;
    NSString *_deviceToken;
    dispatch_block_t _addClientIdToChannels_block;
    dispatch_block_t _removeClientIdToChannels_block;
    dispatch_block_t _uploadDeviceToken_block;
    BOOL _isDeviceTokenUploaded;
    
    // internal queue
    dispatch_queue_t _internalSerialQueue;
    dispatch_queue_t _signatureQueue;
    
    // internal container
    NSMutableDictionary<NSString *, AVIMConversation *> *_conversationDictionary;
    NSMutableDictionary<NSString *, NSMutableArray<void (^)(AVIMConversation *, NSError *)> *> *_queryConvCallbackDictionary;
    
    // disk cache
    LCIMConversationCache *_conversationCache;
    
    // user interact queue
    dispatch_queue_t _userInteractQueue;
}

+ (instancetype)alloc
{
    AVIMClientHasInstantiated = YES;
    return [super alloc];
}

+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds
{
    [AVIMWebSocketWrapper setTimeoutIntervalInSeconds:seconds];
}

#if DEBUG
- (void)assertRunInInternalSerialQueue
{
    void *key = (__bridge void *)(self->_internalSerialQueue);
    NSString *message = [NSString stringWithFormat:@"this method should run in %@", ivarName(self, _internalSerialQueue)];
    NSAssert(dispatch_get_specific(key) == key, message);
}
- (void)assertNotRunInInternalSerialQueue
{
    void *key = (__bridge void *)(self->_internalSerialQueue);
    NSString *message = [NSString stringWithFormat:@"this method should not run in %@", ivarName(self, _internalSerialQueue)];
    NSAssert(dispatch_get_specific(key) != key, message);
}
#endif

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
#if DEBUG
    assert([AVIMConversationUpdatedKeyLastMessage isEqualToString:keyPath(AVIMConversation.alloc, lastMessage)]);
    assert([AVIMConversationUpdatedKeyLastMessageAt isEqualToString:keyPath(AVIMConversation.alloc, lastMessageAt)]);
    assert([AVIMConversationUpdatedKeyLastReadAt isEqualToString:keyPath(AVIMConversation.alloc, lastReadAt)]);
    assert([AVIMConversationUpdatedKeyLastDeliveredAt isEqualToString:keyPath(AVIMConversation.alloc, lastDeliveredAt)]);
    assert([AVIMConversationUpdatedKeyUnreadMessagesCount isEqualToString:keyPath(AVIMConversation.alloc, unreadMessagesCount)]);
    assert([AVIMConversationUpdatedKeyUnreadMessagesMentioned isEqualToString:keyPath(AVIMConversation.alloc, unreadMessagesMentioned)]);
#endif
    
    self->_clientId = ({
        if (!clientId || clientId.length > kLC_ClientId_MaxLength || clientId.length == 0) {
            [NSException raise:NSInvalidArgumentException
                        format:@"clientId invalid or length not in range [1 %lu].", kLC_ClientId_MaxLength];
        }
        clientId.copy;
    });
    
    self->_tag = ({
        if ([tag isEqualToString:kLC_SessionTag_Default]) {
            [NSException raise:NSInvalidArgumentException
                        format:@"%@ is reserved.", kLC_SessionTag_Default];
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
    
    self->_messageQueryCacheEnabled = true;
    
    self->_conversationDictionary = [NSMutableDictionary dictionary];
    self->_queryConvCallbackDictionary = [NSMutableDictionary dictionary];
    
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
    
    self->_socketWrapper = ({
        AVIMWebSocketWrapper *socketWrapper = [AVIMWebSocketWrapper newWithDelegate:self];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self
                   selector:@selector(websocketOpened:)
                       name:AVIM_NOTIFICATION_WEBSOCKET_OPENED
                     object:socketWrapper];
        [center addObserver:self
                   selector:@selector(websocketClosed:)
                       name:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                     object:socketWrapper];
        [center addObserver:self
                   selector:@selector(websocketReconnect:)
                       name:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT
                     object:socketWrapper];
        socketWrapper;
    });

    self->_installation = ({
        self->_deviceToken = installation.deviceToken;
        self->_isDeviceTokenUploaded = false;
        self->_addClientIdToChannels_block = nil;
        self->_removeClientIdToChannels_block = nil;
        self->_uploadDeviceToken_block = nil;
        [installation addObserver:self
                       forKeyPath:keyPath(installation, deviceToken)
                          options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                          context:nil];
        installation;
    });
    
    self->_conversationCache = ({
        LCIMConversationCache *cache = [[LCIMConversationCache alloc] initWithClientId:self->_clientId];
        cache.client = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [cache cleanAllExpiredConversations];
        });
        cache;
    });
    
    self->_userInteractQueue = dispatch_get_main_queue();
}

// MARK: - Dealloc

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self->_installation removeObserver:self forKeyPath:keyPath(self->_installation, deviceToken)];
    [self->_socketWrapper close];
}

// MARK: - Queue

- (dispatch_queue_t)internalSerialQueue
{
    return self->_internalSerialQueue;
}

- (dispatch_queue_t)userInteractQueue
{
    return self->_userInteractQueue;
}

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
        
        AssertRunInInternalSerialQueue(self);
        
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
                callback(false, LCErrorInternal(@"can't open before last open done."));
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
                    sessionCommand.deviceToken = client->_deviceToken ?: AVUtils.deviceUUID;
                    sessionCommand.ua = @"ios" @"/" SDK_VERSION;
                    
                    LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
                    commandWrapper.outCommand = outCommand;
                    commandWrapper;
                });
                
                [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
                    
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
                    [client addClientIdToChannels:1];
                    [client resetUploadingDeviceToken];
                    [client uploadDeviceToken:1];
                    
                    [client invokeInUserInteractQueue:^{
                        callback(true, nil);
                    }];
                }];
                
                [client->_socketWrapper sendCommandWrapper:commandWrapper];
            }];
        }];
    }];
}

- (void)resumeWithCallback:(void (^)(BOOL succeeded, NSError *error))callback
{
    AssertRunInInternalSerialQueue(self);
    
    NSString *imSessionToken = self->_sessionToken;
    
    if (!imSessionToken) {
        callback(false, LCErrorInternal(@"session not open or did close."));
        return;
    }
    
    if (self->_status == AVIMClientStatusOpened) {
        callback(true, nil);
        return;
    }
    
    LCIMProtobufCommandWrapper * (^ newReopenCommand_block)(AVIMSignature *, NSString *) = ^(AVIMSignature *signature, NSString *sessionToken) {
        
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
            sessionCommand.deviceToken = self->_deviceToken ?: AVUtils.deviceUUID;
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
    
    void(^ handleSessionTokenExpired_block)(void) = ^(void) {
        [self getSessionOpenSignatureWithCallback:^(AVIMSignature *signature) {
            AssertRunInInternalSerialQueue(self);
            if (signature && signature.error) {
                callback(false, signature.error);
                return;
            }
            LCIMProtobufCommandWrapper *commandWrapper = newReopenCommand_block(signature, nil);
            [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
                if (commandWrapper.error) {
                    callback(false, commandWrapper.error);
                    return;
                }
                AVIMGenericCommand *inCommand = commandWrapper.inCommand;
                AVIMSessionCommand *sessionCommand = (inCommand.hasSessionMessage ? inCommand.sessionMessage : nil);
                NSString *sessionToken = (sessionCommand.hasSt ? sessionCommand.st : nil);
                if (!sessionToken) {
                    callback(false, ({
                        AVIMErrorCode code = AVIMErrorCodeInvalidCommand;
                        LCError(code, AVIMErrorMessage(code), nil);
                    }));
                    return;
                }
                self->_status = AVIMClientStatusOpened;
                [self setSessionToken:sessionToken ttl:(sessionCommand.hasStTtl ? sessionCommand.stTtl : 0)];
                if (!self->_isDeviceTokenUploaded) {
                    [self uploadDeviceToken:1];
                }
                callback(true, nil);
            }];
            [self->_socketWrapper sendCommandWrapper:commandWrapper];
        }];
    };
    
    LCIMProtobufCommandWrapper *commandWrapper = newReopenCommand_block(nil, imSessionToken);
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        if (commandWrapper.error) {
            if (commandWrapper.error.code == kLC_Code_SessionTokenExpired) {
                handleSessionTokenExpired_block();
            } else {
                callback(false, commandWrapper.error);
            }
            return;
        }
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMSessionCommand *sessionCommand = (inCommand.hasSessionMessage ? inCommand.sessionMessage : nil);
        NSString *sessionToken = (sessionCommand.hasSt ? sessionCommand.st : nil);
        if (!sessionToken) {
            callback(false, ({
                AVIMErrorCode code = AVIMErrorCodeInvalidCommand;
                LCError(code, AVIMErrorMessage(code), nil);
            }));
            return;
        }
        self->_status = AVIMClientStatusOpened;
        [self setSessionToken:sessionToken ttl:(sessionCommand.hasStTtl ? sessionCommand.stTtl : 0)];
        if (!self->_isDeviceTokenUploaded) {
            [self uploadDeviceToken:1];
        }
        callback(true, nil);
    }];
    [self->_socketWrapper sendCommandWrapper:commandWrapper];
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
            [client removeClientIdFromChannels:1];
            [client resetUploadingDeviceToken];
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
    AssertRunInInternalSerialQueue(self);
    NSParameterAssert(sessionToken);
    self->_sessionToken = sessionToken;
    self->_sessionTokenExpireTimestamp = NSDate.date.timeIntervalSince1970 + (NSTimeInterval)ttl;
}

- (void)clearSessionTokenAndTTL
{
    AssertRunInInternalSerialQueue(self);
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
            
            [client _sendCommandWrapper:commandWrapper];
            
        } else {
            
            callback(oldSessionToken, nil);
        }
    }];
}

// MARK: - APNs

- (void)addClientIdToChannels:(NSUInteger)delayInterval
{
    AssertRunInInternalSerialQueue(self);
    
    if (self->_removeClientIdToChannels_block) {
        dispatch_block_cancel(self->_removeClientIdToChannels_block);
        self->_removeClientIdToChannels_block = nil;
    }
    
    if (self->_addClientIdToChannels_block) {
        dispatch_block_cancel(self->_addClientIdToChannels_block);
        self->_addClientIdToChannels_block = nil;
    }
    
    if (!self->_deviceToken || self->_deviceToken.length == 0) {
        return;
    }
    
    dispatch_block_t block = dispatch_block_create(0, ^{
        self->_addClientIdToChannels_block = nil;
        [self->_installation addUniqueObject:self->_clientId forKey:@"channels"];
        [self->_installation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if (error) {
#if DEBUG
                if (self.assertInternalQuietCallback) {
                    self.assertInternalQuietCallback(error);
                }
#endif
                AVLoggerError(AVLoggerDomainIM, @"%@", error);
                if (error.code != kAVErrorInvalidChannelName && delayInterval > 0) {
                    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
                        [client addClientIdToChannels:delayInterval * 2];
                    }];
                }
            }
        }];
    });
    self->_addClientIdToChannels_block = block;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayInterval * NSEC_PER_SEC), self->_internalSerialQueue, block);
}

- (void)removeClientIdFromChannels:(NSUInteger)delayInterval
{
    AssertRunInInternalSerialQueue(self);
    
    if (self->_addClientIdToChannels_block) {
        dispatch_block_cancel(self->_addClientIdToChannels_block);
        self->_addClientIdToChannels_block = nil;
    }
    
    if (self->_removeClientIdToChannels_block) {
        dispatch_block_cancel(self->_removeClientIdToChannels_block);
        self->_removeClientIdToChannels_block = nil;
    }
    
    if (!self->_deviceToken || self->_deviceToken.length == 0) {
        return;
    }
    
    dispatch_block_t block = dispatch_block_create(0, ^{
        self->_removeClientIdToChannels_block = nil;
        [self->_installation removeObject:self->_clientId forKey:@"channels"];
        [self->_installation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if (error) {
#if DEBUG
                if (self.assertInternalQuietCallback) {
                    self.assertInternalQuietCallback(error);
                }
#endif
                AVLoggerError(AVLoggerDomainIM, @"%@", error);
                if (error.code != kAVErrorInvalidChannelName && delayInterval > 0) {
                    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
                        [client removeClientIdFromChannels:delayInterval * 2];
                    }];
                }
            }
        }];
    });
    self->_removeClientIdToChannels_block = block;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayInterval * NSEC_PER_SEC), self->_internalSerialQueue, block);
}

- (void)uploadDeviceToken:(NSUInteger)delayInterval
{
    AssertRunInInternalSerialQueue(self);
    
    NSString *deviceToken = self->_deviceToken;
    
    if (!deviceToken || deviceToken.length == 0 || self->_status != AVIMClientStatusOpened) {
        return;
    }
    
    if (self->_uploadDeviceToken_block) {
        dispatch_block_cancel(self->_uploadDeviceToken_block);
        self->_uploadDeviceToken_block = nil;
    }
    
    dispatch_block_t block = dispatch_block_create(0, ^{
        self->_uploadDeviceToken_block = nil;
        LCIMProtobufCommandWrapper *commandWrapper = ({
            AVIMGenericCommand *outCommand = [[AVIMGenericCommand alloc] init];
            AVIMReportCommand *reportCommand = [[AVIMReportCommand alloc] init];
            outCommand.cmd = AVIMCommandType_Report;
            outCommand.op = AVIMOpType_Upload;
            outCommand.reportMessage = reportCommand;
            reportCommand.initiative = true;
            reportCommand.type = @"token";
            reportCommand.data_p = deviceToken;
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = outCommand;
            commandWrapper;
        });
        [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
            if (commandWrapper.error) {
#if DEBUG
                if (self.assertInternalQuietCallback) {
                    self.assertInternalQuietCallback(commandWrapper.error);
                }
#endif
                AVLoggerError(AVLoggerDomainIM, @"%@", commandWrapper.error);
                if (delayInterval > 0) {
                    [self uploadDeviceToken:delayInterval * 2];
                }
            } else {
                self->_isDeviceTokenUploaded = true;
            }
        }];
        [self _sendCommandWrapper:commandWrapper];
    });
    self->_uploadDeviceToken_block = block;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayInterval * NSEC_PER_SEC), self->_internalSerialQueue, block);
}

- (void)resetUploadingDeviceToken
{
    AssertRunInInternalSerialQueue(self);
    
    self->_isDeviceTokenUploaded = false;
    if (self->_uploadDeviceToken_block) {
        dispatch_block_cancel(self->_uploadDeviceToken_block);
        self->_uploadDeviceToken_block = nil;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        if (object == client->_installation) {
            if (keyPath == keyPath(client->_installation, deviceToken)) {
                NSString *value = [NSString lc__decodingDictionary:change key:NSKeyValueChangeNewKey];
                if (value && value.length != 0 && ![value isEqualToString:client->_deviceToken]) {
                    client->_deviceToken = value;
                    if (client->_sessionToken) {
                        [client addClientIdToChannels:1];
                        [client resetUploadingDeviceToken];
                        [client uploadDeviceToken:1];
                    }
                }
            }
        }
    }];
}

// MARK: - WebSocket Notification

- (void)websocketOpened:(NSNotification *)notification
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        if (!client->_sessionToken) {
            return;
        }
        
        [client resumeWithCallback:^(BOOL succeeded, NSError *error) {
            if (error) {
                AVLoggerError(AVLoggerDomainIM, @"%@", error);
            } else {
                id <AVIMClientDelegate> delegate = client->_delegate;
                if (delegate) {
                    [client invokeInUserInteractQueue:^{
                        [delegate imClientResumed:client];
                    }];
                }
            }
        }];
    }];
}

- (void)websocketClosed:(NSNotification *)notification
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        if (!client->_sessionToken) {
            return;
        }
        
        BOOL willReconnect = [notification.userInfo[@"willReconnect"] boolValue];
        if (willReconnect) {
            client->_status = AVIMClientStatusPaused;
            id<AVIMClientDelegate> delegate = client->_delegate;
            if (delegate) {
                [client invokeInUserInteractQueue:^{
                    [delegate imClientPaused:client];
                }];
            }
        } else {
            NSError *error = notification.userInfo[@"error"];
            client->_status = AVIMClientStatusClosed;
            [client clearSessionTokenAndTTL];
            id<AVIMClientDelegate> delegate = client->_delegate;
            if (delegate) {
                [client invokeInUserInteractQueue:^{
                    [delegate imClientClosed:client error:error];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    SEL sel = @selector(imClientPaused:error:);
                    if ([delegate respondsToSelector:sel]) {
                        [delegate imClientPaused:client error:error];
                    }
#pragma clang diagnostic pop
                }];
            }
        }
    }];
}

- (void)websocketReconnect:(NSNotification *)notification
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        if (!client->_sessionToken) {
            return;
        }
        
        client->_status = AVIMClientStatusResuming;
        id <AVIMClientDelegate> delegate = client->_delegate;
        if (delegate) {
            [client invokeInUserInteractQueue:^{
                [delegate imClientResuming:client];
            }];
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
                AssertRunInInternalSerialQueue(client);
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

- (void)sendCommand:(AVIMGenericCommand *)command
{
    dispatch_async(_internalSerialQueue, ^{
        
        [self _sendCommand:command];
    });
}

- (void)_sendCommand:(AVIMGenericCommand *)command
{
    AssertRunInInternalSerialQueue(self);
    
    if (_status != AVIMClientStatusOpened) {
        
        AVIMCommandResultBlock callback = command.callback;
        
        if (callback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(command, nil, ({
                    AVIMErrorCode code = AVIMErrorCodeClientNotOpen;
                    LCError(code, AVIMErrorMessage(code), nil);
                }));
            });
        }
        
        return;
    }
    
    [_socketWrapper sendCommand:command];
}

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        [client _sendCommandWrapper:commandWrapper];
    }];
}

- (void)_sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper
{
    AssertRunInInternalSerialQueue(self);
    
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
    
    [self->_socketWrapper sendCommandWrapper:commandWrapper];
}

// MARK: - WebSocket Delegate

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didOccurError:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        if (commandWrapper.hasCallback && commandWrapper.error) {
            [commandWrapper executeCallbackAndSetItToNil];
        }
    }];
}

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didReceiveCallback:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        if (commandWrapper.hasCallback) {
            [commandWrapper executeCallbackAndSetItToNil];
        }
        
        if (commandWrapper.error && commandWrapper.error.code == kLC_Code_SessionConflict) {
            client->_status = AVIMClientStatusClosed;
            [client clearSessionTokenAndTTL];
            [client removeClientIdFromChannels:1];
            [client resetUploadingDeviceToken];
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
    if (!commandWrapper.inCommand) {
        return;
    }
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

// MARK: - Command Process

- (void)process_session_closed:(AVIMGenericCommand *)inCommand
{
    AssertRunInInternalSerialQueue(self);
    
    AVIMSessionCommand *sessionCommand = (inCommand.hasSessionMessage ? inCommand.sessionMessage : nil);
    if (!sessionCommand) {
        return;
    }
    
    self->_status = AVIMClientStatusClosed;
    [self clearSessionTokenAndTTL];
    
    int32_t code = (sessionCommand.hasCode ? sessionCommand.code : 0);
    
    if (code == kLC_Code_SessionConflict) {
        [self removeClientIdFromChannels:1];
        [self resetUploadingDeviceToken];
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    
    NSDictionary *attr = ({
        AVIMJsonObjectMessage *jsonObjectMessage = (convCommand.hasAttr ? convCommand.attr : nil);
        NSString *jsonString = (jsonObjectMessage.hasData_p ? jsonObjectMessage.data_p : nil);
        NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
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
        NSError *error = nil;
        NSDictionary *attrModified = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error || ![NSDictionary lc__checkingType:attrModified]) {
            return;
        }
        attrModified;
    });
    
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    NSDate *updateDate = LCDateFromString((convCommand.hasUdate ? convCommand.udate : nil));
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    AVIMConvMemberInfo *convMemberInfo = (convCommand.hasInfo ? convCommand.info : nil);
    NSString *memberId = (convMemberInfo.hasPid ? convMemberInfo.pid : nil);
    NSString *roleKey = (convMemberInfo.hasRole ? convMemberInfo.role : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMPatchCommand *patchCommand = (inCommand.hasPatchMessage ? inCommand.patchMessage : nil);
    if (!patchCommand) {
        return;
    }
    
    for (AVIMPatchItem *patchItem in patchCommand.patchesArray) {
        if (patchItem.hasPatchTimestamp && patchItem.patchTimestamp > self->_lastPatchTimestamp) {
            self->_lastPatchTimestamp = patchItem.patchTimestamp;
        }
        NSString *conversationId = (patchItem.hasCid ? patchItem.cid : nil);
        if (!conversationId) {
            continue;
        }
        [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
            if (error) { return; }
            AVIMMessage *patchMessage = [conversation process_patch_modified:patchItem];
            id <AVIMClientDelegate> delegate = self->_delegate;
            SEL sel = @selector(conversation:messageHasBeenUpdated:);
            if (patchMessage && delegate && [delegate respondsToSelector:sel]) {
                [self invokeInUserInteractQueue:^{
                    [delegate conversation:conversation messageHasBeenUpdated:patchMessage];
                }];
            }
        }];
    }
    
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
        [self _sendCommandWrapper:ackCommandWrapper];
    });
}

- (void)process_rcp:(AVIMGenericCommand *)inCommand
{
    AssertRunInInternalSerialQueue(self);
    
    AVIMRcpCommand *rcpCommand = (inCommand.hasRcpMessage ? inCommand.rcpMessage : nil);
    NSString *conversationId = (rcpCommand.hasCid ? rcpCommand.cid : nil);
    if (!conversationId) {
        return;
    }
    BOOL isReadRcp = (rcpCommand.hasRead ? rcpCommand.read : false);
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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
    AssertRunInInternalSerialQueue(self);
    
    AVIMUnreadCommand *unreadCommand = (inCommand.hasUnreadMessage ? inCommand.unreadMessage : nil);
    if (!unreadCommand) {
        return;
    }
    
    int64_t notifTime = (unreadCommand.hasNotifTime ? unreadCommand.notifTime : 0);
    if (notifTime > self->_lastUnreadTimestamp) {
        self->_lastUnreadTimestamp = notifTime;
    }
    
    for (AVIMUnreadTuple *unreadTuple in unreadCommand.convsArray) {
        NSString *conversationId = (unreadTuple.hasCid ? unreadTuple.cid : nil);
        if (!conversationId) {
            continue;
        }
        [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
            if (error) { return; }
            NSUInteger unreadCount = [conversation process_unread:unreadTuple];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            id <AVIMClientDelegate> delegate = self->_delegate;
            SEL selector = @selector(conversation:didReceiveUnread:);
            if (delegate && [delegate respondsToSelector:selector]) {
                [self invokeInUserInteractQueue:^{
                    [delegate conversation:conversation didReceiveUnread:unreadCount];
                }];
            }
#pragma clang diagnostic pop
        }];
    }
}

- (void)process_direct:(AVIMGenericCommand *)inCommand
{
    AssertRunInInternalSerialQueue(self);
    
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
        [self _sendCommandWrapper:ackCommandWrapper];
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
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

// MARK: - Conversation Query

- (void)queryConversationWithId:(NSString *)conversationId
                       callback:(void (^)(AVIMConversation *conversation, NSError *error))callback
{
    AssertRunInInternalSerialQueue(self);
    NSParameterAssert(conversationId);
    
    [self queryConversationWithId:conversationId
                      queryOption:0
                         callback:callback];
}

- (void)queryConversationWithId:(NSString *)conversationId
                    queryOption:(AVIMConversationQueryOption)queryOption
                       callback:(void (^)(AVIMConversation *conversation, NSError *error))callback
{
    AssertRunInInternalSerialQueue(self);
    NSParameterAssert(conversationId);
    
    AVIMConversation *conversation = [self getConversationFromMemory:conversationId];
    if (conversation) {
        callback(conversation, nil);
    } else {
        [self queryConversationFromServerWithId:conversationId
                                    queryOption:queryOption
                                       callback:callback];
    }
}

- (void)queryConversationFromServerWithId:(NSString *)conversationId
                              queryOption:(AVIMConversationQueryOption)queryOption
                                 callback:(void (^)(AVIMConversation *conversation, NSError *error))callback
{
    AssertRunInInternalSerialQueue(self);
    NSParameterAssert(conversationId);
    
    ({
        NSMutableArray<void (^)(AVIMConversation *, NSError *)> *callbacks = ({
            self->_queryConvCallbackDictionary[conversationId];
        });
        if (callbacks) {
            [callbacks addObject:callback];
            return;
        }
    });
    
    BOOL isTemporaryConversation = [conversationId hasPrefix:kTemporaryConversationIdPrefix];
    
    LCIMProtobufCommandWrapper *commandWrapper = ({

        AVIMGenericCommand *outCommand = [[AVIMGenericCommand alloc] init];
        AVIMConvCommand *convCommand = [[AVIMConvCommand alloc] init];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_Query;
        outCommand.convMessage = convCommand;
        
        if (queryOption) {
            convCommand.flag = queryOption;
        }
        if (isTemporaryConversation) {
            convCommand.tempConvIdsArray = [NSMutableArray arrayWithObject:conversationId];
        } else {
            AVIMJsonObjectMessage *jsonObjectMessage = [[AVIMJsonObjectMessage alloc] init];
            convCommand.where = jsonObjectMessage;
            jsonObjectMessage.data_p = ({
                NSError *error = nil;
                NSData *data = ({
                    [NSJSONSerialization dataWithJSONObject:@{ @"objectId" : conversationId } options:0 error:&error];
                });
                if (error) {
                    callback(nil, error);
                    return;
                }
                [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            });
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        void(^ invokeAllCallback_block)(AVIMConversation *, NSError *) = ({
            NSMutableArray<void (^)(AVIMConversation *, NSError *)> *callbacks = ({
                self->_queryConvCallbackDictionary[conversationId];
            });
            if (callbacks) {
                [self->_queryConvCallbackDictionary removeObjectForKey:conversationId];
            }
            ^ (AVIMConversation *conversation, NSError *error) {
                for (void (^item_block)(AVIMConversation *, NSError *) in callbacks) {
                    item_block(conversation, error);
                }
            };
        });
        
        if (commandWrapper.error) {
            AVLoggerError(AVLoggerDomainIM, @"%@", commandWrapper.error);
            invokeAllCallback_block(nil, commandWrapper.error);
            return;
        }
        
        AVIMConversation *conversation = ({
            NSString *jsonString = commandWrapper.inCommand.convMessage.results.data_p;
            NSMutableDictionary *jsonData = ({
                NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                NSError *error = nil;
                NSMutableArray<NSMutableDictionary *> *results = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                if (error) {
                    AVLoggerError(AVLoggerDomainIM, @"%@", error);
                    invokeAllCallback_block(nil, error);
                    return;
                }
                results.firstObject;
            });
            if (![NSMutableDictionary lc__checkingType:jsonData] ||
                ![[NSString lc__decodingDictionary:jsonData key:kLCIMConv_objectId] isEqualToString:conversationId]) {
                NSError *error = ({
                    AVIMErrorCode code = AVIMErrorCodeInvalidCommand;
                    LCError(code, AVIMErrorMessage(code), nil);
                });
                AVLoggerError(AVLoggerDomainIM, @"%@", error);
                invokeAllCallback_block(nil, error);
                return;
            }
            AVIMConversation *conversation = [self getConversationFromMemory:conversationId];
            if (conversation) {
                [conversation setRawJSONData:jsonData];
            } else {
                conversation = [AVIMConversation conversationWithRawJSONData:jsonData client:self];
                if (conversation) {
                    [self cacheConversationToMemory:conversation];
                }
            }
            if (!isTemporaryConversation) {
                [self->_conversationCache cacheConversations:@[conversation]
                                                    maxAge:3600
                                                forCommand:commandWrapper.outCommand.avim_conversationForCache];
            }
            conversation;
        });
        
        invokeAllCallback_block(conversation, nil);
    }];
    
    self->_queryConvCallbackDictionary[conversationId] = [NSMutableArray arrayWithObject:callback];
    
    [self _sendCommandWrapper:commandWrapper];
}

// MARK: - Conversation Create

- (void)createConversationWithName:(NSString *)name
                         clientIds:(NSArray<NSString *> *)clientIds
                          callback:(void (^)(AVIMConversation *conversation, NSError *error))callback
{
    [self createConversationWithName:name clientIds:clientIds attributes:nil options:(AVIMConversationOptionNone) temporaryTTL:0 callback:callback];
}

- (void)createChatRoomWithName:(NSString *)name
                    attributes:(NSDictionary *)attributes
                      callback:(void (^)(AVIMChatRoom *chatRoom, NSError *error))callback
{
    [self createConversationWithName:name clientIds:@[] attributes:attributes options:(AVIMConversationOptionTransient) temporaryTTL:0 callback:^(AVIMConversation * _Nullable conversation, NSError * _Nullable error) {
        callback((AVIMChatRoom *)conversation, error);
    }];
}

- (void)createTemporaryConversationWithClientIds:(NSArray<NSString *> *)clientIds
                                      timeToLive:(int32_t)ttl
                                        callback:(void (^)(AVIMTemporaryConversation *temporaryConversation, NSError *error))callback
{
    [self createConversationWithName:nil clientIds:clientIds attributes:nil options:(AVIMConversationOptionTemporary) temporaryTTL:ttl callback:^(AVIMConversation * _Nullable conversation, NSError * _Nullable error) {
        callback((AVIMTemporaryConversation *)conversation, error);
    }];
}

- (void)createConversationWithName:(NSString *)name
                         clientIds:(NSArray<NSString *> *)clientIds
                        attributes:(NSDictionary *)attributes
                           options:(AVIMConversationOption)options
                          callback:(void (^)(AVIMConversation *conversation, NSError *error))callback
{
    [self createConversationWithName:name clientIds:clientIds attributes:attributes options:options temporaryTTL:0 callback:callback];
}

- (void)createConversationWithName:(NSString *)name
                         clientIds:(NSArray<NSString *> *)clientIds
                        attributes:(NSDictionary *)attributes
                           options:(AVIMConversationOption)options
                      temporaryTTL:(int32_t)temporaryTTL
                          callback:(AVIMConversationResultBlock)callback
{
    for (NSString *item in clientIds) {
        if (item.length > kLC_ClientId_MaxLength || item.length == 0) {
            [self invokeInUserInteractQueue:^{
                callback(nil, LCErrorInternal([NSString stringWithFormat:@"client id's length should in range [1 %lu].", kLC_ClientId_MaxLength]));
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
        
        AssertRunInInternalSerialQueue(self);
        
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
                    dic[kLCIMConv_name] = name;
                }
                if (attributes) {
                    dic[kLCIMConv_attributes] = attributes;
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
                AVIMConversation *conversation = [self getConversationFromMemory:conversationId];
                if (conversation) {
                    if (unique) {
                        NSMutableDictionary *dic = ({
                            NSMutableDictionary *dic = [NSMutableDictionary dictionary];
                            if (name) {
                                dic[kLCIMConv_name] = name;
                            }
                            if (attributes) {
                                dic[kLCIMConv_attributes] = attributes.mutableCopy;
                            }
                            (dic.count > 0 ? dic : nil);
                        });
                        if (dic) {
                            [conversation updateRawJSONDataWith:dic];
                        }
                    }
                } else {
                    NSMutableDictionary *dic = ({
                        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
                        if (name) {
                            dic[kLCIMConv_name] = name;
                        }
                        if (attributes) {
                            dic[kLCIMConv_attributes] = attributes.mutableCopy;
                        }
                        if (convCommand.hasCdate) {
                            dic[kLCIMConv_createdAt] = convCommand.cdate;
                        }
                        if (convCommand.hasTempConvTtl) {
                            dic[kLCIMConv_temporaryTTL] = @(convCommand.tempConvTtl);
                        }
                        if (convCommand.hasUniqueId) {
                            dic[kLCIMConv_uniqueId] = convCommand.uniqueId;
                        }
                        dic[kLCIMConv_unique] = @(unique);
                        dic[kLCIMConv_transient] = @(transient);
                        dic[kLCIMConv_system] = @(false);
                        dic[kLCIMConv_temporary] = @(temporary);
                        dic[kLCIMConv_creator] = self->_clientId;
                        dic[kLCIMConv_members] = members;
                        dic[kLCIMConv_objectId] = conversationId;
                        dic;
                    });
                    conversation = [AVIMConversation conversationWithRawJSONData:dic client:self];
                    if (conversation) {
                        [self cacheConversationToMemory:conversation];
                    }
                }
                conversation;
            });
            
            [self invokeInUserInteractQueue:^{
                callback(conversation, nil);
            }];
        }];
        
        [self _sendCommandWrapper:commandWrapper];
    }];
}

// MARK: - Conversations Memory Management

- (void)cacheConversationToMemory:(AVIMConversation *)conversation
{
    AssertRunInInternalSerialQueue(self);
    NSParameterAssert(conversation);
    NSParameterAssert(conversation.conversationId);
    self->_conversationDictionary[conversation.conversationId] = conversation;
}

- (AVIMConversation *)getConversationFromMemory:(NSString *)conversationId
{
    AssertRunInInternalSerialQueue(self);
    NSParameterAssert(conversationId);
    return self->_conversationDictionary[conversationId];
}

- (AVIMConversation *)conversationForId:(NSString *)conversationId
{
    AssertNotRunInInternalSerialQueue(self);
    if (!conversationId) {
        return nil;
    }
    __block AVIMConversation *conv = nil;
    dispatch_sync(self->_internalSerialQueue, ^{
        conv = [self getConversationFromMemory:conversationId];
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
            AVIMConversation *conv = [client getConversationFromMemory:conversationId];
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
        [client->_conversationDictionary removeObjectsForKeys:conversationIds];
        [client invokeInUserInteractQueue:^{
            callback();
        }];
    }];
}

- (void)removeAllConversationsInMemoryWith:(void (^)(void))callback
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        [client->_conversationDictionary removeAllObjects];
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
    AssertNotRunInInternalSerialQueue(self);
    NSString *conversationId = keyedConversation.rawDataDic[kLCIMConv_objectId];
    if (!conversationId) {
        return nil;
    }
    __block AVIMConversation *conv = nil;
    dispatch_sync(self->_internalSerialQueue, ^{
        conv = [self getConversationFromMemory:conversationId];
        if (!conv) {
            conv = [AVIMConversation conversationWithRawJSONData:keyedConversation.rawDataDic.mutableCopy client:self];
            if (conv) {
                [self cacheConversationToMemory:conv];
            }
        }
    });
    return conv;
}

- (void)conversation:(AVIMConversation *)conversation didUpdateForKeys:(NSArray<AVIMConversationUpdatedKey> *)keys
{
    AssertRunInInternalSerialQueue(self);
    
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

- (LCIMConversationCache *)conversationCache
{
    return self->_conversationCache;
}

+ (NSMutableDictionary *)_userOptions {
    static dispatch_once_t onceToken;
    static NSMutableDictionary *userOptions;

    dispatch_once(&onceToken, ^{
        userOptions = [NSMutableDictionary dictionary];
    });

    return userOptions;
}

+ (void)_setUserOptions:(NSDictionary *)userOptions {
    if (AVIMClientHasInstantiated) {
        [NSException raise:NSInternalInconsistencyException format:@"AVIMClient user options should be set before instantiation"];
    }
    
    if (!userOptions)
        return;
    
    [self._userOptions addEntriesFromDictionary:userOptions];
}

+ (void)setUnreadNotificationEnabled:(BOOL)enabled
{
    NSDictionary *options = @{ kAVIMUserOptionUseUnread : @(enabled) };
    [self _setUserOptions:options];
}

// MARK: - Deprecated

+ (void)setUserOptions:(NSDictionary *)userOptions {
    if (AVIMClientHasInstantiated) {
        [NSException raise:NSInternalInconsistencyException format:@"AVIMClient user options should be set before instantiation"];
    }
    
    if (!userOptions)
        return;
    
    [self._userOptions addEntriesFromDictionary:userOptions];
}

@end
