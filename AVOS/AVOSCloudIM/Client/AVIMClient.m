//
//  AVIM.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMClient_Internal.h"
#import "AVIMConversation_Internal.h"
#import "AVIMKeyedConversation_internal.h"
#import "AVIMConversationMemberInfo_Internal.h"
#import "AVIMConversationQuery_Internal.h"
#import "AVIMTypedMessage_Internal.h"

#import "AVIMErrorUtil.h"

#import "UserAgent.h"
#import "AVObjectUtils.h"
#import "AVUtils.h"
#import "AVPaasClient.h"
#import "AVErrorUtils.h"

static BOOL gClientHasInstantiated = false;

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
    AVIMClientStatus _status;
}

+ (instancetype)alloc
{
    gClientHasInstantiated = true;
    return [super alloc];
}

+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds
{
    [LCRTMConnection setConnectingTimeoutInterval:seconds];
}

+ (instancetype)new
{
    [NSException raise:NSInternalInconsistencyException
                format:@"no support"];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException
                format:@"no support"];
    return nil;
}

// MARK: Initialization

- (instancetype)initWithClientId:(NSString *)clientId
{
    return [self initWithClientId:clientId
                              tag:nil
                            error:nil];
}

- (instancetype)initWithClientId:(NSString *)clientId
                           error:(NSError *__autoreleasing  _Nullable *)error
{
    return [self initWithClientId:clientId
                              tag:nil
                            error:error];
}

- (instancetype)initWithClientId:(NSString *)clientId
                             tag:(NSString *)tag
{
    return [self initWithClientId:clientId
                              tag:tag
                            error:nil];
}

- (instancetype)initWithClientId:(NSString *)clientId
                             tag:(NSString *)tag
                           error:(NSError *__autoreleasing  _Nullable *)error
{
    return [self initWithClientId:clientId
                              tag:tag
                     installation:[AVInstallation defaultInstallation]
                            error:error];
}

- (instancetype)initWithUser:(AVUser *)user
{
    return [self initWithUser:user
                          tag:nil
                        error:nil];
}

- (instancetype)initWithUser:(AVUser *)user
                       error:(NSError *__autoreleasing  _Nullable *)error
{
    return [self initWithUser:user
                          tag:nil
                        error:error];
}

- (instancetype)initWithUser:(AVUser *)user
                         tag:(NSString *)tag
{
    return [self initWithUser:user
                          tag:tag
                        error:nil];
}

- (instancetype)initWithUser:(AVUser *)user
                         tag:(NSString *)tag
                       error:(NSError *__autoreleasing  _Nullable *)error
{
    return [self initWithUser:user
                          tag:tag
                 installation:[AVInstallation defaultInstallation]
                        error:error];
}

- (instancetype)initWithClientId:(NSString *)clientId
                             tag:(NSString *)tag
                    installation:(AVInstallation *)installation
                           error:(NSError *__autoreleasing  _Nullable *)error
{
    self = [super init];
    if (self) {
        NSError *err = [self doInitializationWithClientId:clientId
                                                      tag:tag
                                             installation:installation];
        if (err) {
            if (error) {
                *error = err;
            }
            return nil;
        }
    }
    return self;
}

- (instancetype)initWithUser:(AVUser *)user
                         tag:(NSString *)tag
                installation:(AVInstallation *)installation
                       error:(NSError *__autoreleasing  _Nullable *)error
{
    self = [super init];
    if (self) {
        _user = user;
        NSError *err = [self doInitializationWithClientId:user.objectId
                                                      tag:tag
                                             installation:installation];
        if (err) {
            if (error) {
                *error = err;
            }
            return nil;
        }
    }
    return self;
}

