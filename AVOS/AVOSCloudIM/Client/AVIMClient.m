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

#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

#if DEBUG
static void *imClientQueue_specific_key;
static void *imClientQueue_specific_value;
#define AssertRunInIMClientQueue assert(dispatch_get_specific(imClientQueue_specific_key) == imClientQueue_specific_value)
#define AssertNotRunInIMClientQueue assert(dispatch_get_specific(imClientQueue_specific_key) != imClientQueue_specific_value)
#else
#define AssertRunInIMClientQueue
#define AssertNotRunInIMClientQueue
#endif

static const NSUInteger kDistinctMessageIdArraySize = 10;

static dispatch_queue_t imClientQueue = NULL;

static BOOL AVIMClientHasInstantiated = NO;

static int64_t AVIMClient_IMSessionConfigBitmap;

static NSUInteger const kLC_ClientId_MaxLength = 64;
static NSString * const kLC_SessionTag_Default = @"default";
static NSInteger const kLC_Code_SessionConflict = 4111;
NSInteger const kLC_Code_SessionTokenExpired = 4112;

NSString * const kTemporaryConversationIdPrefix = @"_tmp:";

/**
 Session open config bitmap.

 - LCIMSessionConfigOptions_Patch: Support message patch.
 - LCIMSessionConfigOptions_TempConv: Support temporary conversation.
 - LCIMSessionConfigOptions_AutoBindInstallation: Support auto bind installation table.
 - LCIMSessionConfigOptions_TransientACK: Support transient message's ack.
 - LCIMSessionConfigOptions_ReliableNotification: Support reliable notification mechanism.
 - LCIMSessionConfigOptions_CallbackResultSlice: Support callback result with part success and part failure.
 */
typedef NS_OPTIONS(NSUInteger, LCIMSessionConfigOptions) {
    LCIMSessionConfigOptions_Patch = 1 << 0,
    LCIMSessionConfigOptions_TempConv = 1 << 1,
    LCIMSessionConfigOptions_AutoBindInstallation = 1 << 2,
    LCIMSessionConfigOptions_TransientACK = 1 << 3,
    LCIMSessionConfigOptions_ReliableNotification = 1 << 4,
    LCIMSessionConfigOptions_CallbackResultSlice = 1 << 5,
};

static id AVIMClient_JSONObjectFromString(NSString *string, NSJSONReadingOptions options)
{
    if (!string || string.length == 0) {
        
        return nil;
    }
    
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error = nil;
    
    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:options error:&error];
    
    if (error) {
        
        return nil;
    }
    
    return JSONObject;
}

static NSString * AVIMClient_StringFromJSONObject(id JSONObject, NSJSONWritingOptions options)
{
    if (!JSONObject || ![NSJSONSerialization isValidJSONObject:JSONObject]) {
        
        return nil;
    }
    
    NSError *error = nil;
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:JSONObject options:options error:&error];
    
    if (error) {
        
        return nil;
    }
    
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    return (string.length > 0) ? string : nil;
}

static NSDate * AVIMClient_dateFromString(NSString *string)
{
    if (!string || string.length == 0) {
        
        return nil;
    }
    
    NSDateFormatter *dateFormatter = ({
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:AV_DATE_FORMAT];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        dateFormatter;
    });
    
    NSDate *date = [dateFormatter dateFromString:string];
    
    return date;
}

@implementation AVIMClient {
    
    __weak id<AVIMClientDelegate> _delegate;
    
    __weak id<AVIMSignatureDataSource> _signatureDataSource;
    
    AVIMWebSocketWrapper *_socketWrapper;
    
    AVIMClientStatus _status;
    
    NSString *_sessionToken;
    NSTimeInterval _sessionTokenExpireTimestamp;
    
    AVInstallation *_installation;
    NSString *_deviceToken;
    dispatch_block_t _addClientIdToChannels_block;
    dispatch_block_t _removeClientIdToChannels_block;
    dispatch_block_t _uploadDeviceToken_block;
    BOOL _isDeviceTokenUploaded;
    
    dispatch_queue_t _internalSerialQueue;
    
    dispatch_queue_t _signatureQueue;
    
    NSMutableArray *_distinctMessageIdArray;
    
    dispatch_queue_t _queueOfConvMemory;
    
    int64_t _lastPatchTimestamp;
    
    int64_t _lastUnreadTimestamp;
    
    NSMutableDictionary<NSString *, NSMutableArray<void (^)(AVIMConversation *, NSError *)> *> *_callbackMapOfQueryConversation;
    
#ifdef DEBUG
    
    void *_queueOfConvMemory_specific_key;
    
    void *_queueOfConvMemory_specific_value;
    
#endif
}

+ (void)initialize {
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        imClientQueue = dispatch_queue_create("cn.leancloud.im", DISPATCH_QUEUE_SERIAL);
        
        AVIMClient_IMSessionConfigBitmap = ({
            (
             LCIMSessionConfigOptions_Patch |
             LCIMSessionConfigOptions_TempConv |
             LCIMSessionConfigOptions_TransientACK |
             LCIMSessionConfigOptions_CallbackResultSlice
             );
        });
        
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

+ (void)_assertClientIdsIsValid:(NSArray *)clientIds {
    for (id item in clientIds) {
        if (![item isKindOfClass:[NSString class]]) {
            [NSException raise:NSInternalInconsistencyException format:@"ClientId should be NSString but %@ found.", NSStringFromClass([item class])];
            return;
        }
        if ([item length] == 0 || [item length] > kLC_ClientId_MaxLength) {
            [NSException raise:NSInternalInconsistencyException format:@"ClientId length should be in range [1, 64] but found '%@' length %lu.", item, (unsigned long)[item length]];
            return;
        }
    }
}

// MARK: - Init

+ (instancetype)new
{
    [NSException raise:NSInternalInconsistencyException
                format:@"not allow."];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException
                format:@"not allow."];
    return nil;
}

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
        
        _user = nil;
        
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
        
        _user = user;
        
        [self doInitializationWithClientId:user.objectId tag:tag installation:installation];
    }
    
    return self;
}

