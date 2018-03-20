//
//  AVIM.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMClient.h"
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

#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

#ifdef DEBUG

/*
 Use dispatch's specific to Assert ('current queue' == 'imClient')
 */
///
static void *imClientQueue_specific_key;
static void *imClientQueue_specific_value;

#define AssertRunInIMClientQueue NSAssert(dispatch_get_specific(imClientQueue_specific_key) == imClientQueue_specific_value, @"This Internal Method should Run in `imClientQueue` Thread.")

#define AssertNotRunInIMClientQueue NSAssert(dispatch_get_specific(imClientQueue_specific_key) != imClientQueue_specific_value, @"This Method should Not Run in `imClientQueue` Thread.")
///

#else

#define AssertRunInIMClientQueue

#define AssertNotRunInIMClientQueue

#endif

static const NSUInteger kMaxClientIdLength = 64;

static const NSUInteger kDistinctMessageIdArraySize = 10;

static dispatch_queue_t imClientQueue = NULL;

static BOOL AVIMClientHasInstantiated = NO;

static int64_t LCIMSessionConfigBitmap;

/*
 This Options is Just to let Server known What feature current SDK supported,
 It's Not a Switch!
 */
typedef NS_OPTIONS(NSUInteger, LCIMSessionConfigOptions) {
    
    LCIMSessionConfigOptions_Patch = 1 << 0,
    
    LCIMSessionConfigOptions_TempConv = 1 << 1,
    
    LCIMSessionConfigOptions_AutoBindInstallation = 1 << 2,
    
    LCIMSessionConfigOptions_TransientACK = 1 << 3,
    
    LCIMSessionConfigOptions_ReliableNotification = 1 << 4,
    
    LCIMSessionConfigOptions_CallbackResultSlice = 1 << 5,
};

@implementation AVIMClient {
    
    __weak id<AVIMClientDelegate> _delegate;
    
    __weak id<AVIMSignatureDataSource> _signatureDataSource;
    
    AVIMWebSocketWrapper *_socketWrapper;
    
    AVInstallation *_installation;
    
    NSString *_appId;
    
    /*
     State-Machine-Property global variable
     */
    
    ///
    
    AVIMClientStatus _status;
    
    NSString *_sessionToken;
    
    ///
    
    dispatch_queue_t _internalSerialQueue;
    
    NSMutableArray *_distinctMessageIdArray;
    
    dispatch_queue_t _queueOfConvMemory;
    
    int64_t _lastPatchTimestamp;
    
    int64_t _lastUnreadTimestamp;
    
#ifdef DEBUG
    
    void *_queueOfConvMemory_specific_key;
    
    void *_queueOfConvMemory_specific_value;
    
#endif
}

+ (void)initialize {
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        imClientQueue = dispatch_queue_create("cn.leancloud.im", DISPATCH_QUEUE_SERIAL);
        
        LCIMSessionConfigBitmap = (
                                   LCIMSessionConfigOptions_Patch |
                                   LCIMSessionConfigOptions_TempConv |
                                   LCIMSessionConfigOptions_TransientACK
                                   );
        
#ifdef DEBUG
        /*
         Add specific to 'imClientQueue'
         */
        ///
        imClientQueue_specific_key = (__bridge void *)imClientQueue;
        imClientQueue_specific_value = (__bridge void *)imClientQueue;
        dispatch_queue_set_specific(imClientQueue,
                                    imClientQueue_specific_key,
                                    imClientQueue_specific_value,
                                    NULL);
        ///
#endif
    });
}

+ (instancetype)alloc {
    AVIMClientHasInstantiated = YES;
    return [super alloc];
}

+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds {
    [AVIMWebSocketWrapper setTimeoutIntervalInSeconds:seconds];
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

// MARK: - Init Instance

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Not Allow to Initialize Instance by this Method."];
    
    return nil;
}

- (instancetype)initWithClientId:(NSString *)clientId
{
    return [self initWithClientId:clientId
                              tag:nil];
}

- (instancetype)initWithClientId:(NSString *)clientId
                             tag:(NSString *)tag
{
    self = [super init];
    
    if (self) {
        
        _user = nil;
        
        [self doInitializationWithClientId:clientId
                                       tag:tag];
    }
    
    return self;
}

- (instancetype)initWithUser:(AVUser *)user
{
    return [self initWithUser:user
                          tag:nil];
}

- (instancetype)initWithUser:(AVUser *)user
                         tag:(NSString *)tag
{
    self = [super init];

    if (self) {
        
        _user = user;

        [self doInitializationWithClientId:user.objectId
                                       tag:tag];
    }

    return self;
}

- (void)doInitializationWithClientId:(NSString *)clientId
                                 tag:(NSString *)tag
{
    void(^setupAppId_block)(void) = ^(void) {
        
        NSString *appId = [AVOSCloud getApplicationId];
        
        if (!appId) {
            
            [NSException raise:NSInternalInconsistencyException
                        format:@"Application id can not be nil."];
        }
        
        _appId = [appId copy];
    };
    
    setupAppId_block();

    void(^setupClientId_block)(void) = ^(void) {
        
        if (!clientId || clientId.length > kMaxClientIdLength) {
            
            [NSException raise:NSInvalidArgumentException
                        format:@"`clientId` is invalid or exceed Max Length('%lu').", (unsigned long)kMaxClientIdLength];
        }
        
        _clientId = [clientId copy];
    };
    
    setupClientId_block();

    void(^setupTag_block)(void) = ^(void) {
        
        if (tag) {
            
            if ([tag isEqualToString:LCIMTagDefault]) {
                
                [NSException raise:NSInvalidArgumentException
                            format:@"The tag('%@') is a Reserved Tag", LCIMTagDefault];
            }
            
            _tag = [tag copy];
            
        } else {
            
            _tag = nil;
        }
    };
    
    setupTag_block();
    
    void(^setupWebSocketWrapper_block)(void) = ^(void) {
        
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
        
        [center addObserver:self
                   selector:@selector(receiveCommand:)
                       name:AVIM_NOTIFICATION_WEBSOCKET_COMMAND
                     object:socketWrapper];
        
        _socketWrapper = socketWrapper;
    };
    
    setupWebSocketWrapper_block();
    
    void(^setupInstallation_block)(void) = ^(void) {
        
        AVInstallation *installation = [AVInstallation defaultInstallation];
        
        [installation addObserver:self
                       forKeyPath:keyPath(installation, deviceToken)
                          options:(NSKeyValueObservingOptionNew)
                          context:nil];
        
        _installation = installation;
    };
    
    setupInstallation_block();
    
    void(^setup_StateMachineProperty_Var_block)(void) = ^(void) {
        
        _status = AVIMClientStatusNone;
        
        _sessionToken = nil;
    };
    
    setup_StateMachineProperty_Var_block();
    
    _internalSerialQueue = imClientQueue;
    
    _lastPatchTimestamp = 0;
    _lastUnreadTimestamp = 0;
    
    _stagedMessages = [[NSMutableDictionary alloc] init];
    _messageQueryCacheEnabled = YES;

    _distinctMessageIdArray = [NSMutableArray arrayWithCapacity:kDistinctMessageIdArraySize + 1];
    
    _conversationDictionary = [NSMutableDictionary dictionary];
    
    _queueOfConvMemory = dispatch_queue_create("AVIMClient._queueOfConvMemory", NULL);
#ifdef DEBUG
    _queueOfConvMemory_specific_key = (__bridge void *)_queueOfConvMemory;
    _queueOfConvMemory_specific_value = (__bridge void *)_queueOfConvMemory;
    dispatch_queue_set_specific(_queueOfConvMemory,
                                _queueOfConvMemory_specific_key,
                                _queueOfConvMemory_specific_value,
                                NULL);
#endif

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        LCIMConversationCache *cache = [self conversationCache];
        [cache cleanAllExpiredConversations];
    });
}