- (NSError *)doInitializationWithClientId:(NSString *)clientId
                                      tag:(NSString *)tag
                             installation:(AVInstallation *)installation
{
    if (!clientId ||
        clientId.length > kClientIdLengthLimit ||
        clientId.length == 0) {
        return LCError(AVErrorInternalErrorCodeInconsistency,
                       @"The length of `clientId` should in range `[1 64]`.", nil);
    }
    _clientId = clientId.copy;
    if ([tag isEqualToString:kClientTagDefault]) {
        return LCError(AVErrorInternalErrorCodeInconsistency,
                       @"The tag `%@` is reserved.", nil);
    }
    _tag = (tag ? tag.copy : nil);
    _messageQueryCacheEnabled = true;
    _sessionConfigBitmap = (LCIMSessionConfigOptionsPatchMessage |
                            LCIMSessionConfigOptionsTemporaryConversationMessage |
                            LCIMSessionConfigOptionsTransientMessageACK |
                            LCIMSessionConfigOptionsPartialFailedMessage);
    _status = AVIMClientStatusNone;
    _lock = [NSLock new];
    _lastUnreadNotifTime = 0;
    _lastPatchTime = 0;
    _internalSerialQueue = ({
        NSString *className = NSStringFromClass(self.class);
        NSString *propertyName = keyPath(self, internalSerialQueue);
        NSString *label = [NSString stringWithFormat:@"LC.Objc.%@.%@", className, propertyName];
        dispatch_queue_t queue = dispatch_queue_create(label.UTF8String, DISPATCH_QUEUE_SERIAL);
#if DEBUG
        void *key = (__bridge void *)queue;
        dispatch_queue_set_specific(queue, key, key, NULL);
#endif
        queue;
    });
    _signatureQueue = ({
        NSString *className = NSStringFromClass(self.class);
        NSString *propertyName = keyPath(self, signatureQueue);
        NSString *label = [NSString stringWithFormat:@"LC.Objc.%@.%@", className, propertyName];
        dispatch_queue_t queue = dispatch_queue_create(label.UTF8String, DISPATCH_QUEUE_CONCURRENT);
#if DEBUG
        void *key = (__bridge void *)queue;
        dispatch_queue_set_specific(queue, key, key, NULL);
#endif
        queue;
    });
    _userInteractQueue = dispatch_get_main_queue();
    _serviceConsumer = [[LCRTMServiceConsumer alloc] initWithApplication:[AVApplication defaultApplication]
                                                                 service:LCRTMServiceInstantMessaging
                                                                protocol:[AVIMClient IMProtocol]
                                                                  peerID:_clientId];
    NSError *error;
    _connection = [[LCRTMConnectionManager sharedManager] registerWithServiceConsumer:_serviceConsumer
                                                                                error:&error];
    if (error) {
        return error;
    }
    _connectionDelegator = [[LCRTMConnectionDelegator alloc] initWithPeerID:_clientId
                                                                   delegate:self
                                                                      queue:_internalSerialQueue];
    _conversationManager = [[AVIMClientInternalConversationManager alloc] initWithClient:self];
    _installation = installation;
    _currentDeviceToken = installation.deviceToken;
    [installation addObserver:self
                   forKeyPath:keyPath(installation, deviceToken)
                      options:(NSKeyValueObservingOptionNew |
                               NSKeyValueObservingOptionOld |
                               NSKeyValueObservingOptionInitial)
                      context:(__bridge void *)(self)];
    _conversationCache = ({
        LCIMConversationCache *cache = [[LCIMConversationCache alloc] initWithClientId:_clientId];
        cache.client = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [cache cleanAllExpiredConversations];
        });
        cache;
    });
    return nil;
}

- (void)dealloc
{
    AVLoggerInfo(AVLoggerDomainIM,
                 @"\n%@: %p"
                 @"\n\t- dealloc",
                 NSStringFromClass([self class]), self);
    AVInstallation *installation = self.installation;
    [installation removeObserver:self
                      forKeyPath:keyPath(installation, deviceToken)
                         context:(__bridge void *)(self)];
    [self.connection removeDelegatorWithServiceConsumer:self.serviceConsumer];
    [[LCRTMConnectionManager sharedManager] unregisterWithServiceConsumer:self.serviceConsumer];
}

// MARK: Queue

- (void)addOperationToInternalSerialQueue:(void (^)(AVIMClient *client))block
{
    dispatch_async(self.internalSerialQueue, ^{
        block(self);
    });
}

- (void)invokeInUserInteractQueue:(void (^)(void))block
{
    dispatch_async(self.userInteractQueue, ^{
        block();
    });
}

- (void)invokeDelegateInUserInteractQueue:(void (^)(id<AVIMClientDelegate> delegate))block
{
    dispatch_async(self.userInteractQueue, ^{
        block(self.delegate);
    });
}

// MARK: Status

- (AVIMClientStatus)status
{
    AVIMClientStatus value;
    [self.lock lock];
    value = _status;
    [self.lock unlock];
    return value;
}

- (void)setStatus:(AVIMClientStatus)status
{
    [self.lock lock];
    _status = status;
    [self.lock unlock];
}

// MARK: Open & Close

- (void)openWithCallback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self openWithOption:AVIMClientOpenOptionForceOpen
                callback:callback];
}

- (void)openWithOption:(AVIMClientOpenOption)openOption
              callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    dispatch_async(self.internalSerialQueue, ^{
        if (self.openingCompletion || self.sessionToken) {
            if (self.openingCompletion) {
                [self invokeInUserInteractQueue:^{
                    callback(false,
                             LCError(AVErrorInternalErrorCodeInconsistency,
                                     @"In opening, cannot do repetitive operation.", nil));
                }];
            } else {
                [self invokeInUserInteractQueue:^{
                    callback(false,
                             LCError(AVErrorInternalErrorCodeInconsistency,
                                     @"Did opened, cannot do repetitive operation.", nil));
                }];
            }
            return;
        }
        self.openingCompletion = callback;
        self.openingOption = openOption;
        [self setStatus:AVIMClientStatusOpening];
        self.connectionDelegator.delegate = self;
        [self.connection connectWithServiceConsumer:self.serviceConsumer
                                          delegator:self.connectionDelegator];
    });
}