- (void)doInitializationWithClientId:(NSString *)clientId
                                 tag:(NSString *)tag
                        installation:(AVInstallation *)installation
{
    self->_clientId = ({
        if (!clientId || clientId.length > kLC_ClientId_MaxLength || clientId.length == 0) {
            [NSException raise:NSInvalidArgumentException
                        format:@"clientId invalid or length not in range [1 %lu].", (unsigned long)kLC_ClientId_MaxLength];
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
    
    self->_sessionToken = ({
        self->_sessionTokenExpireTimestamp = 0;
        nil;
    });;
    
    _lastPatchTimestamp = 0;
    _lastUnreadTimestamp = 0;
    
    _stagedMessages = [[NSMutableDictionary alloc] init];
    _messageQueryCacheEnabled = YES;
    
    _distinctMessageIdArray = [NSMutableArray arrayWithCapacity:kDistinctMessageIdArraySize + 1];
    
    _conversationDictionary = [NSMutableDictionary dictionary];
    
    _callbackMapOfQueryConversation = [NSMutableDictionary dictionary];
    
    _internalSerialQueue = imClientQueue;
    
    _signatureQueue = ({
        NSString *className = NSStringFromClass([self class]);
        NSString *ivarName = ivarName(self, _signatureQueue);
        NSString *label = [NSString stringWithFormat:@"%@.%@", className, ivarName];
        dispatch_queue_create(label.UTF8String, DISPATCH_QUEUE_CONCURRENT);
    });
    
    _queueOfConvMemory = dispatch_queue_create("AVIMClient._queueOfConvMemory", NULL);
    
#ifdef DEBUG
    _queueOfConvMemory_specific_key = (__bridge void *)_queueOfConvMemory;
    _queueOfConvMemory_specific_value = (__bridge void *)_queueOfConvMemory;
    dispatch_queue_set_specific(_queueOfConvMemory,
                                _queueOfConvMemory_specific_key,
                                _queueOfConvMemory_specific_value,
                                NULL);
#endif
    
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
        [center addObserver:self
                   selector:@selector(receiveCommand:)
                       name:AVIM_NOTIFICATION_WEBSOCKET_COMMAND
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
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        LCIMConversationCache *cache = [self conversationCache];
        [cache cleanAllExpiredConversations];
    });
}

// MARK: - Dealloc

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self->_installation removeObserver:self forKeyPath:keyPath(self->_installation, deviceToken)];
    [self->_socketWrapper close];
}

// MARK: - Internal Serial Queue

- (dispatch_queue_t)internalSerialQueue
{
    return self->_internalSerialQueue;
}

- (void)addOperationToInternalSerialQueue:(void (^)(AVIMClient *client))block
{
    dispatch_async(self->_internalSerialQueue, ^{
        
        block(self);
    });
}

// MARK: - API Callback Queue

- (void)invokeInSpecifiedQueue:(void (^)(void))block
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        block();
    });
}

// MARK: - Delegate

- (id<AVIMClientDelegate>)delegate
{
    AssertNotRunInIMClientQueue;
    
    __block id<AVIMClientDelegate> delegate = nil;
    
    dispatch_sync(_internalSerialQueue, ^{
        
        delegate = self->_delegate;
    });
    
    return delegate;
}