- (void)dealloc
{
    AVLoggerInfo(AVLoggerDomainIM, @"AVIMClient dealloc.");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_socketWrapper close];
}

// MARK: - Internal Serial Queue

- (dispatch_queue_t)internalSerialQueue
{
    return _internalSerialQueue;
}

- (void)addOperationToInternalSerialQueueWithBlock:(void (^)(AVIMClient *client))block
{
    dispatch_async(_internalSerialQueue, ^{
        
        block(self);
    });
}

// MARK: - Getter and Setter of Delegate & DataSource

- (id<AVIMClientDelegate>)delegate
{
    AssertNotRunInIMClientQueue;
    
    __block id<AVIMClientDelegate> delegate = nil;
    
    dispatch_sync(_internalSerialQueue, ^{
        
        delegate = _delegate;
    });
    
    return delegate;
}

- (void)setDelegate:(id<AVIMClientDelegate>)delegate
{
    dispatch_async(_internalSerialQueue, ^{
        
        _delegate = delegate;
    });
}

- (id<AVIMSignatureDataSource>)signatureDataSource
{
    AssertNotRunInIMClientQueue;
    
    __block id<AVIMSignatureDataSource> signatureDataSource = nil;
    
    dispatch_sync(_internalSerialQueue, ^{
        
        signatureDataSource = _signatureDataSource;
    });
    
    return signatureDataSource;
}

- (void)setSignatureDataSource:(id<AVIMSignatureDataSource>)signatureDataSource
{
    dispatch_async(_internalSerialQueue, ^{
        
        _signatureDataSource = signatureDataSource;
    });
}

// MARK: - AVIMClient Status

- (AVIMClientStatus)status
{
    AssertNotRunInIMClientQueue;
    
    __block AVIMClientStatus status = AVIMClientStatusNone;
    
    dispatch_sync(_internalSerialQueue, ^{
        
        status = _status;
    });
    
    return status;
}

// MARK: - Open Client

- (void)openWithCallback:(AVIMBooleanResultBlock)callback
{
    [self openWithOption:AVIMClientOpenOptionForceOpen
                callback:callback];
}

- (void)openWithOption:(AVIMClientOpenOption)openOption
              callback:(AVIMBooleanResultBlock)callback
{
    [self getSignatureForOpenWith:^(AVIMSignature *signature) {
        
        AssertRunInIMClientQueue;
        
        if (signature && signature.error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(false, signature.error);
            });
            
            return ;
        }
        
        if (_status == AVIMClientStatusOpened) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(true, nil);
            });
            
            return;
        }
        
        _status = AVIMClientStatusOpening;
        
        _sessionToken = nil;
        
        AVIMWebSocketWrapper *socketWrapper = _socketWrapper;
        
        [socketWrapper openWithCallback:^(BOOL succeeded, NSError *error1) {
            
            dispatch_async(_internalSerialQueue, ^{
                
                if (error1) {
                    
                    _status = AVIMClientStatusClosed;
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        callback(false, error1);
                    });
                    
                    return;
                }
                
                AVIMGenericCommand *genericCommand = [self newSessionOpenCommandWithOpenOption:openOption
                                                                                  sessionToken:nil
                                                                                     signature:signature];
                
                [genericCommand setNeedResponse:true];
                
                [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error2) {
                    
                    dispatch_async(_internalSerialQueue, ^{
                        
                        if (error2) {
                            
                            _status = AVIMClientStatusClosed;
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                
                                callback(false, error2);
                            });
                            
                            return;
                        }
                        
                        _status = AVIMClientStatusOpened;
                        
                        AVIMSessionCommand *sessionCommand = inCommand.sessionMessage;
                        
                        if (sessionCommand) {
                            
                            _sessionToken = sessionCommand.st;
                            
                        } else {
                            
                            AVLoggerError(AVLoggerDomainIM, @"Not Found Session Token.");
                        }
                        
                        [self installationRegisterClientChannel];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            callback(true, nil);
                        });
                    });
                }];
                
                [socketWrapper sendCommand:genericCommand];
            });
        }];
    }];
}

- (AVIMGenericCommand *)newSessionOpenCommandWithOpenOption:(AVIMClientOpenOption)openOption
                                               sessionToken:(NSString *)sessionToken
                                                  signature:(AVIMSignature *)signature
{
    AssertRunInIMClientQueue;
    
    AVIMSessionCommand *sessionCommand = [[AVIMSessionCommand alloc] init];
    
    /* Config Bitmap */
    
    sessionCommand.configBitmap = LCIMSessionConfigBitmap;
    
    /* Last Patch Time */
    
    int64_t lastPatchTimestamp  = _lastPatchTimestamp;
    
    if (lastPatchTimestamp > 0) {
        
        sessionCommand.lastPatchTime = lastPatchTimestamp;
    }
    
    /* Last Unread Notif Time */
    
    int64_t lastUnreadTimestamp = _lastUnreadTimestamp;
    
    if (lastUnreadTimestamp > 0) {
        
        sessionCommand.lastUnreadNotifTime = lastUnreadTimestamp;
    }
    
    /* Check `sessionToken` */
    
    if (sessionToken) {
        
        /*
         If `sessionToken` is valid,
         it must a reconnect action by SDK.
         */
        
        /* Reconnect */
        
        sessionCommand.r = true;
        
        /* Session Token */
        
        sessionCommand.st = sessionToken;
        
    } else {
        
        /* Not reconnect, Open by User */
        
        if (openOption == AVIMClientOpenOptionReopen) {
            
            /*
             
             (Reopen == Reconnect), Almost, Nearly.
             
             Difference:
             
             1. `Reconnect` with a SessionToken.
             
             2. `Reopen` with or without a Signature.
             
             */
            
            sessionCommand.r = true;
        }
        
        /* Tag */
        
        NSString *tag = _tag;
        
        if (tag) {
            
            sessionCommand.tag = tag;
        }
        
        /* Signature */
        
        if (signature) {
            
            /*
             Exist Signature, so must use Signature a get a new Session Token.
             */
            
            NSAssert(nil == signature.error, @"Signature has a Error: %@", signature.error);
            
            sessionCommand.t = signature.timestamp;
            
            sessionCommand.n = signature.nonce;
            
            sessionCommand.s = signature.signature;
        }
        
        /* Device Token */
        
        NSString *deviceToken = _installation.deviceToken ?: [AVUtils deviceUUID];
        
        sessionCommand.deviceToken = deviceToken;
        
        /* User Agent */
        
        sessionCommand.ua = @"ios" @"/" SDK_VERSION;
    }
    
    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
    
    /* Message */
    
    genericCommand.sessionMessage = sessionCommand;
    
    /* Type */
    
    genericCommand.cmd = AVIMCommandType_Session;
    
    /* Operation */
    
    genericCommand.op = AVIMOpType_Open;
    
    /* App ID */
    
    genericCommand.appId = _appId;
    
    /*
     Peer ID
     
     @note Must ! With !! `PeerId` !!! Because !!! it's a Open !!! Command !!!
     */
    
    genericCommand.peerId = _clientId;
    
    NSAssert(genericCommand.peerId, @"~(T_T)||~");
    
    return genericCommand;
}