- (void)closeWithCallback:(void (^)(BOOL, NSError * _Nullable))callback
{
    LCIMProtobufCommandWrapper *commandWrapper = ({
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        outCommand.cmd = AVIMCommandType_Session;
        outCommand.op = AVIMOpType_Close;
        AVIMSessionCommand *sessionCommand = [AVIMSessionCommand new];
        outCommand.sessionMessage = sessionCommand;
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    [commandWrapper setCallback:^(AVIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error);
            }];
            return;
        }
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        if (inCommand.cmd == AVIMCommandType_Session &&
            inCommand.op == AVIMOpType_Closed) {
            [client sessionClosedWithSuccess:true
                                       error:nil
                                  completion:callback];
        } else {
            [client invokeInUserInteractQueue:^{
                callback(false, LCError(AVIMErrorCodeInvalidCommand,
                                        @"Invalid command.", nil));
            }];
        }
    }];
    [self sendCommandWrapper:commandWrapper];
}

// MARK: Session

- (void)getOpenSignatureWithToken:(NSString *)token
                       completion:(void (^)(AVIMClient *client, AVIMSignature *signature))completion
{
    NSParameterAssert(token);
    NSString *path = @"/rtm/sign";
    AVPaasClient *paasClient = [AVPaasClient sharedInstance];
    NSURLRequest *request = [paasClient requestWithPath:path
                                                 method:@"POST"
                                                headers:nil
                                             parameters:@{ @"session_token": token }];
    AVIMSignature *signature = [AVIMSignature new];
    __weak typeof(self) ws = self;
    [paasClient performRequest:request
                       success:^(NSHTTPURLResponse *response, id result) {
        AVIMClient *ss = ws;
        if (!ss) {
            return;
        }
        if ([NSDictionary _lc_isTypeOf:result]) {
            NSString *sign = [NSString _lc_decoding:result
                                                key:@"signature"];
            int64_t timestamp = [[NSNumber _lc_decoding:result
                                                    key:@"timestamp"] longLongValue];
            NSString *nonce = [NSString _lc_decoding:result
                                                 key:@"nonce"];
            if (sign &&
                timestamp > 0 &&
                nonce) {
                signature.signature = sign;
                signature.timestamp = timestamp;
                signature.nonce = nonce;
                [ss addOperationToInternalSerialQueue:^(AVIMClient *client) {
                    completion(client, signature);
                }];
                return;
            }
        }
        signature.error = LCError(AVErrorInternalErrorCodeMalformedData,
                                  [NSString stringWithFormat:
                                   @"Malformed response data, path: %@, data: %@",
                                   path, result ?: @"nil"],
                                  nil);
        [ss addOperationToInternalSerialQueue:^(AVIMClient *client) {
            completion(client, signature);
        }];
    } failure:^(NSHTTPURLResponse *response, id result, NSError *error) {
        AVIMClient *ss = ws;
        if (!ss) {
            return;
        }
        signature.error = error;
        [ss addOperationToInternalSerialQueue:^(AVIMClient *client) {
            completion(client, signature);
        }];
    }];
}

- (AVIMGenericCommand *)newSessionCommandWithOp:(AVIMOpType)op
                                          token:(NSString * _Nullable)token
                                      signature:(AVIMSignature * _Nullable)signature
                                       isReopen:(BOOL)isReopen
{
    AssertRunInQueue(self.internalSerialQueue);
    AVIMGenericCommand *command = [AVIMGenericCommand new];
    command.cmd = AVIMCommandType_Session;
    command.op = op;
    AVIMSessionCommand *sessionCommand = [AVIMSessionCommand new];
    if (op == AVIMOpType_Open) {
        command.appId = [self.serviceConsumer.application identifierThrowException];
        command.peerId = self.clientId;
        sessionCommand.configBitmap = self.sessionConfigBitmap;
        sessionCommand.deviceToken = (self.currentDeviceToken
                                      ?: AVUtils.deviceUUID);
        sessionCommand.ua = USER_AGENT;
        if (self.tag) {
            sessionCommand.tag = self.tag;
        }
        if (isReopen) {
            sessionCommand.r = true;
        }
        if (self.lastUnreadNotifTime > 0) {
            sessionCommand.lastUnreadNotifTime = self.lastUnreadNotifTime;
        }
        if (self.lastPatchTime > 0) {
            sessionCommand.lastPatchTime = self.lastPatchTime;
        }
        if (token) {
            sessionCommand.st = token;
        }
        if (signature) {
            sessionCommand.s = signature.signature;
            sessionCommand.t = signature.timestamp;
            sessionCommand.n = signature.nonce;
        }
    } else if (op == AVIMOpType_Refresh) {
        NSParameterAssert(token);
        sessionCommand.st = token;
    } else {
        [NSException raise:NSInternalInconsistencyException
                    format:@"should never happen."];
    }
    command.sessionMessage = sessionCommand;
    return command;
}