- (void)setDelegate:(id<AVIMClientDelegate>)delegate
{
    dispatch_async(_internalSerialQueue, ^{
        
        self->_delegate = delegate;
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

// MARK: - Status

- (AVIMClientStatus)status
{
    AssertNotRunInIMClientQueue;
    
    __block AVIMClientStatus status = AVIMClientStatusNone;
    
    dispatch_sync(_internalSerialQueue, ^{
        
        status = _status;
    });
    
    return status;
}

// MARK: - Open

- (void)openWithCallback:(void (^)(BOOL succeeded, NSError *error))callback
{
    [self openWithOption:AVIMClientOpenOptionForceOpen
                callback:callback];
}

- (void)openWithOption:(AVIMClientOpenOption)openOption
              callback:(void (^)(BOOL succeeded, NSError *error))callback
{
    [self getSessionOpenSignatureWithCallback:^(AVIMSignature *signature) {
        
        AssertRunInIMClientQueue;
        
        if (signature && signature.error) {
            
            [self invokeInSpecifiedQueue:^{
                
                callback(false, signature.error);
            }];
            
            return;
        }
        
        if (self->_status == AVIMClientStatusOpened) {
            
            [self invokeInSpecifiedQueue:^{
                
                callback(true, nil);
            }];
            
            return;
        }
        
        if (self->_status == AVIMClientStatusOpening) {
            
            [self invokeInSpecifiedQueue:^{
                
                NSError *aError = ({
                    NSString *reason = @"can't open before last open done.";
                    LCErrorInternal(reason);
                });
                
                callback(false, aError);
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
                    
                    [client invokeInSpecifiedQueue:^{
                        
                        callback(false, error);
                    }];
                    
                    return;
                }
                
                AVIMGenericCommand *outCommand = ({
                    
                    AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
                    AVIMSessionCommand *sessionCommand = [AVIMSessionCommand new];
                    
                    outCommand.cmd = AVIMCommandType_Session;
                    outCommand.op = AVIMOpType_Open;
                    outCommand.appId = [AVOSCloud getApplicationId];
                    outCommand.peerId = client->_clientId;
                    outCommand.sessionMessage = sessionCommand;
                    
                    if (AVIMClient_IMSessionConfigBitmap) {
                        sessionCommand.configBitmap = AVIMClient_IMSessionConfigBitmap;
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
                    
                    outCommand;
                });
                
                LCIMProtobufCommandWrapper *commandWrapper = ({
                    
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
                        
                        [client invokeInSpecifiedQueue:^{
                            
                            callback(false, commandWrapper.error);
                        }];
                        
                        return;
                    }
                    
                    AVIMGenericCommand *inCommand = commandWrapper.inCommand;
                    AVIMSessionCommand *inSessionCommand = inCommand.sessionMessage;
                    
                    if (!inSessionCommand || !inSessionCommand.st) {
                        
                        if (client->_status == AVIMClientStatusOpening) {
                            
                            client->_status = AVIMClientStatusClosed;
                            
                            [client clearSessionTokenAndTTL];
                        }
                        
                        [client invokeInSpecifiedQueue:^{
                            
                            NSError *aError = ({
                                NSString *reason = @"invalid session open.";
                                LCErrorInternal(reason);
                            });
                            
                            callback(false, aError);
                        }];
                        
                        return;
                    }
                    
                    client->_status = AVIMClientStatusOpened;
                    
                    [client setSessionTokenAndTTL:inSessionCommand];
                    
                    [client addClientIdToChannels:1];
                    
                    client->_isDeviceTokenUploaded = false;
                    
                    [client uploadDeviceToken:1];
                    
                    [client invokeInSpecifiedQueue:^{
                        
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
    AssertRunInIMClientQueue;
    
    NSString *imSessionToken = self->_sessionToken;
    
    if (!imSessionToken) {
        
        NSError *aError = ({
            NSString *reason = @"session has not opened or did close.";
            LCErrorInternal(reason);
        });
        
        callback(false, aError);
        
        return;
    }
    
    if (self->_status == AVIMClientStatusOpened) {
        
        callback(true, nil);
        
        return;
    }
    
    LCIMProtobufCommandWrapper * (^newReopenCommand_block)(AVIMSignature *signature, NSString *sessionToken) = ^(AVIMSignature *signature, NSString *sessionToken) {
        
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
            
            if (AVIMClient_IMSessionConfigBitmap) {
                
                sessionCommand.configBitmap = AVIMClient_IMSessionConfigBitmap;
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
    
    void(^handleSessionOpened_block)(AVIMSessionCommand *sessionCommand) = ^(AVIMSessionCommand *sessionCommand) {
        
        self->_status = AVIMClientStatusOpened;
        
        [self setSessionTokenAndTTL:sessionCommand];
        
        if (!self->_isDeviceTokenUploaded) {
            
            [self uploadDeviceToken:1];
        }
    };
    
    LCIMProtobufCommandWrapper *commandWrapper_1 = newReopenCommand_block(nil, imSessionToken);
    
    [commandWrapper_1 setCallback:^(LCIMProtobufCommandWrapper *commandWrapper_1) {
        
        if (commandWrapper_1.error) {
            
            if (commandWrapper_1.error.code == kLC_Code_SessionTokenExpired) {
                
                [self getSessionOpenSignatureWithCallback:^(AVIMSignature *signature) {
                    
                    AssertRunInIMClientQueue;
                    
                    if (signature && signature.error) {
                        
                        callback(false, signature.error);
                        
                        return;
                    }
                    
                    LCIMProtobufCommandWrapper *commandWrapper_2 = newReopenCommand_block(signature, nil);
                    
                    [commandWrapper_2 setCallback:^(LCIMProtobufCommandWrapper *commandWrapper_2) {
                        
                        if (commandWrapper_2.error) {
                            
                            callback(false, commandWrapper_2.error);
                            
                            return;
                        }
                        
                        handleSessionOpened_block(commandWrapper_2.inCommand.sessionMessage);
                        
                        callback(true, nil);
                    }];
                    
                    [self->_socketWrapper sendCommandWrapper:commandWrapper_2];
                }];
                
            } else {
                
                callback(false, commandWrapper_1.error);
            }
            
            return;
        }
        
        handleSessionOpened_block(commandWrapper_1.inCommand.sessionMessage);
        
        callback(true, nil);
    }];
    
    [self->_socketWrapper sendCommandWrapper:commandWrapper_1];
}

// MARK: - Close

- (void)closeWithCallback:(void (^)(BOOL succeeded, NSError *error))callback
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        if (client->_status == AVIMClientStatusClosed) {
            
            [client clearSessionTokenAndTTL];
            
            [client invokeInSpecifiedQueue:^{
                
                callback(true, nil);
            }];
            
            return;
        }
        
        if (client->_status == AVIMClientStatusClosing) {
            
            [client invokeInSpecifiedQueue:^{
                
                NSError *aError = ({
                    NSString *reason = @"can't do close before last close done.";
                    LCErrorInternal(reason);
                });
                
                callback(false, aError);
            }];
            
            return;
        }
        else if (client->_status != AVIMClientStatusOpened) {
            
            [client invokeInSpecifiedQueue:^{
                
                NSError *aError = ({
                    NSString *reason = @"can't do close when not opened.";
                    LCErrorInternal(reason);
                });
                
                callback(false, aError);
            }];
            
            return;
        }
        
        client->_status = AVIMClientStatusClosing;
        
        AVIMGenericCommand *outCommand = ({
            
            AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
            AVIMSessionCommand *sessionCommand = [AVIMSessionCommand new];
            
            outCommand.cmd = AVIMCommandType_Session;
            outCommand.op = AVIMOpType_Close;
            outCommand.sessionMessage = sessionCommand;
            
            outCommand;
        });
        
        LCIMProtobufCommandWrapper *commandWrapper = ({
            
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = outCommand;
            commandWrapper;
        });
        
        [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                
                if (client->_status == AVIMClientStatusClosing) {
                    
                    client->_status = AVIMClientStatusOpened;
                }
                
                [client invokeInSpecifiedQueue:^{
                    
                    callback(false, commandWrapper.error);
                }];
                
                return;
            }
            
            client->_status = AVIMClientStatusClosed;
            
            [client clearSessionTokenAndTTL];
            
            [client removeClientIdFromChannels:1];
            
            client->_isDeviceTokenUploaded = false;
            
            if (client->_uploadDeviceToken_block) {
                
                dispatch_block_cancel(client->_uploadDeviceToken_block);
                
                client->_uploadDeviceToken_block = nil;
            }
            
            [client->_socketWrapper close];
            
            [client invokeInSpecifiedQueue:^{
                
                callback(true, nil);
            }];
        }];
        
        [client->_socketWrapper sendCommandWrapper:commandWrapper];
    }];
}

// MARK: - Session Token

- (void)setSessionTokenAndTTL:(AVIMSessionCommand *)sessionCommand
{
    AssertRunInIMClientQueue;
    
    if (sessionCommand && sessionCommand.st) {
        
        self->_sessionToken = sessionCommand.st;
        
        if (sessionCommand.stTtl) {
            
            self->_sessionTokenExpireTimestamp = NSDate.date.timeIntervalSince1970 + (NSTimeInterval)sessionCommand.stTtl;
        }
    }
}

- (void)clearSessionTokenAndTTL
{
    AssertRunInIMClientQueue;
    
    self->_sessionToken = nil;
    self->_sessionTokenExpireTimestamp = 0;
}

- (void)getSessionTokenWithForcingRefresh:(BOOL)forcingRefresh
                                 callback:(void (^)(NSString *sessionToken, NSError *error))callback
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        NSString *oldSessionToken = client->_sessionToken;
        
        NSError *sessionNotOpenError = ({
            NSString *reason = @"session has not opened or did close.";
            LCErrorInternal(reason);
        });
        
        if (!oldSessionToken || self->_status != AVIMClientStatusOpened) {
            
            callback(nil, sessionNotOpenError);
            
            return;
        }
        
        if (forcingRefresh || (NSDate.date.timeIntervalSince1970 > client->_sessionTokenExpireTimestamp)) {
            
            AVIMGenericCommand *outCommand = ({
                
                AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
                AVIMSessionCommand *sessionCommand = [AVIMSessionCommand new];
                
                outCommand.cmd = AVIMCommandType_Session;
                outCommand.op = AVIMOpType_Refresh;
                outCommand.sessionMessage = sessionCommand;
                
                sessionCommand.st = oldSessionToken; /* let server to clear old session token */
                
                outCommand;
            });
            
            LCIMProtobufCommandWrapper *commandWrapper = ({
                
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
                    
                    callback(nil, sessionNotOpenError);
                    
                    return;
                }
                
                AVIMGenericCommand *inCommand = commandWrapper.inCommand;
                AVIMSessionCommand *sessionCommand = inCommand.sessionMessage;
                
                if (inCommand.cmd == AVIMCommandType_Session &&
                    inCommand.op == AVIMOpType_Refreshed &&
                    sessionCommand && sessionCommand.st) {
                    
                    [client setSessionTokenAndTTL:sessionCommand];
                    
                    callback(sessionCommand.st, nil);
                    
                } else {
                    
                    NSError *aError = ({
                        NSString *reason = @"invalid session refreshed.";
                        LCErrorInternal(reason);
                    });
                    
                    callback(nil, aError);
                }
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
    AssertRunInIMClientQueue;
    
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
                
                AVLoggerError(AVLoggerDomainIM, @"Error: %@", error);
                
                if (delayInterval > 0) {
                    
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
    AssertRunInIMClientQueue;
    
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
                
                AVLoggerError(AVLoggerDomainIM, @"Error: %@", error);
                
                if (delayInterval > 0) {
                    
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
    AssertRunInIMClientQueue;
    
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
        
        [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                
                AVLoggerError(AVLoggerDomainIM, @"Error: %@", commandWrapper.error);
                
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
                        
                        client->_isDeviceTokenUploaded = false;
                        
                        [client addClientIdToChannels:1];
                        
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
                
                AVLoggerError(AVLoggerDomainIM, @"Error: %@", error);
                
            } else {
                
                id <AVIMClientDelegate> delegate = client->_delegate;
                
                if (delegate) {
                    
                    [client invokeInSpecifiedQueue:^{
                        
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
                
                [client invokeInSpecifiedQueue:^{
                    
                    [delegate imClientPaused:client];
                }];
            }
        } else {
            
            NSError *error = notification.userInfo[@"error"];
            
            client->_status = AVIMClientStatusClosed;
            
            [client clearSessionTokenAndTTL];
            
            id<AVIMClientDelegate> delegate = client->_delegate;
            
            if (delegate) {
                
                [client invokeInSpecifiedQueue:^{
                    
                    [delegate imClientClosed:client error:error];
                    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    if ([delegate respondsToSelector:@selector(imClientPaused:error:)]) {
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
            
            [client invokeInSpecifiedQueue:^{
                
                [delegate imClientResuming:client];
            }];
        }
    }];
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
                
            case AVIMCommandType_Direct:
                
                [self processDirectCommand:command];
                
                break;
                
            case AVIMCommandType_Unread:
                
                [self processUnreadCommand:command];
                
                break;
                
            case AVIMCommandType_Rcp:
                
                [self processReceiptCommand:command];
                
                break;
                
            default:
                
                break;
        }
    });
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
                
                signature.error = ({
                    NSString *reason = @"AVUser's Session Token is invalid.";
                    LCErrorInternal(reason);
                });
                
                callback(signature);
                
                return;
            }
            
            AVPaasClient *paasClient = [AVPaasClient sharedInstance];
            
            NSURLRequest *request = ({
                NSDictionary *parameters = @{ @"session_token" : userSessionToken };
                [paasClient requestWithPath:@"rtm/sign"
                                     method:@"POST"
                                    headers:nil
                                 parameters:parameters];
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
                
                signature.error = ({
                    NSString *reason = [NSString stringWithFormat:@"response data: %@ is invalid.", (result ?: @"nil")];
                    LCErrorInternal(reason);
                });
                
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
                
                AssertRunInIMClientQueue;
                
                callback(signature);
            }];
        }
    }];
}

- (void)getSignatureWithConversationId:(NSString *)conversationId
                                action:(AVIMSignatureAction)action
                     actionOnClientIds:(NSArray<NSString *> *)actionOnClientIds
                              callback:(void (^)(AVIMSignature *signature))callback
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

// MARK: - Send Command

- (void)sendCommand:(AVIMGenericCommand *)command
{
    dispatch_async(_internalSerialQueue, ^{
        
        [self _sendCommand:command];
    });
}

- (void)_sendCommand:(AVIMGenericCommand *)command
{
    AssertRunInIMClientQueue;
    
    if (_status != AVIMClientStatusOpened) {
        
        AVIMCommandResultBlock callback = command.callback;
        
        if (callback) {
            
            NSError *error = LCError(kAVIMErrorClientNotOpen, @"Client Not Open when Send a Command.", nil);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(command, nil, error);
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
    AssertRunInIMClientQueue;
    
    if (self->_status != AVIMClientStatusOpened) {
        
        if (commandWrapper.hasCallback) {
            
            commandWrapper.error = ({
                
                NSString *reason = @"client not opened.";
                LCErrorInternal(reason);
            });
            
            [commandWrapper executeCallbackAndSetItToNil];
        }
        
        return;
    }
    
    [self->_socketWrapper sendCommandWrapper:commandWrapper];
}

// MARK: - AVIMWebSocketWrapperDelegate

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
            
            client->_isDeviceTokenUploaded = false;
            
            if (client->_uploadDeviceToken_block) {
                
                dispatch_block_cancel(client->_uploadDeviceToken_block);
                
                client->_uploadDeviceToken_block = nil;
            }
            
            id <AVIMClientDelegate> delegate = client->_delegate;
            
            SEL sel = @selector(client:didOfflineWithError:);
            
            if (delegate && [delegate respondsToSelector:sel]) {
                
                [client invokeInSpecifiedQueue:^{
                    
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
        
        switch (inCommand.cmd)
        {
            case AVIMCommandType_Session:
            {
                switch (inCommand.op)
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
                switch (inCommand.op)
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
                
            case AVIMCommandType_Patch:
            {
                switch (inCommand.op)
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

// MARK: - Process In Command

- (void)process_session_closed:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    self->_status = AVIMClientStatusClosed;
    
    [self clearSessionTokenAndTTL];
    
    AVIMSessionCommand *sessionCommand = inCommand.sessionMessage;
    
    if (!sessionCommand) {
        
        return;
    }
    
    if (sessionCommand.code == kLC_Code_SessionConflict) {
        
        [self removeClientIdFromChannels:1];
        
        self->_isDeviceTokenUploaded = false;
        
        if (self->_uploadDeviceToken_block) {
            
            dispatch_block_cancel(self->_uploadDeviceToken_block);
            
            self->_uploadDeviceToken_block = nil;
        }
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(client:didOfflineWithError:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
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

- (void)process_patch_modify:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    NSArray<AVIMPatchItem *> *patchArray = inCommand.patchMessage.patchesArray;
    
    for (AVIMPatchItem *patchItem in patchArray) {
        
        if (patchItem.patchTimestamp > _lastPatchTimestamp) {
            
            _lastPatchTimestamp = patchItem.patchTimestamp;
        }
        
        NSString *conversationId = patchItem.cid;
        NSString *messageId = patchItem.mid;
        NSString *payloadString = patchItem.data_p;
        
        if (conversationId && messageId && payloadString) {
            
            LCIMMessageCacheStore *messageCacheStore = [self messageCacheStoreForConversationId:conversationId];
            
            AVIMMessage *message = [messageCacheStore messageForId:messageId];
            
            if (message) {
                
                NSDictionary<NSString *, id> *entries = @{
                                                          LCIM_FIELD_PAYLOAD: payloadString,
                                                          LCIM_FIELD_PATCH_TIMESTAMP: @((double)patchItem.patchTimestamp),
                                                          @"mention_all": @(patchItem.mentionAll),
                                                          @"mention_list": patchItem.mentionPidsArray ? [NSKeyedArchiver archivedDataWithRootObject:patchItem.mentionPidsArray] : [NSNull null],
                                                          };
                
                [messageCacheStore updateEntries:entries forMessageId:messageId];
                
                message.content = payloadString;
                message.updatedAt = [NSDate dateWithTimeIntervalSince1970:(patchItem.patchTimestamp / 1000.0)];
                message.mentionAll = patchItem.mentionAll;
                message.mentionList = patchItem.mentionPidsArray;
                
                if ([message isKindOfClass:[AVIMTypedMessage class]]) {
                    
                    ((AVIMTypedMessage *)message).messageObject = [[AVIMTypedMessageObject alloc] initWithJSON:patchItem.data_p];
                }
                
            } else {
                
                AVIMTypedMessageObject *messageObject = [[AVIMTypedMessageObject alloc] initWithJSON:patchItem.data_p];
                
                if ([messageObject isValidTypedMessageObject]) {
                    
                    message = [AVIMTypedMessage messageWithMessageObject:messageObject];
                    
                } else {
                    
                    message = [[AVIMMessage alloc] init];
                }
                
                message.content = patchItem.data_p;
                message.sendTimestamp = patchItem.timestamp;
                message.conversationId = conversationId;
                message.clientId = patchItem.from;
                message.messageId = messageId;
                message.status = AVIMMessageStatusNone;
                message.localClientId = _clientId;
                message.mentionAll = patchItem.mentionAll;
                message.mentionList = patchItem.mentionPidsArray;
                message.updatedAt = [NSDate dateWithTimeIntervalSince1970:(patchItem.patchTimestamp / 1000.0)];
                
                [messageCacheStore insertOrUpdateMessage:message withBreakpoint:YES];
            }
            
            [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
                
                if (error) { return; }
                
                if ([conversation.lastMessage.messageId isEqualToString:message.messageId]) {
                    
                    conversation.lastMessage = message;
                }
                
                id <AVIMClientDelegate> delegate = self->_delegate;
                
                if (conversation && message && delegate && [delegate respondsToSelector:@selector(conversation:messageHasBeenUpdated:)]) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        [delegate conversation:conversation messageHasBeenUpdated:message];
                    });
                }
            }];
        }
    }
    
    LCIMProtobufCommandWrapper *ackCommandWrapper = ({
        
        AVIMGenericCommand *command = [[AVIMGenericCommand alloc] init];
        command.cmd = AVIMCommandType_Patch;
        command.op = AVIMOpType_Modified;
        AVIMPatchCommand *patchMessage = [[AVIMPatchCommand alloc] init];
        patchMessage.lastPatchTime = _lastPatchTimestamp;
        command.patchMessage = patchMessage;
        
        LCIMProtobufCommandWrapper *commandWrapper = [[LCIMProtobufCommandWrapper alloc] init];
        commandWrapper.outCommand = command;
        commandWrapper;
    });
    
    [self _sendCommandWrapper:ackCommandWrapper];
}

- (void)process_conv_joined:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    NSString *conversationId = inCommand.convMessage.cid;
    NSString *initById = inCommand.convMessage.initBy;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        [conversation addMember:self->_clientId];
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:invitedByClientId:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation invitedByClientId:initById];
            }];
        }
    }];
}

- (void)process_conv_members_joined:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    NSString *conversationId = inCommand.convMessage.cid;
    NSArray<NSString *> *memberIds = inCommand.convMessage.mArray;
    NSString *initById = inCommand.convMessage.initBy;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        [conversation addMembers:memberIds];
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:membersAdded:byClientId:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation membersAdded:memberIds byClientId:initById];
            }];
        }
    }];
}