- (void)reopenWithSessionToken:(NSString *)sessionToken
{
    AssertRunInIMClientQueue;
    
    AVIMWebSocketWrapper *socketWrapper = _socketWrapper;
    
    void(^imClientResumed_block)(void) = ^(void) {
        
        AssertRunInIMClientQueue;
        
        _status = AVIMClientStatusOpened;
        
        id<AVIMClientDelegate> delegate = _delegate;
        
        if (!delegate) {
            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [delegate imClientResumed:self];
        });
    };
    
    void(^imClientClosedWithError_block)(NSError *) = ^(NSError *error) {
        
        AssertRunInIMClientQueue;
        
        _status = AVIMClientStatusClosed;
        
        id<AVIMClientDelegate> delegate = _delegate;
        
        if (!delegate) {
            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [delegate imClientClosed:self error:error];
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            if ([delegate respondsToSelector:@selector(imClientPaused:error:)]) {
                
                [delegate imClientPaused:self error:error];
            }
#pragma clang diagnostic pop
        });
    };
    
    void(^handleSessionTokenExpired_block)(void) = ^(void) {
        
        AssertRunInIMClientQueue;
        
        _sessionToken = nil;
        
        [self _getSignatureForOpenWith:^(AVIMSignature *signature) {
            
            AssertRunInIMClientQueue;
            
            if (signature && signature.error) {
                
                imClientClosedWithError_block(signature.error);
                
                return ;
            }
            
            AVIMGenericCommand *cmd = [self newSessionOpenCommandWithOpenOption:AVIMClientOpenOptionReopen
                                                                   sessionToken:nil
                                                                      signature:signature];
            
            [cmd setNeedResponse:true];
            
            [cmd setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
                
                dispatch_async(_internalSerialQueue, ^{
                    
                    if (error) {
                        
                        imClientClosedWithError_block(error);
                        
                        return ;
                    }
                    
                    AVIMSessionCommand *sessionCommand = inCommand.sessionMessage;
                    
                    if (sessionCommand) {
                        
                        _sessionToken = sessionCommand.st;
                        
                    } else {
                        
                        AVLoggerError(AVLoggerDomainIM, @"Not Found Session Token.");
                    }
                    
                    imClientResumed_block();
                });
            }];
            
            [socketWrapper sendCommand:cmd];
        }];
    };
    
    AVIMGenericCommand *cmd = [self newSessionOpenCommandWithOpenOption:0
                                                           sessionToken:sessionToken
                                                              signature:nil];
    
    [cmd setNeedResponse:true];
    
    [cmd setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
        
        dispatch_async(_internalSerialQueue, ^{
            
            if (error) {
                
                AVIMErrorCommand *errorCommand = inCommand.errorMessage;
                
                if (errorCommand &&
                    (LCIMErrorCodeSessionTokenExpired == errorCommand.code)) {
                    
                    handleSessionTokenExpired_block();
                    
                    return ;
                }
                
                imClientClosedWithError_block(error);
                
                return ;
            }
            
            imClientResumed_block();
        });
    }];
    
    [socketWrapper sendCommand:cmd];
}

// MARK: - Close Client

- (void)closeWithCallback:(AVIMBooleanResultBlock)callback
{
    dispatch_async(_internalSerialQueue, ^{
        
        if (_status == AVIMClientStatusClosed) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(true, nil);
            });
            
            return;
        }
        
        _status = AVIMClientStatusClosing;
        
        AVIMWebSocketWrapper *socketWrapper = _socketWrapper;
        
        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
        
        genericCommand.cmd = AVIMCommandType_Session;
        genericCommand.op = AVIMOpType_Close;
        genericCommand.sessionMessage = [[AVIMSessionCommand alloc] init];
        
        [genericCommand setNeedResponse:true];
        [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
            
            dispatch_async(_internalSerialQueue, ^{
                
                if (error) {
                    
                    _status = AVIMClientStatusNone;
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        callback(false, error);
                    });
                    
                    return ;
                }
                
                _status = AVIMClientStatusClosed;
                
                _sessionToken = nil;
                
                [self installationRemoveClientChannel];
                
                [socketWrapper close];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    callback(true, nil);
                });
            });
        }];
        
        [socketWrapper sendCommand:genericCommand];
    });
}

- (void)processCommand_SessionClosed:(AVIMGenericCommand *)genericCommand
{
    AssertRunInIMClientQueue;
    
    _status = AVIMClientStatusClosed;
    
    _sessionToken = nil;
    
    [self installationRemoveClientChannel];
    
    id<AVIMClientDelegate> delegate = _delegate;
    
    if (delegate) {
        
        SEL aSel = @selector(client:didOfflineWithError:);
        
        if ([delegate respondsToSelector:aSel]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                NSError *error = [genericCommand avim_errorObject];
                
                [delegate client:self didOfflineWithError:error];
            });
        }
    }
}

// MARK: - APNs

- (void)installationRegisterClientChannel
{
    AssertRunInIMClientQueue;
    
    AVInstallation *installation = _installation;
    
    NSString *clientId = _clientId;
    
    NSString *deviceToken = installation.deviceToken;
    
    if (!deviceToken) {
        
        return;
    }
    
    [installation addUniqueObject:clientId
                           forKey:@"channels"];
    
    [installation saveInBackgroundWithBlock:^(BOOL succeeded, NSError * _Nullable error) {
        
        if (error) {
            
            AVLoggerError(AVLoggerDomainIM, @"%@", error);
        }
    }];
    
    AVIMReportCommand *reportCommand = [[AVIMReportCommand alloc] init];
    
    reportCommand.initiative = YES;
    reportCommand.type = @"token";
    reportCommand.data_p = deviceToken;
    
    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
    
    genericCommand.cmd = AVIMCommandType_Report;
    genericCommand.op = AVIMOpType_Upload;
    genericCommand.reportMessage = reportCommand;
    
    [self _sendCommand:genericCommand];
}