- (void)getSessionOpenCommandWithToken:(NSString * _Nullable)token
                              isReopen:(BOOL)isReopen
                            completion:(void (^)(AVIMClient *client, AVIMGenericCommand *openCommand))completion
{
    AssertRunInQueue(self.internalSerialQueue);
    if (token) {
        completion(self,
                   [self newSessionCommandWithOp:AVIMOpType_Open
                                           token:token
                                       signature:nil
                                        isReopen:isReopen]);
    } else if (self.user.sessionToken) {
        [self getOpenSignatureWithToken:self.user.sessionToken
                             completion:^(AVIMClient *client, AVIMSignature *signature) {
            AssertRunInQueue(client.internalSerialQueue);
            if (signature.error) {
                [client sessionClosedWithSuccess:false
                                           error:signature.error
                                      completion:client.openingCompletion];
            } else {
                completion(client,
                           [client newSessionCommandWithOp:AVIMOpType_Open
                                                     token:nil
                                                 signature:signature
                                                  isReopen:isReopen]);
            }
        }];
    } else if (self.signatureDataSource) {
        [self getSignatureWithConversationId:nil
                                      action:AVIMSignatureActionOpen
                           actionOnClientIds:nil
                                    callback:^(AVIMSignature *signature) {
            AssertRunInQueue(self.internalSerialQueue);
            if (signature.error) {
                [self sessionClosedWithSuccess:false
                                         error:signature.error
                                    completion:self.openingCompletion];
            } else {
                completion(self,
                           [self newSessionCommandWithOp:AVIMOpType_Open
                                                   token:nil
                                               signature:signature
                                                isReopen:isReopen]);
            }
        }];
    } else {
        completion(self,
                   [self newSessionCommandWithOp:AVIMOpType_Open
                                           token:nil
                                       signature:nil
                                        isReopen:isReopen]);
    }
}

- (void)handleSessionOpenCallbackWithInCommand:(AVIMGenericCommand *)inCommand
                                   openCommand:(AVIMGenericCommand * _Nullable)openCommand
                                    completion:(void (^ _Nullable)(BOOL, NSError *))openingCompletion
{
    AssertRunInQueue(self.internalSerialQueue);
    if (inCommand.cmd == AVIMCommandType_Session &&
        inCommand.op == AVIMOpType_Opened) {
        self.openingCompletion = nil;
        AVIMSessionCommand *sessionCommand = (inCommand.hasSessionMessage ? inCommand.sessionMessage : nil);
        if (sessionCommand.hasSt) {
            self.sessionToken = sessionCommand.st;
        }
        if (sessionCommand.hasStTtl) {
            self.sessionTokenExpiration = [NSDate dateWithTimeIntervalSinceNow:sessionCommand.stTtl];
        }
        [self setStatus:AVIMClientStatusOpened];
        if (openCommand) {
            [self reportDeviceToken:self.currentDeviceToken
                        openCommand:openCommand];
        }
        if (openingCompletion) {
            [self invokeInUserInteractQueue:^{
                openingCompletion(true, nil);
            }];
        } else {
            [self invokeDelegateInUserInteractQueue:^(id<AVIMClientDelegate> delegate) {
                if ([delegate respondsToSelector:@selector(imClientResumed:)]) {
                    [delegate imClientResumed:self];
                }
            }];
        }
    } else if (inCommand.cmd == AVIMCommandType_Session &&
               inCommand.op == AVIMOpType_Closed) {
        NSError *error = LCErrorFromSessionCommand((inCommand.hasSessionMessage
                                                    ? inCommand.sessionMessage
                                                    : nil));
        [self sessionClosedWithSuccess:false
                                 error:error
                            completion:openingCompletion];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self invokeDelegateInUserInteractQueue:^(id<AVIMClientDelegate> delegate) {
            if ([delegate respondsToSelector:@selector(client:didOfflineWithError:)]) {
                [delegate client:self didOfflineWithError:error];
            }
        }];
#pragma clang diagnostic pop
    } else {
        [self sessionClosedWithSuccess:false
                                 error:LCError(AVIMErrorCodeInvalidCommand,
                                               @"Invalid command.", nil)
                            completion:openingCompletion];
    }
}

- (void)sessionClosedWithSuccess:(BOOL)success
                           error:(NSError * _Nullable)error
                      completion:(void (^ _Nullable)(BOOL, NSError *))completion
{
    AssertRunInQueue(self.internalSerialQueue);
    self.connectionDelegator.delegate = nil;
    [self.connection removeDelegatorWithServiceConsumer:self.serviceConsumer];
    self.sessionToken = nil;
    self.sessionTokenExpiration = nil;
    self.openingCompletion = nil;
    [self setStatus:AVIMClientStatusClosed];
    if (completion) {
        [self invokeInUserInteractQueue:^{
            completion(success, error);
        }];
    } else {
        [self invokeDelegateInUserInteractQueue:^(id<AVIMClientDelegate> delegate) {
            if ([delegate respondsToSelector:@selector(imClientClosed:error:)]) {
                [delegate imClientClosed:self error:error];
            }
        }];
    }
}