- (void)process_conv_left:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    NSString *conversationId = inCommand.convMessage.cid;
    NSString *initById = inCommand.convMessage.initBy;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        [conversation removeMember:self->_clientId];
        
        [[self conversationCache] removeConversationAndItsMessagesForId:conversationId];
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:kickedByClientId:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation kickedByClientId:initById];
            }];
        }
    }];
}

- (void)process_conv_members_left:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    NSString *conversationId = inCommand.convMessage.cid;
    NSArray<NSString *> *memberIds = inCommand.convMessage.mArray;
    NSString *initById = inCommand.convMessage.initBy;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        [conversation removeMembers:memberIds];
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:membersRemoved:byClientId:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation membersRemoved:memberIds byClientId:initById];
            }];
        }
    }];
}

- (void)process_conv_updated:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    NSString *conversationId = inCommand.convMessage.cid;
    NSString *initById = inCommand.convMessage.initBy;
    NSDate *updateDate = AVIMClient_dateFromString(inCommand.convMessage.udate);
    id JSONObject = AVIMClient_JSONObjectFromString(inCommand.convMessage.attr.data_p, 0);
    
    if (!conversationId || ![NSDictionary lc__checkingType:JSONObject]) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        [conversation mergeConvUpdatedMessage:JSONObject];
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:didUpdateAt:byClientId:updatedData:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation didUpdateAt:updateDate byClientId:initById updatedData:JSONObject];
            }];
        }
    }];
}