- (void)installationRemoveClientChannel
{
    AssertRunInIMClientQueue;
    
    AVInstallation *installation = _installation;
    
    if (installation.deviceToken) {
        
        [installation removeObject:_clientId
                            forKey:@"channels"];
        
        [installation saveInBackgroundWithBlock:^(BOOL succeeded, NSError * _Nullable error) {
            
            if (error) {
                
                AVLoggerError(AVLoggerDomainIM, @"%@", error);
            }
        }];
    }
}

// MARK: - WebSocket Notification

- (void)websocketOpened:(NSNotification *)notification
{
    dispatch_async(_internalSerialQueue, ^{
        
        NSString *sessionToken = _sessionToken;
        
        if (!sessionToken) {
            
            return;
        }
        
        if (_status != AVIMClientStatusResuming) {
            
            return;
        }
        
        [self reopenWithSessionToken:sessionToken];
    });
}

- (void)websocketClosed:(NSNotification *)notification
{
    dispatch_async(_internalSerialQueue, ^{
        
        if (!_sessionToken) {
            
            return ;
        }
        
        void(^imClientPaused_block)(void) = ^(void) {
            
            _status = AVIMClientStatusPaused;
            
            id<AVIMClientDelegate> delegate = _delegate;
            
            if (!delegate) {
                
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [delegate imClientPaused:self];
            });
        };
        
        void(^imClientClosedWithError_block)(NSError *) = ^(NSError *error) {
            
            _status = AVIMClientStatusClosed;
            
            id<AVIMClientDelegate> delegate = _delegate;
            
            if (!delegate) {
                
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [delegate imClientClosed:self error:error];
                
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([delegate respondsToSelector:@selector(imClientPaused:error:)]) {
                    
                    [delegate imClientPaused:self error:error];
                }
#pragma clang diagnostic pop
            });
        };
        
        NSDictionary *info = notification.userInfo;
        
        NSAssert(info, @"This Notification's `userInfo` can't be nil.");
        
        BOOL willReconnect = [info[@"willReconnect"] boolValue];
        
        NSError *error = info[@"error"];
        
        if (willReconnect) {
            
            imClientPaused_block();
            
        } else {
            
            imClientClosedWithError_block(error);
        }
    });
}

- (void)websocketReconnect:(NSNotification *)notification
{
    dispatch_async(_internalSerialQueue, ^{
        
        if (!_sessionToken) {
            
            return;
        }
        
        if (_status != AVIMClientStatusPaused) {
            
            return;
        }
        
        _status = AVIMClientStatusResuming;
        
        id<AVIMClientDelegate> delegate = _delegate;
        
        if (!delegate) {
            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [delegate imClientResuming:self];
        });
    });
}

- (void)receiveCommand:(NSNotification *)notification
{
    dispatch_async(_internalSerialQueue, ^{
        
        NSDictionary *userInfo = notification.userInfo;
        
        if (!userInfo) {
            
            return;
        }
        
        AVIMGenericCommand *command = [userInfo objectForKey:@"command"];
        
        if (!command) {
            
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
    });
}

// MARK: - Signature

- (AVIMSignature *)getSignatureByDataSourceWithAction:(NSString *)action
                                       conversationId:(NSString *)conversationId
                                            clientIds:(NSArray<NSString *> *)clientIds
{
    AssertRunInIMClientQueue;
    
    NSString *clientId = _clientId;
    
    __block AVIMSignature *signature = nil;
    
    id<AVIMSignatureDataSource> signatureDataSource = _signatureDataSource;
    
    if (signatureDataSource) {
        
        SEL aSel = @selector(signatureWithClientId:conversationId:action:actionOnClientIds:);
        
        if ([signatureDataSource respondsToSelector:aSel]) {
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                signature = [signatureDataSource signatureWithClientId:clientId
                                                        conversationId:conversationId
                                                                action:action
                                                     actionOnClientIds:clientIds];
            });
        }
    }
    
    return signature;
}

- (void)getSignatureForOpenWith:(void(^)(AVIMSignature *))callback
{
    dispatch_async(_internalSerialQueue, ^{
        
        [self _getSignatureForOpenWith:callback];
    });
}

- (void)_getSignatureForOpenWith:(void(^)(AVIMSignature *))callback
{
    AssertRunInIMClientQueue;
    
    AVUser *user = _user;
    
    AVIMSignature *signature = nil;
    
    if (user) {
        
        signature = [[AVIMSignature alloc] init];
        
        NSString *userSessionToken = user.sessionToken;
        
        if (!userSessionToken) {
            
            NSString *reason = @"The Session Token of `user`('AVUser') is invalid.";
            
            NSDictionary *info = @{ @"reason" : reason };
            
            NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                  code:0
                                              userInfo:info];
            
            signature.error = aError;
            
            callback(signature);
            
            return;
        }
        
        AVPaasClient *client = [AVPaasClient sharedInstance];
        
        NSDictionary *parameters = @{ @"session_token" : userSessionToken };
        
        NSURLRequest *request = [client requestWithPath:@"rtm/sign"
                                                 method:@"POST"
                                                headers:nil
                                             parameters:parameters];
        
        [client performRequest:request success:^(NSHTTPURLResponse *response, id result) {
            
            if (!result) {
                
                NSString *reason = @"No Result for Open Signature.";
                
                NSDictionary *info = @{ @"reason" : reason };
                
                NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                      code:0
                                                  userInfo:info];
                
                signature.error = aError;
                
                dispatch_async(_internalSerialQueue, ^{
                    
                    callback(signature);
                });
                
                return;
            }
            
            signature.nonce = result[@"nonce"];
            signature.signature = result[@"signature"];
            signature.timestamp = [result[@"timestamp"] unsignedIntegerValue];
            
            dispatch_async(_internalSerialQueue, ^{
                
                callback(signature);
            });
            
        } failure:^(NSHTTPURLResponse *response, id result, NSError *error) {
            
            if (error) {
                
                signature.error = error;
                
            } else {
                
                NSString *reason = @"Unknown Error for Open Signature.";
                
                NSDictionary *info = @{ @"reason" : reason };
                
                NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                      code:0
                                                  userInfo:info];
                
                signature.error = aError;
            }
            
            dispatch_async(_internalSerialQueue, ^{
                
                callback(signature);
            });
        }];
        
    } else {
        
        signature = [self getSignatureByDataSourceWithAction:@"open"
                                              conversationId:nil
                                                   clientIds:nil];
        
        callback(signature);
    }
}

// MARK: - Send Command

- (void)sendCommand:(AVIMGenericCommand *)command
{
    dispatch_async(_internalSerialQueue, ^{
        
        [self _sendCommand:command];
    });
}

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueueWithBlock:^(AVIMClient *client) {
        
        if (_status != AVIMClientStatusOpened) {
            
            if ([commandWrapper hasCallback]) {
                
                NSError *aError = ({
                    NSString *reason = @"Client Not Open when Send a Command.";
                    NSDictionary *userInfo = @{ @"reason" : reason };
                    [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                        code:0
                                    userInfo:userInfo];
                });
                
                commandWrapper.error = aError;
                
                [commandWrapper executeCallbackAndSetItToNil];
            }
            
            return;
        }
        
        [client->_socketWrapper sendCommandWrapper:commandWrapper];
    }];
}