- (void)sendSessionReopenCommand:(AVIMGenericCommand *)command
{
    AssertRunInQueue(self.internalSerialQueue);
    __weak typeof(self) ws = self;
    [self.connection sendCommand:command
                         service:LCRTMServiceInstantMessaging
                          peerID:self.clientId
                         onQueue:self.internalSerialQueue
                        callback:^(AVIMGenericCommand * _Nullable inCommand, NSError * _Nullable error) {
        AVIMClient *client = ws;
        if (!client) {
            return;
        }
        AssertRunInQueue(client.internalSerialQueue);
        if (error) {
            if ([error.domain isEqualToString:kLeanCloudErrorDomain]) {
                if (error.code == AVIMErrorCodeCommandTimeout) {
                    [client sendSessionReopenCommand:command];
                } else if (error.code == AVIMErrorCodeConnectionLost) {
                    AVLoggerError(AVLoggerDomainIM, @"%@", error);
                } else if (error.code == AVIMErrorCodeSessionTokenExpired) {
                    [client getSessionOpenCommandWithToken:nil
                                                  isReopen:true
                                                completion:^(AVIMClient *client, AVIMGenericCommand *openCommand) {
                        [client sendSessionReopenCommand:openCommand];
                    }];
                } else {
                    [client sessionClosedWithSuccess:false
                                               error:error
                                          completion:nil];
                }
            } else {
                AVLoggerError(AVLoggerDomainIM, @"%@", error);
            }
        } else {
            [client handleSessionOpenCallbackWithInCommand:inCommand
                                               openCommand:nil
                                                completion:nil];
        }
    }];
}

- (void)getSessionTokenWithForcingRefresh:(BOOL)forcingRefresh
                                 callback:(void (^)(NSString *, NSError *))callback
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        NSString *oldSessionToken = client.sessionToken;
        if (!oldSessionToken ||
            [client status] != AVIMClientStatusOpened) {
            callback(nil, LCError(AVIMErrorCodeClientNotOpen,
                                  @"Client not open", nil));
            return;
        }
        if (forcingRefresh ||
            !client.sessionTokenExpiration ||
            [client.sessionTokenExpiration compare:[NSDate date]] == NSOrderedAscending) {
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = [client newSessionCommandWithOp:AVIMOpType_Refresh
                                                                  token:oldSessionToken
                                                              signature:nil
                                                               isReopen:false];
            [commandWrapper setCallback:^(AVIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
                if (commandWrapper.error) {
                    callback(nil, commandWrapper.error);
                    return;
                }
                if (!client.sessionToken) {
                    callback(nil, LCError(AVIMErrorCodeClientNotOpen,
                                          @"Client not open", nil));
                    return;
                }
                AVIMGenericCommand *inCommand = commandWrapper.inCommand;
                AVIMSessionCommand *sessionCommand = (inCommand.hasSessionMessage ? inCommand.sessionMessage : nil);
                if (sessionCommand.hasSt) {
                    client.sessionToken = sessionCommand.st;
                }
                if (sessionCommand.hasStTtl) {
                    client.sessionTokenExpiration = [NSDate dateWithTimeIntervalSinceNow:sessionCommand.stTtl];
                }
                callback(client.sessionToken, nil);
            }];
            [client sendCommandWrapper:commandWrapper];
        } else {
            callback(oldSessionToken, nil);
        }
    }];
}

// MARK: Signature

- (void)getSignatureWithConversationId:(NSString *)conversationId
                                action:(AVIMSignatureAction)action
                     actionOnClientIds:(NSArray<NSString *> *)actionOnClientIds
                              callback:(void (^)(AVIMSignature *))callback
{
    dispatch_async(self.signatureQueue, ^{
        AVIMSignature *signature;
        id<AVIMSignatureDataSource> dataSource = self.signatureDataSource;
        if ([dataSource respondsToSelector:@selector(signatureWithClientId:conversationId:action:actionOnClientIds:)]) {
            signature = [dataSource signatureWithClientId:self.clientId
                                           conversationId:conversationId
                                                   action:action
                                        actionOnClientIds:actionOnClientIds];
        }
        [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
            callback(signature);
        }];
    });
}