- (void)process_conv_member_info_changed:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    NSString *conversationId = inCommand.convMessage.cid;
    NSString *initById = inCommand.convMessage.initBy;
    NSString *memberId = inCommand.convMessage.info.pid;
    NSString *role = inCommand.convMessage.info.role;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        [conversation process_member_info_changed:inCommand];
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:didMemberInfoUpdateBy:memberId:role:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation didMemberInfoUpdateBy:initById memberId:memberId role:role];
            }];
        }
    }];
}

- (void)process_conv_blocked:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    AVIMConvCommand *convCommand = inCommand.convMessage;
    NSString *conversationId = convCommand.cid;
    NSString *initById = convCommand.initBy;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:didBlockBy:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation didBlockBy:initById];
            }];
        }
    }];
}

- (void)process_conv_members_blocked:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    AVIMConvCommand *convCommand = inCommand.convMessage;
    NSString *conversationId = convCommand.cid;
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = convCommand.initBy;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:didMembersBlockBy:memberIds:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation didMembersBlockBy:initById memberIds:memberIds];
            }];
        }
    }];
}

- (void)process_conv_unblocked:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    AVIMConvCommand *convCommand = inCommand.convMessage;
    NSString *conversationId = convCommand.cid;
    NSString *initById = convCommand.initBy;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:didUnblockBy:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation didUnblockBy:initById];
            }];
        }
    }];
}