- (void)_sendCommand:(AVIMGenericCommand *)command
{
    AssertRunInIMClientQueue;
    
    if (_status != AVIMClientStatusOpened) {
        
        AVIMCommandResultBlock callback = command.callback;
        
        if (callback) {
            
            NSError *error = [AVIMErrorUtil errorWithCode:kAVIMErrorClientNotOpen
                                                   reason:@"Client Not Open when Send a Command."];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(command, nil, error);
            });
        }
        
        return;
    }
    
    [_socketWrapper sendCommand:command];
}

// MARK: - Command Receiving

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socket commandDidGetCallback:(LCIMProtobufCommandWrapper *)command
{
    [self addOperationToInternalSerialQueueWithBlock:^(AVIMClient *client) {
        
        if ([command hasCallback]) {
            
            [command executeCallbackAndSetItToNil];
            
        } else if (command.error) {
            
            // TODO: add a protocol or global notification to throw error to user.
        }
    }];
}

// MARK: -

- (LCIMConversationCache *)conversationCache {
    if (_conversationCache)
        return _conversationCache;

    @synchronized (self) {
        if (_conversationCache)
            return _conversationCache;

        _conversationCache = [[LCIMConversationCache alloc] initWithClientId:_clientId];
        _conversationCache.client = self;

        return _conversationCache;
    }
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

- (void)updateLastPatchTimestamp:(int64_t)patchTimestamp {
    // TODO: Rework set `_lastPatchTimestamp`
    @synchronized (self) {
        if (patchTimestamp > _lastPatchTimestamp)
            _lastPatchTimestamp = patchTimestamp;
    }
}

- (void)updateLastUnreadTimestamp:(int64_t)unreadTimestamp {
    // TODO: Rework set `_lastUnreadTimestamp`
    @synchronized (self) {
        if (unreadTimestamp > _lastUnreadTimestamp)
            _lastUnreadTimestamp = unreadTimestamp;
    }
}

- (void)createConversationWithName:(NSString *)name
                         clientIds:(NSArray *)clientIds
                          callback:(AVIMConversationResultBlock)callback
{
    [self createConversationWithName:name
                           clientIds:clientIds
                          attributes:nil
                             options:AVIMConversationOptionNone
                        temporaryTTL:0
                            callback:callback];
}

- (void)createChatRoomWithName:(NSString *)name
                    attributes:(NSDictionary *)attributes
                      callback:(AVIMChatRoomResultBlock)callback
{
    [self createConversationWithName:name
                           clientIds:@[]
                          attributes:attributes
                             options:AVIMConversationOptionTransient
                        temporaryTTL:0
                            callback:
     ^(AVIMConversation *conv, NSError * error){
         
         if (conv) {
             
             AVIMChatRoom *chatRoom = (AVIMChatRoom *)conv;
             
             callback(chatRoom, nil);
             
         } else {
             
             callback(nil, error);
         }
     }];
}

- (void)createTemporaryConversationWithClientIds:(NSArray *)clientIds
                                      timeToLive:(int32_t)ttl
                                        callback:(AVIMTemporaryConversationResultBlock)callback
{
    [self createConversationWithName:nil
                           clientIds:clientIds
                          attributes:nil
                             options:AVIMConversationOptionTemporary
                        temporaryTTL:ttl
                            callback:
     ^(AVIMConversation *conv, NSError * error){
         
         if (conv) {
             
             AVIMTemporaryConversation *temporaryConversation = (AVIMTemporaryConversation *)conv;
             
             callback(temporaryConversation, nil);
             
         } else {
             
             callback(nil, error);
         }
     }];
}

- (void)createConversationWithName:(NSString *)name
                         clientIds:(NSArray *)clientIds
                        attributes:(NSDictionary *)attr
                           options:(AVIMConversationOption)options
                          callback:(AVIMConversationResultBlock)callback
{
    [self createConversationWithName:name
                           clientIds:clientIds
                          attributes:attr
                             options:options
                        temporaryTTL:0
                            callback:callback];
}

- (void)createConversationWithName:(NSString *)name
                         clientIds:(NSArray *)clientIds
                        attributes:(NSDictionary *)attr
                           options:(AVIMConversationOption)options
                      temporaryTTL:(int32_t)temporaryTTL
                          callback:(AVIMConversationResultBlock)callback
{
    [[self class] _assertClientIdsIsValid:clientIds];
    
    BOOL unique    = options & AVIMConversationOptionUnique;
    BOOL transient = options & AVIMConversationOptionTransient;
    BOOL temporary = options & AVIMConversationOptionTemporary;
    
    if ((unique && transient) ||
        (unique && temporary) ||
        (transient && temporary)) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSString *reason = @"`options` is invalid.";
            
            NSDictionary *info = @{ @"reason" : reason };
            
            NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                  code:0
                                              userInfo:info];
            
            callback(nil, aError);
        });
        
        return;
    }
    
    NSMutableDictionary *attributes = nil;
    
    if (name || attr) {
        
        attributes = [NSMutableDictionary dictionary];
        
        if (name) {
            
            [attributes setObject:name forKey:kConvAttrKey_name];
        }
        
        if (attr) {
            
            [attributes setObject:attr forKey:kConvAttrKey_attributes];
        }
    }
    
    NSMutableArray *memberArray = [NSMutableArray arrayWithArray:({
        
        NSMutableSet *members = [NSMutableSet setWithArray:clientIds ?: @[]];
        
        [members addObject:_clientId];
        
        [members allObjects];
    })];
    
    dispatch_async(_internalSerialQueue, ^{
        
        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
        
        genericCommand.needResponse = YES;
        
        genericCommand.cmd = AVIMCommandType_Conv;
        genericCommand.op = AVIMOpType_Start;

        AVIMConvCommand *convCommand = [[AVIMConvCommand alloc] init];

        if (attributes) {
            
            convCommand.attr = [AVIMCommandFormatter JSONObjectWithDictionary:attributes];
        }

        if (transient) {
            
            convCommand.transient = true;
            
        } else if (temporary) {
            
            convCommand.tempConv = true;
            
            if (temporaryTTL > 0) {
                
                convCommand.tempConvTtl = temporaryTTL;
            }
            
            convCommand.mArray = memberArray;
            
        } else {
            
            if (unique) {
                
                convCommand.unique = true;
            }
            
            convCommand.mArray = memberArray;
        }

        [genericCommand avim_addRequiredKeyWithCommand:convCommand];
        
        NSString *acition = [AVIMCommandFormatter signatureActionForKey:genericCommand.op];
        
        AVIMSignature *signature = [self getSignatureByDataSourceWithAction:acition
                                                             conversationId:nil
                                                                  clientIds:memberArray.copy];
        
        [genericCommand avim_addRequiredKeyForConvMessageWithSignature:signature];
        
        if ([AVIMClient checkErrorForSignature:signature command:genericCommand]) {
            return;
        }
        
        [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
            if (!error) {
                AVIMConvCommand *inConvCommand = inCommand.convMessage;
                AVIMConvCommand *outConvCommand = outCommand.convMessage;
                
                NSString *convId = inConvCommand.cid;
                
                LCIMConvType convType = LCIMConvTypeUnknown;
                
                if (transient) {
                    
                    convType = LCIMConvTypeTransient;
                    
                } else if (temporary) {
                    
                    convType = LCIMConvTypeTemporary;
                    
                } else {
                    
                    convType = LCIMConvTypeNormal;
                }
                
                AVIMConversation *conversation = [self getConversationWithId:convId
                                                               orNewWithType:convType];
                
                if (!conversation) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        NSString *reason = [NSString stringWithFormat:@"Create Conversation failed, conversation's ID: (%@)", convId ?: @"nil"];
                        
                        NSDictionary *info = @{ @"reason" : reason };
                        
                        NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                              code:0
                                                          userInfo:info];
                        
                        callback(nil, aError);
                    });
                    
                    return;
                }
                
                conversation.name = name;
                conversation.attributes = attr;
                
                conversation.creator = _clientId;
                
                conversation.createAt = [AVObjectUtils dateFromString:[inConvCommand cdate]];
                
                [conversation addMembers:[outConvCommand.mArray copy]];
                
                if (temporary) {
                    
                    conversation.temporaryTTL = inConvCommand.tempConvTtl;
                }
                
                if (outConvCommand.unique) {
                    
                    conversation.unique = true;
                    
                    if (inConvCommand.hasUniqueId) {
                        
                        conversation.uniqueId = inConvCommand.uniqueId;
                    }
                }

                [AVIMBlockHelper callConversationResultBlock:callback
                                                conversation:conversation
                                                       error:nil];
                
            } else {
                
                [AVIMBlockHelper callConversationResultBlock:callback
                                                conversation:nil
                                                       error:error];
            }
        }];

        [self _sendCommand:genericCommand];
    });
}