// MARK: Send Command

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
        if ([client status] != AVIMClientStatusOpened) {
            if (commandWrapper.callback) {
                commandWrapper.error = LCError(AVIMErrorCodeClientNotOpen,
                                               @"Client not open.", nil);
                commandWrapper.callback(client, commandWrapper);
                commandWrapper.callback = nil;
            }
            return;
        }
        if (commandWrapper.callback) {
            __weak typeof(client) wClient = client;
            [client.connection sendCommand:commandWrapper.outCommand
                                   service:LCRTMServiceInstantMessaging
                                    peerID:client.clientId
                                   onQueue:client.internalSerialQueue
                                  callback:^(AVIMGenericCommand * _Nullable inCommand, NSError * _Nullable error) {
                AVIMClient *sClient = wClient;
                if (!sClient) {
                    return;
                }
                AssertRunInQueue(sClient.internalSerialQueue);
                commandWrapper.inCommand = inCommand;
                commandWrapper.error = error;
                commandWrapper.callback(sClient, commandWrapper);
                commandWrapper.callback = nil;
            }];
        } else {
            [client.connection sendCommand:commandWrapper.outCommand
                                   service:LCRTMServiceInstantMessaging
                                    peerID:client.clientId
                                   onQueue:client.internalSerialQueue
                                  callback:nil];
        }
    }];
}

// MARK: LCRTMConnection Delegate

- (void)LCRTMConnection:(LCRTMConnection *)connection didReceiveCommand:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self.internalSerialQueue);
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
                    [self process_session_closed:inCommand];
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
                    [self process_conv_joined:inCommand];
                } break;
                case AVIMOpType_MembersJoined:
                {
                    [self process_conv_members_joined:inCommand];
                } break;
                case AVIMOpType_Left:
                {
                    [self process_conv_left:inCommand];
                } break;
                case AVIMOpType_MembersLeft:
                {
                    [self process_conv_members_left:inCommand];
                } break;
                case AVIMOpType_Updated:
                {
                    [self process_conv_updated:inCommand];
                } break;
                case AVIMOpType_MemberInfoChanged:
                {
                    [self process_conv_member_info_changed:inCommand];
                } break;
                case AVIMOpType_Blocked:
                {
                    [self process_conv_blocked:inCommand];
                } break;
                case AVIMOpType_MembersBlocked:
                {
                    [self process_conv_members_blocked:inCommand];
                } break;
                case AVIMOpType_Unblocked:
                {
                    [self process_conv_unblocked:inCommand];
                } break;
                case AVIMOpType_MembersUnblocked:
                {
                    [self process_conv_members_unblocked:inCommand];
                } break;
                case AVIMOpType_Shutuped:
                {
                    [self process_conv_shutuped:inCommand];
                } break;
                case AVIMOpType_MembersShutuped:
                {
                    [self process_conv_members_shutuped:inCommand];
                } break;
                case AVIMOpType_Unshutuped:
                {
                    [self process_conv_unshutuped:inCommand];
                } break;
                case AVIMOpType_MembersUnshutuped:
                {
                    [self process_conv_members_unshutuped:inCommand];
                } break;
                default: break;
            }
        } break;
        case AVIMCommandType_Direct:
        {
            [self process_direct:inCommand];
        } break;
        case AVIMCommandType_Rcp:
        {
            [self process_rcp:inCommand];
        } break;
        case AVIMCommandType_Unread:
        {
            [self process_unread:inCommand];
        } break;
        case AVIMCommandType_Patch:
        {
            switch (opType)
            {
                case AVIMOpType_Modify:
                {
                    [self process_patch_modify:inCommand];
                } break;
                default: break;
            }
        } break;
        default: break;
    }
}

- (void)LCRTMConnectionDidConnect:(LCRTMConnection *)connection
{
    AssertRunInQueue(self.internalSerialQueue);
    if (self.openingCompletion) {
        [self getSessionOpenCommandWithToken:nil
                                    isReopen:(self.openingOption == AVIMClientOpenOptionReopen)
                                  completion:^(AVIMClient *client, AVIMGenericCommand *openCommand) {
            AssertRunInQueue(client.internalSerialQueue);
            __weak typeof(client) wClient = client;
            [client.connection sendCommand:openCommand
                                   service:LCRTMServiceInstantMessaging
                                    peerID:client.clientId
                                   onQueue:client.internalSerialQueue
                                  callback:^(AVIMGenericCommand * _Nullable inCommand, NSError * _Nullable error) {
                AVIMClient *sClient = wClient;
                if (!sClient) {
                    return;
                }
                AssertRunInQueue(sClient.internalSerialQueue);
                if (error) {
                    [sClient sessionClosedWithSuccess:false
                                                error:error
                                           completion:sClient.openingCompletion];
                } else {
                    [sClient handleSessionOpenCallbackWithInCommand:inCommand
                                                        openCommand:openCommand
                                                         completion:sClient.openingCompletion];
                }
            }];
        }];
    } else if (self.sessionToken) {
        BOOL isExpired = false;
        if (!self.sessionTokenExpiration ||
            [self.sessionTokenExpiration compare:[NSDate date]] == NSOrderedAscending) {
            isExpired = true;
        }
        [self getSessionOpenCommandWithToken:(isExpired ? nil : self.sessionToken)
                                    isReopen:true
                                  completion:^(AVIMClient *client, AVIMGenericCommand *openCommand) {
            AssertRunInQueue(client.internalSerialQueue);
            [client sendSessionReopenCommand:openCommand];
        }];
    }
}