- (void)process_conv_members_unblocked:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    AVIMConvCommand *convCommand = inCommand.convMessage;
    NSString *conversationId = convCommand.cid;
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = convCommand.initBy;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:didMembersUnblockBy:memberIds:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation didMembersUnblockBy:initById memberIds:memberIds];
            }];
        }
    }];
}

- (void)process_conv_shutuped:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    AVIMConvCommand *convCommand = inCommand.convMessage;
    NSString *conversationId = convCommand.cid;
    NSString *initById = convCommand.initBy;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:didMuteBy:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation didMuteBy:initById];
            }];
        }
    }];
}

- (void)process_conv_members_shutuped:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    AVIMConvCommand *convCommand = inCommand.convMessage;
    NSString *conversationId = convCommand.cid;
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = convCommand.initBy;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:didMembersMuteBy:memberIds:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation didMembersMuteBy:initById memberIds:memberIds];
            }];
        }
    }];
}

- (void)process_conv_unshutuped:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    AVIMConvCommand *convCommand = inCommand.convMessage;
    NSString *conversationId = convCommand.cid;
    NSString *initById = convCommand.initBy;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:didUnmuteBy:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation didUnmuteBy:initById];
            }];
        }
    }];
}

- (void)process_conv_members_unshutuped:(AVIMGenericCommand *)inCommand
{
    AssertRunInIMClientQueue;
    
    AVIMConvCommand *convCommand = inCommand.convMessage;
    NSString *conversationId = convCommand.cid;
    NSArray<NSString *> *memberIds = convCommand.mArray;
    NSString *initById = convCommand.initBy;
    
    if (!conversationId) {
        
        return;
    }
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        id <AVIMClientDelegate> delegate = self->_delegate;
        
        SEL sel = @selector(conversation:didMembersUnmuteBy:memberIds:);
        
        if (delegate && [delegate respondsToSelector:sel]) {
            
            [self invokeInSpecifiedQueue:^{
                
                [delegate conversation:conversation didMembersUnmuteBy:initById memberIds:memberIds];
            }];
        }
    }];
}

// MARK: - Query Conversation

- (void)queryConversationWithId:(NSString *)conversationId
                       callback:(void (^)(AVIMConversation *conversation, NSError *error))callback
{
    AssertRunInIMClientQueue;
    NSParameterAssert(conversationId);
    
    [self queryConversationWithId:conversationId
                      queryOption:AVIMConversationQueryOptionWithMessage
                         callback:callback];
}