- (AVIMConversation *)conversationWithKeyedConversation:(AVIMKeyedConversation *)keyedConversation
{
    NSString *conversationId = keyedConversation.conversationId;
    NSDictionary *rawDataDic = keyedConversation.rawDataDic;
    
    if (!rawDataDic) {
        
        return nil;
    }
    
    BOOL transient = [rawDataDic[kConvAttrKey_transient] boolValue];
    BOOL system = [rawDataDic[kConvAttrKey_system] boolValue];
    BOOL temporary = [rawDataDic[kConvAttrKey_temporary] boolValue];
    
    LCIMConvType convType = LCIMConvTypeUnknown;
    
    if (!transient && !system && !temporary) {
        
        convType = LCIMConvTypeNormal;
        
    } else if (transient && !system && !temporary) {
        
        convType = LCIMConvTypeTransient;
        
    } else if (!transient && system && !temporary) {
        
        convType = LCIMConvTypeSystem;
        
    } else if (!transient && !system && temporary) {
        
        convType = LCIMConvTypeTemporary;
    }
    
    AVIMConversation *conversation = [self getConversationWithId:conversationId
                                                   orNewWithType:convType];
    
    if (conversation) {
        
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
    dispatch_async(_internalSerialQueue, ^{
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
        
        NSMutableArray<NSString *> *sessionPeerIdsArray = [NSMutableArray new];
        if (clients) {
            [sessionPeerIdsArray addObjectsFromArray:clients];
        }
        sessionCommand.sessionPeerIdsArray = sessionPeerIdsArray;

        [genericCommand avim_addRequiredKeyWithCommand:sessionCommand];

        [self _sendCommand:genericCommand];
    });
}

#pragma mark - process received messages

- (BOOL)insertDistinctMessageId:(NSString *)messageId {
    if ([_distinctMessageIdArray containsObject:messageId])
        return NO;

    [_distinctMessageIdArray addObject:messageId];

    NSUInteger count = _distinctMessageIdArray.count;

    if (count > kDistinctMessageIdArraySize)
        [_distinctMessageIdArray removeObjectsInRange:NSMakeRange(0, count - kDistinctMessageIdArraySize)];

    return YES;
}

- (void)processDirectCommand:(AVIMGenericCommand *)genericCommand
{
    AssertRunInIMClientQueue;
    
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
    message.localClientId = _clientId;
    message.transient = directCommand.transient;
    message.mentionAll = directCommand.mentionAll;
    message.mentionList = [directCommand.mentionPidsArray copy];

    if (directCommand.hasPatchTimestamp)
        message.updatedAt = [NSDate dateWithTimeIntervalSince1970:(directCommand.patchTimestamp / 1000.0)];
    
    [self receiveMessage:message
                convType:directCommand.convType];
    
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
        [self _sendCommand:genericAckCommand];
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
    message.localClientId = _clientId;

    if (unreadTuple.hasPatchTimestamp)
        message.updatedAt = [NSDate dateWithTimeIntervalSince1970:unreadTuple.patchTimestamp / 1000.0];

    return message;
}

- (void)processUnreadCommand:(AVIMGenericCommand *)genericCommand
{
    AssertRunInIMClientQueue;
    
    AVIMUnreadCommand *unreadCommand = genericCommand.unreadMessage;

    [self updateLastUnreadTimestamp:unreadCommand.notifTime];

    for (AVIMUnreadTuple *unreadTuple in unreadCommand.convsArray)
        [self processUnreadTuple:unreadTuple];
}

- (void)processUnreadTuple:(AVIMUnreadTuple *)unreadTuple
{
    NSString *conversationId = unreadTuple.cid;
    
    LCIMConvType convType = unreadTuple.convType;
    
    void(^messageNotification_block)(AVIMConversation *) = ^(AVIMConversation *conversation) {
        
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        
        dictionary[@"unreadMessagesCount"] = @(unreadTuple.unread);
        dictionary[@"lastMessage"] = [self messageWithUnreadTuple:unreadTuple];
        
        if (unreadTuple.hasMentioned) {
            
            dictionary[@"unreadMessagesMentioned"] = @(unreadTuple.mentioned);
        }
        
        [self updateConversation:conversationId withDictionary:dictionary];
        
        /* For compatibility, we reserve this callback. It should be removed in future. */
        id<AVIMClientDelegate> delegate = _delegate;
        SEL selector = @selector(conversation:didReceiveUnread:);
        if (delegate && [delegate respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [delegate conversation:conversation
                      didReceiveUnread:unreadTuple.unread];
            });
#pragma clang diagnostic pop
        }
    };
    
    AVIMConversation *conversation = [self getConversationWithId:conversationId
                                                   orNewWithType:convType];
    
    if (conversation && conversation.createAt) {
        
        messageNotification_block(conversation);
        
    } else {
        
        AVIMConversationQuery *query = [self conversationQuery];
        
        query.cachePolicy = kAVCachePolicyNetworkOnly;
        
        __weak typeof(self) weakSelf = self;
        
        [query getConversationById:conversationId
                          callback:
         ^(AVIMConversation *conversation, NSError *error){
             
             AVIMClient *client = weakSelf;
             
             if (!client) {
                 
                 return;
             }
             
             dispatch_async(_internalSerialQueue, ^{
                 
                 if (error) {
                     
                     AVLoggerError(AVLoggerDomainIM, @"Fetch Conversation Failed, with Error: %@", error);
                     
                     return;
                 }
                 
                 messageNotification_block(conversation);
             });
         }];
    }
}