- (void)LCRTMConnectionInConnecting:(LCRTMConnection *)connection
{
    AssertRunInQueue(self.internalSerialQueue);
    if (!self.sessionToken ||
        [self status] == AVIMClientStatusResuming) {
        return;
    }
    [self setStatus:AVIMClientStatusResuming];
    [self invokeDelegateInUserInteractQueue:^(id<AVIMClientDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(imClientResuming:)]) {
            [delegate imClientResuming:self];
        }
    }];
}

- (void)LCRTMConnection:(LCRTMConnection *)connection didDisconnectWithError:(NSError *)error
{
    AssertRunInQueue(self.internalSerialQueue);
    if (self.openingCompletion) {
        [self sessionClosedWithSuccess:false
                                 error:error
                            completion:self.openingCompletion];
    } else if (self.sessionToken ||
               [self status] != AVIMClientStatusPaused) {
        [self setStatus:AVIMClientStatusPaused];
        [self invokeDelegateInUserInteractQueue:^(id<AVIMClientDelegate> delegate) {
            if ([delegate respondsToSelector:@selector(imClientPaused:error:)]) {
                [delegate imClientPaused:self error:error];
            }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            if ([delegate respondsToSelector:@selector(imClientPaused:)]) {
                [delegate imClientPaused:self];
            }
#pragma clang diagnostic pop
        }];
    }
}

// MARK: Process Command

- (void)process_session_closed:(AVIMGenericCommand *)inCommand
{
    NSError *error = LCErrorFromSessionCommand((inCommand.hasSessionMessage
                                                ? inCommand.sessionMessage
                                                : nil));
    [self sessionClosedWithSuccess:false
                             error:error
                        completion:nil];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self invokeDelegateInUserInteractQueue:^(id<AVIMClientDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(client:didOfflineWithError:)]) {
            [delegate client:self didOfflineWithError:error];
        }
    }];
#pragma clang diagnostic pop
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
        if (error || ![NSDictionary _lc_isTypeOf:attr]) {
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
        if (error || ![NSDictionary _lc_isTypeOf:attrModified]) {
            return;
        }
        attrModified;
    });
    
    NSString *initById = (convCommand.hasInitBy ? convCommand.initBy : nil);
    NSDate *updatedAt;
    if (convCommand.hasUdate) {
        updatedAt = [AVDate dateFromString:convCommand.udate];
    }
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation process_conv_updated_attr:attr attrModified:attrModified];
        id <AVIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:didUpdateAt:byClientId:updatedData:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didUpdateAt:updatedAt byClientId:initById updatedData:attrModified];
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
            if (patchItem.hasPatchTimestamp && patchItem.patchTimestamp > self.lastPatchTime) {
                self.lastPatchTime = patchItem.patchTimestamp;
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
            patchMessage.lastPatchTime = self.lastPatchTime;
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
    if (notifTime > self.lastUnreadNotifTime) {
        self.lastUnreadNotifTime = notifTime;
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
            if ([message isKindOfClass:[AVIMTypedMessage class]] && [delegate respondsToSelector:selType]) {
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

// MARK: Conversation Create

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
                callback(nil, LCErrorInternal([NSString stringWithFormat:@"client id's length should in range [1 %lu].", (unsigned long)kClientIdLengthLimit]));
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
        
        [commandWrapper setCallback:^(AVIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                [client invokeInUserInteractQueue:^{
                    callback(nil, commandWrapper.error);
                }];
                return;
            }
            
            AVIMGenericCommand *inCommand = commandWrapper.inCommand;
            AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
            NSString *conversationId = (convCommand.hasCid ? convCommand.cid : nil);
            if (!conversationId) {
                [client invokeInUserInteractQueue:^{
                    callback(nil, ({
                        AVIMErrorCode code = AVIMErrorCodeInvalidCommand;
                        LCError(code, AVIMErrorMessage(code), nil);
                    }));
                }];
                return;
            }
            
            AVIMConversation *conversation = ({
                AVIMConversation *conversation = [client.conversationManager conversationForId:conversationId];
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
                        mutableDic[AVIMConversationKeyCreator] = client.clientId;
                        mutableDic[AVIMConversationKeyMembers] = members;
                        mutableDic[AVIMConversationKeyObjectId] = conversationId;
                        mutableDic;
                    });
                    conversation = [AVIMConversation conversationWithRawJSONData:mutableDic client:client];
                    if (conversation) {
                        [client.conversationManager insertConversation:conversation];
                    }
                }
                conversation;
            });
            
            [client invokeInUserInteractQueue:^{
                callback(conversation, nil);
            }];
        }];
        
        [self sendCommandWrapper:commandWrapper];
    }];
}

// MARK: Conversations Instance

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