- (void)queryConversationWithId:(NSString *)conversationId
                    queryOption:(AVIMConversationQueryOption)queryOption
                       callback:(void (^)(AVIMConversation *conversation, NSError *error))callback
{
    AssertRunInIMClientQueue;
    NSParameterAssert(conversationId);
    
    AVIMConversation *conversation = [self conversationForId:conversationId];
    
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
    AssertRunInIMClientQueue;
    NSParameterAssert(conversationId);
    
    NSMutableArray<void (^)(AVIMConversation *, NSError *)> *callbacks_1 = self->_callbackMapOfQueryConversation[conversationId];
    
    if (callbacks_1) {
        
        [callbacks_1 addObject:callback];
        
        return;
    }
    
    NSError *JSONSerializationError = nil;
    
    NSString *whereString = ({
        NSString *whereString = nil;
        if (![conversationId hasPrefix:kTemporaryConversationIdPrefix]) {
            NSData *data = [NSJSONSerialization dataWithJSONObject:@{ @"objectId" : conversationId }
                                                           options:0
                                                             error:&JSONSerializationError];
            if (data) {
                whereString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
        }
        whereString;
    });
    
    if (JSONSerializationError) {
        
        callback(nil, JSONSerializationError);
        
        return;
    }
    
    self->_callbackMapOfQueryConversation[conversationId] = [NSMutableArray arrayWithObject:callback];
    
    LCIMProtobufCommandWrapper *commandWrapper = ({

        AVIMGenericCommand *outCommand = [[AVIMGenericCommand alloc] init];
        AVIMConvCommand *convCommand = [[AVIMConvCommand alloc] init];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_Query;
        outCommand.convMessage = convCommand;
        
        if (queryOption) {
            convCommand.flag = queryOption;
        }
        
        if (whereString) {
            AVIMJsonObjectMessage *jsonObjectMessage = [[AVIMJsonObjectMessage alloc] init];
            convCommand.where = jsonObjectMessage;
            jsonObjectMessage.data_p = whereString;
        }
        else if ([conversationId hasPrefix:kTemporaryConversationIdPrefix]) {
            convCommand.tempConvIdsArray = [NSMutableArray arrayWithObject:conversationId];
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = [[LCIMProtobufCommandWrapper alloc] init];
        commandWrapper.outCommand = outCommand;
        
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        NSMutableArray<void (^)(AVIMConversation *, NSError *)> *callbacka_2 = self->_callbackMapOfQueryConversation[conversationId];
        
        if (callbacka_2) {
            
            [self->_callbackMapOfQueryConversation removeObjectForKey:conversationId];
        }
        
        void(^invokeAllCallback_block)(AVIMConversation *, NSError *) = ^(AVIMConversation *conversation, NSError *error) {
            
            for (void (^item_block)(AVIMConversation *, NSError *) in callbacka_2) {
                
                item_block(conversation, error);
            }
        };
        
        if (commandWrapper.error) {
            
            AVLoggerError(AVLoggerDomainIM, @"Error: %@", commandWrapper.error);
            
            invokeAllCallback_block(nil, commandWrapper.error);
            
            return;
        }
        
        AVIMJsonObjectMessage *results = ({
            
            AVIMGenericCommand *inCommand = commandWrapper.inCommand;
            AVIMConvCommand *convCommand = inCommand.convMessage;
            AVIMJsonObjectMessage *results = convCommand.results;
            results;
        });
        
        NSArray *JSONObject = AVIMClient_JSONObjectFromString(results.data_p, NSJSONReadingMutableContainers);
        
        NSError *queryResultError = ({
            NSString *reason = [NSString stringWithFormat:@"Query result is invalid, data: %@", (JSONObject ?: @"nil")];
            LCErrorInternal(reason);
        });
        
        if (![NSArray lc__checkingType:JSONObject] || JSONObject.count != 1) {
            
            AVLoggerError(AVLoggerDomainIM, @"%@", queryResultError);
            
            invokeAllCallback_block(nil, queryResultError);
            
            return;
        }
        
        AVIMConversation *conversation = ({
            
            AVIMConversation *conversation = nil;
            
            NSDictionary *dic = JSONObject.firstObject;
            
            if ([NSDictionary lc__checkingType:dic]) {
                
                conversation = [AVIMConversation newWithRawJSONData:dic client:self];
            }
            
            conversation;
        });
        
        if (!conversation) {
            
            AVLoggerError(AVLoggerDomainIM, @"%@", queryResultError);
            
            invokeAllCallback_block(nil, queryResultError);
            
            return;
        }
        
        [self cacheConversationToMemory:conversation];
        
        [[self conversationCache] cacheConversations:@[conversation]
                                              maxAge:3600
                                          forCommand:[commandWrapper.outCommand avim_conversationForCache]];
        
        invokeAllCallback_block(conversation, nil);
    }];
    
    [self _sendCommandWrapper:commandWrapper];
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

// MARK: - Create Conversation

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
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        for (NSString *item in clientIds) {
            
            if (item.length > kLC_ClientId_MaxLength || item.length == 0) {
                
                [client invokeInSpecifiedQueue:^{
                    
                    NSError *aError = ({
                        NSString *reason = [NSString stringWithFormat:@"client id's length should in range [1 %lu].", (unsigned long)kLC_ClientId_MaxLength];
                        LCErrorInternal(reason);
                    });
                    
                    callback(nil, aError);
                }];
                
                return;
            }
        }
        
        BOOL unique = options & AVIMConversationOptionUnique;
        BOOL transient = options & AVIMConversationOptionTransient;
        BOOL temporary = options & AVIMConversationOptionTemporary;
        
        if ((unique && transient) || (unique && temporary) || (transient && temporary)) {
            
            [client invokeInSpecifiedQueue:^{
                
                NSError *aError = ({
                    NSString *reason = @"options is invalid.";
                    LCErrorInternal(reason);
                });
                
                callback(nil, aError);
            }];
            
            return;
        }
        
        NSMutableArray *members = ({
            
            NSMutableSet *set = [NSMutableSet setWithArray:(clientIds ?: @[])];
            [set addObject:client->_clientId];
            [[set allObjects] mutableCopy];
        });
        
        [client getSignatureWithConversationId:nil action:AVIMSignatureActionStart actionOnClientIds:[members copy] callback:^(AVIMSignature *signature) {
            
            AssertRunInIMClientQueue;
            
            if (signature && signature.error) {
                
                [client invokeInSpecifiedQueue:^{
                    
                    callback(nil, signature.error);
                }];
                
                return;
            }
            
            AVIMGenericCommand *outCommand = ({
                
                AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
                AVIMConvCommand *convCommand = [AVIMConvCommand new];
                
                outCommand.cmd = AVIMCommandType_Conv;
                outCommand.op = AVIMOpType_Start;
                outCommand.convMessage = convCommand;
                
                convCommand.attr = ({
                    
                    AVIMJsonObjectMessage *jsonObjectMessage = nil;
                    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
                    if (name) { dic[kConvAttrKey_name] = name; }
                    if (attributes) { dic[kConvAttrKey_attributes] = attributes; }
                    if (dic.count > 0) {
                        NSString *jsonString = AVIMClient_StringFromJSONObject(dic, 0);
                        if (jsonString) {
                            jsonObjectMessage = [AVIMJsonObjectMessage new];
                            jsonObjectMessage.data_p = jsonString;
                        }
                    }
                    jsonObjectMessage;
                });
                
                if (transient) {
                    convCommand.transient = transient;
                }
                else if (temporary) {
                    convCommand.tempConv = temporary;
                    if (temporaryTTL > 0) {
                        convCommand.tempConvTtl = temporaryTTL;
                    }
                    convCommand.mArray = members;
                }
                else {
                    if (unique) {
                        convCommand.unique = unique;
                    }
                    convCommand.mArray = members;
                }
                
                if (signature && signature.signature && signature.timestamp && signature.nonce) {
                    convCommand.s = signature.signature;
                    convCommand.t = signature.timestamp;
                    convCommand.n = signature.nonce;
                }
                
                outCommand;
            });
            
            LCIMProtobufCommandWrapper *commandWrapper = ({
                
                LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
                commandWrapper.outCommand = outCommand;
                commandWrapper;
            });
            
            [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
                
                if (commandWrapper.error) {
                    
                    [client invokeInSpecifiedQueue:^{
                    
                        callback(nil, commandWrapper.error);
                    }];
                    
                    return;
                }
                
                AVIMGenericCommand *inCommand = commandWrapper.inCommand;
                AVIMConvCommand *inConvCommand = inCommand.convMessage;
                
                NSString *conversationId = inConvCommand.cid;
                
                LCIMConvType convType = ({
                    
                    LCIMConvType convType;
                    if (transient) {
                        convType = LCIMConvTypeTransient;
                    } else if (temporary) {
                        convType = LCIMConvTypeTemporary;
                    } else {
                        convType = LCIMConvTypeNormal;
                    }
                    convType;
                });
                
                AVIMConversation *conversation = [client getConversationWithId:conversationId orNewWithType:convType];
                
                if (!conversation) {
                    
                    [client invokeInSpecifiedQueue:^{
                        
                        NSError *aError = ({
                            NSString *reason = @"create conversation failed.";
                            LCErrorInternal(reason);
                        });
                        
                        callback(nil, aError);
                    }];
                    
                    return;
                }
                
                conversation.name = name;
                conversation.attributes = [attributes mutableCopy];
                conversation.creator = client->_clientId;
                conversation.createAt = AVIMClient_dateFromString(inConvCommand.cdate);
                conversation.temporaryTTL = inConvCommand.tempConvTtl;
                conversation.unique = unique;
                conversation.uniqueId = inConvCommand.uniqueId;
                [conversation addMembers:members];
                
                [client invokeInSpecifiedQueue:^{
                    
                    callback(conversation, nil);
                }];
            }];
            
            [client sendCommandWrapper:commandWrapper];
        }];
    }];
}