- (void)updateConversation:(NSString *)conversationId withDictionary:(NSDictionary *)dictionary {
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        LCIM_NOTIFY_PROPERTY_UPDATE(_clientId, conversationId, key, value);
    }];
}

- (void)resetUnreadMessagesCountForConversation:(AVIMConversation *)conversation {
    [self updateConversation:conversation.conversationId withDictionary:@{@"unreadMessagesCount": @(0)}];
}

- (void)removeCachedMessagesForId:(NSString *)conversationId {
    NSString *clientId = _clientId;

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
            
            if (convCommand.tempConv && convCommand.tempConvTtl > 0) {
                
                conversation.temporaryTTL = convCommand.tempConvTtl;
            }
            
            [conversation addMember:_clientId];
            [self receiveInvitedFromConversation:conversation byClientId:initBy];
            break;
            
            // AVIMOpType_MembersJoined = 33,
        case AVIMOpType_MembersJoined:
            
            if (convCommand.tempConv && convCommand.tempConvTtl > 0) {
                
                conversation.temporaryTTL = convCommand.tempConvTtl;
            }
            
            [conversation addMembers:members];
            [self receiveMembersAddedFromConversation:conversation clientIds:members byClientId:initBy];
            break;
            
            // AVIMOpType_Left = 39,
        case AVIMOpType_Left:
            [conversation removeMember:_clientId];
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

- (void)processConvCommand:(AVIMGenericCommand *)command
{
    AssertRunInIMClientQueue;
    
    AVIMConvCommand *convCommand = command.convMessage;
    
    if (!convCommand) {
        
        return;
    }
    
    NSString *conversationId = convCommand.cid;
    
    if (!conversationId) {
        
        return;
    }
    
    LCIMConvType convType = LCIMConvTypeUnknown;
    
    if (convCommand.tempConv) {
        
        convType = LCIMConvTypeTemporary;
        
    } else {
        
        convType = LCIMConvTypeNormal;
    }
    
    AVIMConversation *conversation = [self getConversationWithId:conversationId
                                                   orNewWithType:convType];
    
    if (conversation && conversation.createAt) {
        
        [self passConvCommand:command toConversation:conversation];
        
    } else {
        
        AVIMConversationQuery *query = [self conversationQuery];
        
        query.cachePolicy = kAVCachePolicyNetworkOnly;
        
        __weak typeof(self) weakSelf = self;
        
        [query getConversationById:conversationId
                          callback:
         ^(AVIMConversation *conversation, NSError *error){
             
             AVIMClient *client = weakSelf;
             
             if (!client) {
                 
                 return;
             }
             
             dispatch_async(_internalSerialQueue, ^{
                 
                 if (error) {
                     
                     AVLoggerError(AVLoggerDomainIM, @"Fetch Conversation Failed, with Error: %@", error);
                     
                     return;
                 }
                 
                 [client passConvCommand:command toConversation:conversation];
             });
         }];
    }
}

- (LCIMMessageCacheStore *)messageCacheStoreForConversationId:(NSString *)conversationId {
    if (!conversationId)
        return nil;

    LCIMMessageCacheStore *cacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:_clientId conversationId:conversationId];
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

- (void)processReceiptCommand:(AVIMGenericCommand *)genericCommand
{
    AssertRunInIMClientQueue;
    
    AVIMRcpCommand *rcpCommand = genericCommand.rcpMessage;

    int64_t timestamp = rcpCommand.t;
    NSString *messageId = rcpCommand.id_p;
    NSString *conversationId = rcpCommand.cid;
    
    if (!conversationId) {
        
        return;
    }

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp / 1000.0];
    AVIMMessage *message = [self localMessageForId:messageId conversationId:conversationId];
    
    void(^updateReceipt_block)(AVIMConversation *) = ^(AVIMConversation *conversation) {
        
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
                [self receiveMessageDelivered:message conversation:conversation];
            }
            
            receiptKey = NSStringFromSelector(@selector(lastDeliveredAt));
        }
        
        [self updateReceipt:date
             ofConversation:conversation
                     forKey:receiptKey];
    };
    
    NSArray<AVIMConversation *> *result = [self getConversationsFromMemoryWith:@[conversationId]];
    
    AVIMConversation *conversation = result.firstObject;
    
    if (conversation && conversation.createAt) {
        
        updateReceipt_block(conversation);
        
    } else {
        
        AVIMConversationQuery *query = [self conversationQuery];
        
        query.cachePolicy = kAVCachePolicyNetworkOnly;
        
        __weak typeof(self) weakSelf = self;
        
        [query getConversationById:conversationId
                          callback:
         ^(AVIMConversation *conversation, NSError *error){
             
             AVIMClient *client = weakSelf;
             
             if (!client) {
                 
                 return;
             }
             
             dispatch_async(_internalSerialQueue, ^{
                 
                 if (error) {
                     
                     AVLoggerError(AVLoggerDomainIM, @"Fetch Conversation Failed, with Error: %@", error);
                     
                     return;
                 }
                 
                 updateReceipt_block(conversation);
             });
         }];
    }
}

- (void)updateReceipt:(NSDate *)date
       ofConversation:(AVIMConversation *)conversation
               forKey:(NSString *)key
{
    if (!date || !conversation || !key)
        return;

    NSDate *oldDate = [conversation valueForKey:key];

    if (!oldDate || [oldDate compare:date] == NSOrderedAscending) {
        LCIM_NOTIFY_PROPERTY_UPDATE(_clientId, conversation.conversationId, key, date);
    }
}

- (void)processSessionCommand:(AVIMGenericCommand *)genericCommand
{
    AssertRunInIMClientQueue;
    
    AVIMOpType op = genericCommand.op;
    
    if (op == AVIMOpType_Closed) {
        
        [self processCommand_SessionClosed:genericCommand];
    }
}

- (void)processPatchCommand:(AVIMGenericCommand *)command
{
    AssertRunInIMClientQueue;
    
    AVIMOpType op = command.op;

    if (op == AVIMOpType_Modify) {
        [self processMessagePatchCommand:command.patchMessage];
        [self sendACKForPatchCommand:command];
    }
}

- (void)processMessagePatchCommand:(AVIMPatchCommand *)command
{
    AssertRunInIMClientQueue;
    
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
    
    NSString *conversationId = patchItem.cid;
    NSString *messageId = patchItem.mid;
    
    if (conversationId && messageId) {
        
        AVIMConversation *conv = [self conversationForId:conversationId];
        
        AVIMMessage *message = [[self messageCacheStoreForConversationId:conversationId] messageForId:messageId];
        
        id <AVIMClientDelegate> delegate = _delegate;
        
        if (conv && message && delegate && [delegate respondsToSelector:@selector(conversation:messageHasBeenUpdated:)]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [delegate conversation:conv messageHasBeenUpdated:message];
            });
        }
    }
}