// MARK: Device Token

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        if ([keyPath isEqualToString:keyPath(self.installation, deviceToken)] &&
            object == self.installation) {
            NSString *oldToken = [NSString _lc_decoding:change key:NSKeyValueChangeOldKey];
            NSString *newToken = [NSString _lc_decoding:change key:NSKeyValueChangeNewKey];
            if (newToken &&
                ![newToken isEqualToString:oldToken]) {
                [self addOperationToInternalSerialQueue:^(AVIMClient *client) {
                    if (![client.currentDeviceToken isEqualToString:newToken]) {
                        client.currentDeviceToken = newToken;
                        [client reportDeviceToken:newToken
                                      openCommand:nil];
                    }
                }];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)reportDeviceToken:(NSString *)token
              openCommand:(AVIMGenericCommand *)openCommand
{
    AssertRunInQueue(self.internalSerialQueue);
    if (!token ||
        (openCommand.hasSessionMessage &&
         openCommand.sessionMessage.hasDeviceToken &&
         [openCommand.sessionMessage.deviceToken isEqualToString:token]) ||
        [self status] != AVIMClientStatusOpened) {
        return;
    }
    AVIMGenericCommand *command = [AVIMGenericCommand new];
    command.cmd = AVIMCommandType_Report;
    command.op = AVIMOpType_Upload;
    AVIMReportCommand *reportCommand = [AVIMReportCommand new];
    reportCommand.initiative = true;
    reportCommand.type = @"token";
    reportCommand.data_p = token;
    command.reportMessage = reportCommand;
    LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
    commandWrapper.outCommand = command;
#if DEBUG
    [commandWrapper setCallback:^(AVIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        if (commandWrapper.error) {
            AVLoggerError(AVLoggerDomainIM, @"%@", commandWrapper.error);
        }
        [NSNotificationCenter.defaultCenter postNotificationName:@"Test.AVIMClient.reportDeviceToken"
                                                          object:nil
                                                        userInfo:(commandWrapper.error
                                                                  ? @{ @"error": commandWrapper.error }
                                                                  : nil)];
    }];
#endif
    [self sendCommandWrapper:commandWrapper];
}

// MARK: Misc

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
                callback(nil, LCErrorInternal([NSString stringWithFormat:@"clients count beyond max %lu", (unsigned long)clientsCountMax]));
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
    
    [commandWrapper setCallback:^(AVIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(nil, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMSessionCommand *sessionCommand = (inCommand.hasSessionMessage ? inCommand.sessionMessage : nil);
        if (!sessionCommand) {
            [client invokeInUserInteractQueue:^{
                callback(nil, ({
                    AVIMErrorCode code = AVIMErrorCodeInvalidCommand;
                    LCError(code, AVIMErrorMessage(code), nil);
                }));
            }];
            return;
        }
        
        [client invokeInUserInteractQueue:^{
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
        conversationId = [NSString _lc_decoding:rawDataDic key:AVIMConversationKeyObjectId];
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
            rawDataDic[AVIMConversationKeyCreatedAt] = [AVDate stringFromDate:keyedConversation.createAt];
        }
        if (keyedConversation.updateAt) {
            rawDataDic[AVIMConversationKeyUpdatedAt] = [AVDate stringFromDate:keyedConversation.updateAt];
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

// MARK: IM Protocol Options

+ (LCIMProtocol)IMProtocol
{
    NSNumber *useUnreadProtocol = [NSNumber _lc_decoding:AVIMClient.sessionProtocolOptions
                                                     key:kAVIMUserOptionUseUnread];
    if ([useUnreadProtocol boolValue]) {
        return LCIMProtocol3;
    } else {
        return LCIMProtocol1;
    }
}

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
    if (gClientHasInstantiated) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"This method should be invoked before initialization of `AVIMClient`."];
        return;
    }
    AVIMClient.sessionProtocolOptions[kAVIMUserOptionUseUnread] = @(enabled);
}

// MARK: Deprecated

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
+ (void)setUserOptions:(NSDictionary *)userOptions
{
    if (gClientHasInstantiated) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"This method should be invoked before initialization of `AVIMClient`."];
        return;
    }
    if (!userOptions) {
        return;
    }
    [AVIMClient.sessionProtocolOptions addEntriesFromDictionary:userOptions];
}
#pragma clang diagnostic pop

@end

@implementation LCIMProtobufCommandWrapper {
    NSError *_error;
    BOOL _hasDecodedError;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _hasDecodedError = false;
    }
    return self;
}

- (void)setError:(NSError *)error
{
    _error = error;
}

- (NSError *)error
{
    if (_error) {
        return _error;
    } else if (self.inCommand && !_hasDecodedError) {
        _hasDecodedError = true;
        _error = [self decodingError:self.inCommand];
    }
    return _error;
}

- (NSError *)decodingError:(AVIMGenericCommand *)command
{
    NSError *error;
    if (command.hasErrorMessage) {
        error = LCErrorFromErrorCommand(command.errorMessage);
    } else if (command.hasSessionMessage) {
        error = LCErrorFromSessionCommand(command.sessionMessage);
    } else if (command.hasAckMessage) {
        error = LCErrorFromAckCommand(command.ackMessage);
    }
    return error;
}

@end