// MARK: -

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

- (void)queryOnlineClientsInClients:(NSArray<NSString *> *)clients
                           callback:(void (^)(NSArray<NSString *> *, NSError *))callback
{
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
        AVLoggerError(AVLoggerDomainIM, @"Received an invalid message.");
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
    
    void(^messageNotification_block)(AVIMConversation *) = ^(AVIMConversation *conversation) {
        
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        
        dictionary[@"unreadMessagesCount"] = @(unreadTuple.unread);
        dictionary[@"lastMessage"] = [self messageWithUnreadTuple:unreadTuple];
        
        if (unreadTuple.hasMentioned) {
            
            dictionary[@"unreadMessagesMentioned"] = @(unreadTuple.mentioned);
        }
        
        [self updateConversation:conversationId withDictionary:dictionary];
        
        /* For compatibility, we reserve this callback. It should be removed in future. */
        id<AVIMClientDelegate> delegate = self->_delegate;
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
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        messageNotification_block(conversation);
    }];
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
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        updateReceipt_block(conversation);
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
        LCIM_NOTIFY_PROPERTY_UPDATE(_clientId, conversation.conversationId, key, date);
    }
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
    
    [self queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        
        if (error) { return; }
        
        [self passMessage:message toConversation:conversation];
        [self postNotificationForMessage:message];
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

- (void)receiveMessageDelivered:(AVIMMessage *)message
                   conversation:(AVIMConversation *)conversation
{
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
    [self array:arguments addObject:conversation];
    [self array:arguments addObject:message];
    [AVIMRuntimeHelper callMethodInMainThreadWithTarget:_delegate selector:@selector(conversation:messageDelivered:) arguments:arguments];
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

- (void)cacheConversationToMemory:(AVIMConversation *)conversation
{
    dispatch_async(_queueOfConvMemory, ^{
        
        if (conversation && conversation.conversationId) {
            
            _conversationDictionary[conversation.conversationId] = conversation;
        }
    });
}

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

// MARK: - Thread Unsafe

- (AVIMClientStatus)threadUnsafe_status
{
    return self->_status;
}

- (id<AVIMClientDelegate>)threadUnsafe_delegate
{
    return self->_delegate;
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