- (void)sendACKForPatchCommand:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    int64_t lastPatchTimestamp = _lastPatchTimestamp;

    if (!lastPatchTimestamp)
        return;

    AVIMGenericCommand *command = [[AVIMGenericCommand alloc] init];

    command.peerId = _clientId;

    command.cmd = AVIMCommandType_Patch;
    command.op  = AVIMOpType_Modified;

    AVIMPatchCommand *patchMessage = [[AVIMPatchCommand alloc] init];
    patchMessage.lastPatchTime = lastPatchTimestamp;

    command.patchMessage = patchMessage;

    [self _sendCommand:command];
}

- (void)array:(NSMutableArray *)array addObject:(id)object {
    if (!object) {
        object = [NSNull null];
    }
    [array addObject:object];
}

- (void)receiveMessage:(AVIMMessage *)message
              convType:(LCIMConvType)convtype
{
    NSString *conversationId = message.conversationId;
    
    if (!conversationId) {
        
        return;
    }
    
    /* Only cache non-transient message */
    if (!message.transient && self.messageQueryCacheEnabled) {
        LCIMMessageCacheStore *cacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:_clientId conversationId:conversationId];
        
        /* If cache contains message, update message only */
        if ([cacheStore containMessage:message]) {
            [cacheStore updateMessageWithoutBreakpoint:message];
            return;
        }
        
        /* Otherwise, add message to cache and notify it to user */
        [cacheStore insertOrUpdateMessage:message withBreakpoint:YES];
    }
    
    AVIMConversation *conversation = [self getConversationWithId:conversationId
                                                   orNewWithType:convtype];
    
    if (conversation && conversation.createAt) {
        
        [self passMessage:message toConversation:conversation];
        [self postNotificationForMessage:message];
        
    } else {
        
        AVIMConversationQuery *query = [self conversationQuery];
        
        query.cachePolicy = kAVCachePolicyNetworkOnly;
        
        __weak typeof(self) weakSelf = self;
        
        [query getConversationById:conversationId
                          callback:
         ^(AVIMConversation *conversation, NSError *error){
             
             AVIMClient *client = weakSelf;
             
             if (!client) {
                 
                 return;
             }
             
             dispatch_async(_internalSerialQueue, ^{
                 
                 if (error) {
                     
                     AVLoggerError(AVLoggerDomainIM, @"Fetch Conversation Failed, with Error: %@", error);
                     
                     return;
                 }
                 
                 [client passMessage:message toConversation:conversation];
                 [client postNotificationForMessage:message];
             });
         }];
    }
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

- (void)receiveMessageDelivered:(AVIMMessage *)message
                   conversation:(AVIMConversation *)conversation
{
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

- (void)receiveResumed {
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
    [self array:arguments addObject:self];
    [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(imClientResumed:) arguments:arguments];
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

// MARK: - Conversation Construction & Memory Cache

- (AVIMConversation *)getConversationWithId:(NSString *)convId
                              orNewWithType:(LCIMConvType)convType
{
    __block AVIMConversation *conv = nil;
    
    dispatch_sync(_queueOfConvMemory, ^{
        
        conv = [self _getConversationWithId:convId
                              orNewWithType:convType];
    });
    
    return conv;
}

- (AVIMConversation *)_getConversationWithId:(NSString *)convId
                               orNewWithType:(LCIMConvType)convType
__attribute__((warn_unused_result))
{
    NSAssert(dispatch_get_specific(_queueOfConvMemory_specific_key) == _queueOfConvMemory_specific_value,
             @"This internal method should run in `_queueOfConvMemory`.");
    
    if (!convId) {
        
        return nil;
    }
    
    AVIMConversation *conv = [self _getConversationsFromMemoryWith:@[convId]].firstObject;
    
    if (conv) {
        
        /*
         Get Conversation from Memory
         */
        
        return conv;
    }
    
    conv = [AVIMConversation newWithConversationId:convId
                                          convType:convType
                                            client:self];
    
    if (conv) {
        
        /*
         New Conversation and Retain in Memory by Client
         */
        
        [_conversationDictionary setObject:conv
                                    forKey:convId];
        
        return conv;
    }
    
    return nil;
}

- (AVIMConversation *)conversationForId:(NSString *)conversationId
{
    if (!conversationId) {
        
        return nil;
    }
    
    NSArray<AVIMConversation *> *results = [self getConversationsFromMemoryWith:@[conversationId]];
    
    AVIMConversation *conv = results.firstObject;
    
    return conv;
}

- (NSArray<AVIMConversation *> *)getConversationsFromMemoryWith:(NSArray<NSString *> *)convIdArray
__attribute__((warn_unused_result))
{
    __block NSArray<AVIMConversation *> *result = nil;
    
    dispatch_sync(_queueOfConvMemory, ^{
        
        result = [self _getConversationsFromMemoryWith:convIdArray];
    });
    
    return result;
}

- (NSArray<AVIMConversation *> *)_getConversationsFromMemoryWith:(NSArray<NSString *> *)convIdArray
__attribute__((warn_unused_result))
{
    NSAssert(dispatch_get_specific(_queueOfConvMemory_specific_key) == _queueOfConvMemory_specific_value,
             @"This internal method should run in `_queueOfConvMemory`.");
    
    NSMutableArray<AVIMConversation *> *result = [NSMutableArray array];
    
    if (!convIdArray) {
        
        return result;
    }
    
    for (NSString *convId in convIdArray) {
        
        AVIMConversation *conv = [_conversationDictionary objectForKey:convId];
        
        if (conv) {
            
            [result addObject:conv];
        }
    }
    
    return result;
}

- (void)removeConversationsInMemoryWith:(NSArray<NSString *> *)conversationIDArray
                               callback:(nonnull void (^)(void))callback
{
    if (!conversationIDArray ||
        conversationIDArray.count == 0) {
        
        return;
    }
    
    dispatch_async(_queueOfConvMemory, ^{
        
        [_conversationDictionary removeObjectsForKeys:conversationIDArray];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            callback();
        });
    });
}

- (void)removeAllConversationsInMemoryWith:(void (^)(void))callback
{
    dispatch_async(_queueOfConvMemory, ^{
        
        [_conversationDictionary removeAllObjects];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            callback();
        });
    });
}

// MARK: - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (keyPath == keyPath(_installation, deviceToken)) {
        
        NSString *value = change[NSKeyValueChangeNewKey];
        
        if (value && [value isKindOfClass:[NSString class]]) {
            
            dispatch_async(_internalSerialQueue, ^{
                
                if (_status != AVIMClientStatusOpened) {
                    
                    return ;
                }
                
                [self installationRegisterClientChannel];
            });
        }
    }
}

// MARK: - Thread Unsafe

- (AVIMClientStatus)threadUnsafe_status
{
    return _status;
}

- (id<AVIMClientDelegate>)threadUnsafe_delegate
{
    return _delegate;
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
