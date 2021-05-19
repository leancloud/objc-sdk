//
//  LCIMClient.m
//  LeanCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMClient_Internal.h"
#import "LCIMConversation_Internal.h"
#import "LCIMKeyedConversation_internal.h"
#import "LCIMConversationMemberInfo_Internal.h"
#import "LCIMConversationQuery_Internal.h"
#import "LCIMTypedMessage_Internal.h"

#import "LCIMErrorUtil.h"

#import "UserAgent.h"
#import "LCObjectUtils.h"
#import "LCUtils.h"
#import "LCPaasClient.h"
#import "LCErrorUtils.h"

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

@implementation LCIMConversationCreationOption

- (instancetype)init {
    self = [super init];
    if (self) {
        _isUnique = true;
    }
    return self;
}

@end

@implementation LCIMClient {
    LCIMClientStatus _status;
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
                           error:(NSError *__autoreleasing  _Nullable *)error
{
    return [self initWithClientId:clientId
                              tag:nil
                            error:error];
}

- (instancetype)initWithClientId:(NSString *)clientId
                             tag:(NSString *)tag
                           error:(NSError *__autoreleasing  _Nullable *)error
{
    return [self initWithClientId:clientId
                              tag:tag
                     installation:[LCInstallation defaultInstallation]
                            error:error];
}

- (instancetype)initWithUser:(LCUser *)user
                       error:(NSError *__autoreleasing  _Nullable *)error
{
    return [self initWithUser:user
                          tag:nil
                        error:error];
}

- (instancetype)initWithUser:(LCUser *)user
                         tag:(NSString *)tag
                       error:(NSError *__autoreleasing  _Nullable *)error
{
    return [self initWithUser:user
                          tag:tag
                 installation:[LCInstallation defaultInstallation]
                        error:error];
}

- (instancetype)initWithClientId:(NSString *)clientId
                             tag:(NSString *)tag
                    installation:(LCInstallation *)installation
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

- (instancetype)initWithUser:(LCUser *)user
                         tag:(NSString *)tag
                installation:(LCInstallation *)installation
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
                             installation:(LCInstallation *)installation
{
    if (!clientId ||
        clientId.length > kClientIdLengthLimit ||
        clientId.length == 0) {
        return LCError(LCErrorInternalErrorCodeInconsistency,
                       @"The length of `clientId` should in range `[1 64]`.", nil);
    }
    _clientId = clientId.copy;
    if ([tag isEqualToString:kClientTagDefault]) {
        return LCError(LCErrorInternalErrorCodeInconsistency,
                       @"The tag `%@` is reserved.", nil);
    }
    _tag = (tag ? tag.copy : nil);
    _messageQueryCacheEnabled = true;
    _sessionConfigBitmap = (LCIMSessionConfigOptionsPatchMessage
                            | LCIMSessionConfigOptionsTemporaryConversationMessage
                            | LCIMSessionConfigOptionsTransientMessageACK
                            | LCIMSessionConfigOptionsPartialFailedMessage
                            | LCIMSessionConfigOptionsOmitPeerID);
    _status = LCIMClientStatusNone;
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
    _serviceConsumer = [[LCRTMServiceConsumer alloc] initWithApplication:[LCApplication defaultApplication]
                                                                 service:LCRTMServiceInstantMessaging
                                                                protocol:[LCIMClient IMProtocol]
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
    _conversationManager = [[LCIMClientInternalConversationManager alloc] initWithClient:self];
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
    LCLoggerInfo(LCLoggerDomainIM,
                 @"\n%@: %p"
                 @"\n\t- dealloc",
                 NSStringFromClass([self class]), self);
    LCInstallation *installation = self.installation;
    [installation removeObserver:self
                      forKeyPath:keyPath(installation, deviceToken)
                         context:(__bridge void *)(self)];
    [self.connection removeDelegatorWithServiceConsumer:self.serviceConsumer];
    [[LCRTMConnectionManager sharedManager] unregisterWithServiceConsumer:self.serviceConsumer];
}

// MARK: Queue

- (void)addOperationToInternalSerialQueue:(void (^)(LCIMClient *client))block
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

- (void)invokeDelegateInUserInteractQueue:(void (^)(id<LCIMClientDelegate> delegate))block
{
    dispatch_async(self.userInteractQueue, ^{
        block(self.delegate);
    });
}

// MARK: Status

- (LCIMClientStatus)status
{
    LCIMClientStatus value;
    [self.lock lock];
    value = _status;
    [self.lock unlock];
    return value;
}

- (void)setStatus:(LCIMClientStatus)status
{
    [self.lock lock];
    _status = status;
    [self.lock unlock];
}

// MARK: Open & Close

- (void)openWithCallback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self openWithOption:LCIMClientOpenOptionForceOpen
                callback:callback];
}

- (void)openWithOption:(LCIMClientOpenOption)openOption
              callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    dispatch_async(self.internalSerialQueue, ^{
        if (self.openingCompletion || self.sessionToken) {
            if (self.openingCompletion) {
                [self invokeInUserInteractQueue:^{
                    callback(false,
                             LCError(LCErrorInternalErrorCodeInconsistency,
                                     @"In opening, cannot do repetitive operation.", nil));
                }];
            } else {
                [self invokeInUserInteractQueue:^{
                    callback(false,
                             LCError(LCErrorInternalErrorCodeInconsistency,
                                     @"Did opened, cannot do repetitive operation.", nil));
                }];
            }
            return;
        }
        self.openingCompletion = callback;
        self.openingOption = openOption;
        [self setStatus:LCIMClientStatusOpening];
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
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
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
                callback(false, LCError(LCIMErrorCodeInvalidCommand,
                                        @"Invalid command.", nil));
            }];
        }
    }];
    [self sendCommandWrapper:commandWrapper];
}

// MARK: Session

- (void)getOpenSignatureWithToken:(NSString *)token
                       completion:(void (^)(LCIMClient *client, LCIMSignature *signature))completion
{
    NSParameterAssert(token);
    NSString *path = @"/rtm/sign";
    LCPaasClient *paasClient = [LCPaasClient sharedInstance];
    NSURLRequest *request = [paasClient requestWithPath:path
                                                 method:@"POST"
                                                headers:nil
                                             parameters:@{ @"session_token": token }];
    LCIMSignature *signature = [LCIMSignature new];
    __weak typeof(self) ws = self;
    [paasClient performRequest:request
                       success:^(NSHTTPURLResponse *response, id result) {
        LCIMClient *ss = ws;
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
                [ss addOperationToInternalSerialQueue:^(LCIMClient *client) {
                    completion(client, signature);
                }];
                return;
            }
        }
        signature.error = LCError(LCErrorInternalErrorCodeMalformedData,
                                  [NSString stringWithFormat:
                                   @"Malformed response data, path: %@, data: %@",
                                   path, result ?: @"nil"],
                                  nil);
        [ss addOperationToInternalSerialQueue:^(LCIMClient *client) {
            completion(client, signature);
        }];
    } failure:^(NSHTTPURLResponse *response, id result, NSError *error) {
        LCIMClient *ss = ws;
        if (!ss) {
            return;
        }
        signature.error = error;
        [ss addOperationToInternalSerialQueue:^(LCIMClient *client) {
            completion(client, signature);
        }];
    }];
}

- (AVIMGenericCommand *)newSessionCommandWithOp:(AVIMOpType)op
                                          token:(NSString * _Nullable)token
                                      signature:(LCIMSignature * _Nullable)signature
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
                                      ?: LCUtils.deviceUUID);
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
                            completion:(void (^)(LCIMClient *client, AVIMGenericCommand *openCommand))completion
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
                             completion:^(LCIMClient *client, LCIMSignature *signature) {
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
                                      action:LCIMSignatureActionOpen
                           actionOnClientIds:nil
                                    callback:^(LCIMSignature *signature) {
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
        [self setStatus:LCIMClientStatusOpened];
        if (openCommand) {
            [self reportDeviceToken:self.currentDeviceToken
                        openCommand:openCommand];
        }
        if (openingCompletion) {
            [self invokeInUserInteractQueue:^{
                openingCompletion(true, nil);
            }];
        } else {
            [self invokeDelegateInUserInteractQueue:^(id<LCIMClientDelegate> delegate) {
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
    } else {
        [self sessionClosedWithSuccess:false
                                 error:LCError(LCIMErrorCodeInvalidCommand,
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
    [self setStatus:LCIMClientStatusClosed];
    if (completion) {
        [self invokeInUserInteractQueue:^{
            completion(success, error);
        }];
    } else {
        [self invokeDelegateInUserInteractQueue:^(id<LCIMClientDelegate> delegate) {
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
        LCIMClient *client = ws;
        if (!client) {
            return;
        }
        AssertRunInQueue(client.internalSerialQueue);
        if (error) {
            if ([error.domain isEqualToString:kLeanCloudErrorDomain]) {
                if (error.code == LCIMErrorCodeCommandTimeout) {
                    [client sendSessionReopenCommand:command];
                } else if (error.code == LCIMErrorCodeConnectionLost) {
                    LCLoggerError(LCLoggerDomainIM, @"%@", error);
                } else if (error.code == LCIMErrorCodeSessionTokenExpired) {
                    [client getSessionOpenCommandWithToken:nil
                                                  isReopen:true
                                                completion:^(LCIMClient *client, AVIMGenericCommand *openCommand) {
                        [client sendSessionReopenCommand:openCommand];
                    }];
                } else {
                    [client sessionClosedWithSuccess:false
                                               error:error
                                          completion:nil];
                }
            } else {
                LCLoggerError(LCLoggerDomainIM, @"%@", error);
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
    [self addOperationToInternalSerialQueue:^(LCIMClient *client) {
        NSString *oldSessionToken = client.sessionToken;
        if (!oldSessionToken ||
            [client status] != LCIMClientStatusOpened) {
            callback(nil, LCError(LCIMErrorCodeClientNotOpen,
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
            [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
                if (commandWrapper.error) {
                    callback(nil, commandWrapper.error);
                    return;
                }
                if (!client.sessionToken) {
                    callback(nil, LCError(LCIMErrorCodeClientNotOpen,
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
                                action:(LCIMSignatureAction)action
                     actionOnClientIds:(NSArray<NSString *> *)actionOnClientIds
                              callback:(void (^)(LCIMSignature *))callback
{
    dispatch_async(self.signatureQueue, ^{
        LCIMSignature *signature;
        id<LCIMSignatureDataSource> dataSource = self.signatureDataSource;
        if ([dataSource respondsToSelector:@selector(signatureWithClientId:conversationId:action:actionOnClientIds:)]) {
            signature = [dataSource signatureWithClientId:self.clientId
                                           conversationId:conversationId
                                                   action:action
                                        actionOnClientIds:actionOnClientIds];
        }
        [self addOperationToInternalSerialQueue:^(LCIMClient *client) {
            callback(signature);
        }];
    });
}

// MARK: Send Command

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueue:^(LCIMClient *client) {
        if ([client status] != LCIMClientStatusOpened) {
            if (commandWrapper.callback) {
                commandWrapper.error = LCError(LCIMErrorCodeClientNotOpen,
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
                LCIMClient *sClient = wClient;
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
            [self processDirect:inCommand];
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
                                    isReopen:(self.openingOption == LCIMClientOpenOptionReopen)
                                  completion:^(LCIMClient *client, AVIMGenericCommand *openCommand) {
            AssertRunInQueue(client.internalSerialQueue);
            __weak typeof(client) wClient = client;
            [client.connection sendCommand:openCommand
                                   service:LCRTMServiceInstantMessaging
                                    peerID:client.clientId
                                   onQueue:client.internalSerialQueue
                                  callback:^(AVIMGenericCommand * _Nullable inCommand, NSError * _Nullable error) {
                LCIMClient *sClient = wClient;
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
                                  completion:^(LCIMClient *client, AVIMGenericCommand *openCommand) {
            AssertRunInQueue(client.internalSerialQueue);
            [client sendSessionReopenCommand:openCommand];
        }];
    }
}

- (void)LCRTMConnectionInConnecting:(LCRTMConnection *)connection
{
    AssertRunInQueue(self.internalSerialQueue);
    if (!self.sessionToken ||
        [self status] == LCIMClientStatusResuming) {
        return;
    }
    [self setStatus:LCIMClientStatusResuming];
    [self invokeDelegateInUserInteractQueue:^(id<LCIMClientDelegate> delegate) {
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
               [self status] != LCIMClientStatusPaused) {
        [self setStatus:LCIMClientStatusPaused];
        [self invokeDelegateInUserInteractQueue:^(id<LCIMClientDelegate> delegate) {
            if ([delegate respondsToSelector:@selector(imClientPaused:error:)]) {
                [delegate imClientPaused:self error:error];
            }
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation addMembers:@[self->_clientId]];
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation addMembers:memberIds];
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation removeMembers:@[self->_clientId]];
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation removeMembers:memberIds];
        id <LCIMClientDelegate> delegate = self->_delegate;
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
        updatedAt = [LCDate dateFromString:convCommand.udate];
    }
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation process_conv_updated_attr:attr attrModified:attrModified];
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        [conversation process_member_info_changed:memberId role:roleKey];
        id <LCIMClientDelegate> delegate = self->_delegate;
        SEL sel = @selector(conversation:didMemberInfoUpdateBy:memberId:role:);
        if (delegate && [delegate respondsToSelector:sel]) {
            [self invokeInUserInteractQueue:^{
                LCIMConversationMemberRole role = LCIMConversationMemberInfo_key_to_role(roleKey);
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationsWithIds:conversationIds callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        AVIMPatchItem *patchItem = patchItemMap[conversation.conversationId];
        LCIMMessage *patchMessage = [conversation process_patch_modified:patchItem];
        id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationWithId:conversationId callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        LCIMMessage *message = [conversation process_rcp:rcpCommand isReadRcp:isReadRcp];
        if (!isReadRcp && message) {
            id <LCIMClientDelegate> delegate = self->_delegate;
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
    
    [self->_conversationManager queryConversationsWithIds:conversationIds callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) { return; }
        AVIMUnreadTuple *unreadTuple = unreadTupleMap[conversation.conversationId];
        __unused NSInteger unreadCount = [conversation process_unread:unreadTuple];
    }];
}

- (void)processDirect:(AVIMGenericCommand *)inCommand
{
    AssertRunInQueue(self.internalSerialQueue);
    AVIMDirectCommand *directCommand = (inCommand.hasDirectMessage ? inCommand.directMessage : nil);
    NSString *conversationID = (directCommand.hasCid ? directCommand.cid : nil);
    NSString *messageID = (directCommand.hasId_p ? directCommand.id_p : nil);
    if (!conversationID ||
        !messageID) {
        return;
    }
    [self.conversationManager queryConversationWithId:conversationID callback:^(LCIMConversation *conversation, NSError *error) {
        if (error) {
            LCLoggerError(LCLoggerDomainIM, @"%@", error);
            return;
        }
        BOOL isTransientMsg = (directCommand.hasTransient ? directCommand.transient : false);
        if ((conversation.convType != LCIMConvTypeTransient) &&
            !isTransientMsg) {
            LCIMProtobufCommandWrapper *ackCommandWrapper = ({
                AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
                AVIMAckCommand *ackCommand = [AVIMAckCommand new];
                outCommand.cmd = AVIMCommandType_Ack;
                outCommand.ackMessage = ackCommand;
                ackCommand.cid = conversationID;
                ackCommand.mid = messageID;
                LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
                commandWrapper.outCommand = outCommand;
                commandWrapper;
            });
            [self sendCommandWrapper:ackCommandWrapper];
        }
        LCIMMessage *message = [conversation process_direct:directCommand
                                                  messageId:messageID
                                             isTransientMsg:isTransientMsg];
        id <LCIMClientDelegate> delegate = self.delegate;
        if (message && delegate) {
            SEL selType = @selector(conversation:didReceiveTypedMessage:);
            SEL selCommon = @selector(conversation:didReceiveCommonMessage:);
            if ([message isKindOfClass:[LCIMTypedMessage class]] &&
                [delegate respondsToSelector:selType]) {
                [self invokeInUserInteractQueue:^{
                    [delegate conversation:conversation didReceiveTypedMessage:(LCIMTypedMessage *)message];
                }];
            } else if ([message isKindOfClass:[LCIMMessage class]] &&
                       [delegate respondsToSelector:selCommon]) {
                [self invokeInUserInteractQueue:^{
                    [delegate conversation:conversation didReceiveCommonMessage:message];
                }];
            }
        }
    }];
}

// MARK: Conversation Create

- (void)createConversationWithClientIds:(NSArray<NSString *> *)clientIds
                               callback:(void (^)(LCIMConversation * _Nullable, NSError * _Nullable))callback
{
    [self createConversationWithClientIds:clientIds option:nil callback:callback];
}

- (void)createConversationWithClientIds:(NSArray<NSString *> *)clientIds
                                 option:(LCIMConversationCreationOption *)option
                               callback:(void (^)(LCIMConversation * _Nullable, NSError * _Nullable))callback
{
    LCIMConversationOption convOption = LCIMConversationOptionUnique;
    if (option && !option.isUnique) {
        convOption = LCIMConversationOptionNone;
    }
    [self createConversationWithName:option.name
                           clientIds:clientIds
                          attributes:option.attributes
                             options:convOption
                        temporaryTTL:0
                            callback:callback];
}

- (void)createChatRoomWithCallback:(void (^)(LCIMChatRoom * _Nullable, NSError * _Nullable))callback
{
    [self createChatRoomWithOption:nil callback:callback];
}

- (void)createChatRoomWithOption:(LCIMConversationCreationOption *)option
                        callback:(void (^)(LCIMChatRoom * _Nullable, NSError * _Nullable))callback
{
    [self createConversationWithName:option.name
                           clientIds:@[]
                          attributes:option.attributes
                             options:LCIMConversationOptionTransient
                        temporaryTTL:0
                            callback:^(LCIMConversation * _Nullable conversation, NSError * _Nullable error) {
        callback((LCIMChatRoom *)conversation, error);
    }];
}

- (void)createTemporaryConversationWithClientIds:(NSArray<NSString *> *)clientIds
                                        callback:(void (^)(LCIMTemporaryConversation * _Nullable, NSError * _Nullable))callback
{
    [self createTemporaryConversationWithClientIds:clientIds option:nil callback:callback];
}

- (void)createTemporaryConversationWithClientIds:(NSArray<NSString *> *)clientIds
                                          option:(LCIMConversationCreationOption *)option
                                        callback:(void (^)(LCIMTemporaryConversation * _Nullable, NSError * _Nullable))callback
{
    int32_t ttl = 0;
    if (option.timeToLive > 0) {
        ttl = (int32_t)(option.timeToLive);
    }
    [self createConversationWithName:nil
                           clientIds:clientIds
                          attributes:nil
                             options:LCIMConversationOptionTemporary
                        temporaryTTL:ttl
                            callback:^(LCIMConversation * _Nullable conversation, NSError * _Nullable error) {
        callback((LCIMTemporaryConversation *)conversation, error);
    }];
}

- (void)createConversationWithName:(NSString * _Nullable)name
                         clientIds:(NSArray<NSString *> *)clientIds
                        attributes:(NSDictionary * _Nullable)attributes
                           options:(LCIMConversationOption)options
                      temporaryTTL:(int32_t)temporaryTTL
                          callback:(void (^)(LCIMConversation * _Nullable, NSError * _Nullable))callback
{
    for (NSString *item in clientIds) {
        if (item.length > kClientIdLengthLimit || item.length == 0) {
            [self invokeInUserInteractQueue:^{
                callback(nil, LCErrorInternal([NSString stringWithFormat:@"client id's length should in range [1 %lu].", (unsigned long)kClientIdLengthLimit]));
            }];
            return;
        }
    }
    
    BOOL unique = options & LCIMConversationOptionUnique;
    BOOL transient = options & LCIMConversationOptionTransient;
    BOOL temporary = options & LCIMConversationOptionTemporary;
    
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
    
    [self getSignatureWithConversationId:nil action:LCIMSignatureActionStart actionOnClientIds:members.copy callback:^(LCIMSignature *signature) {
        
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
                    dic[LCIMConversationKeyName] = name;
                }
                if (attributes) {
                    dic[LCIMConversationKeyAttributes] = attributes;
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
        
        [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
            
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
                        LCIMErrorCode code = LCIMErrorCodeInvalidCommand;
                        LCError(code, LCIMErrorMessage(code), nil);
                    }));
                }];
                return;
            }
            
            LCIMConversation *conversation = ({
                LCIMConversation *conversation = [client.conversationManager conversationForId:conversationId];
                if (conversation) {
                    NSMutableDictionary *mutableDic = [NSMutableDictionary dictionary];
                    if (name) {
                        mutableDic[LCIMConversationKeyName] = name;
                    }
                    if (attributes) {
                        mutableDic[LCIMConversationKeyAttributes] = attributes.mutableCopy;
                    }
                    [conversation updateRawJSONDataWith:mutableDic];
                } else {
                    NSMutableDictionary *mutableDic = ({
                        NSMutableDictionary *mutableDic = [NSMutableDictionary dictionary];
                        if (name) {
                            mutableDic[LCIMConversationKeyName] = name;
                        }
                        if (attributes) {
                            mutableDic[LCIMConversationKeyAttributes] = attributes.mutableCopy;
                        }
                        if (convCommand.hasCdate) {
                            mutableDic[LCIMConversationKeyCreatedAt] = convCommand.cdate;
                        }
                        if (convCommand.hasTempConvTtl) {
                            mutableDic[LCIMConversationKeyTemporaryTTL] = @(convCommand.tempConvTtl);
                        }
                        if (convCommand.hasUniqueId) {
                            mutableDic[LCIMConversationKeyUniqueId] = convCommand.uniqueId;
                        }
                        mutableDic[LCIMConversationKeyUnique] = @(unique);
                        mutableDic[LCIMConversationKeyTransient] = @(transient);
                        mutableDic[LCIMConversationKeySystem] = @(false);
                        mutableDic[LCIMConversationKeyTemporary] = @(temporary);
                        mutableDic[LCIMConversationKeyCreator] = client.clientId;
                        mutableDic[LCIMConversationKeyMembers] = members;
                        mutableDic[LCIMConversationKeyObjectId] = conversationId;
                        mutableDic;
                    });
                    conversation = [LCIMConversation conversationWithRawJSONData:mutableDic client:client];
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

- (LCIMConversation *)conversationForId:(NSString *)conversationId
{
    AssertNotRunInQueue(self->_internalSerialQueue);
    if (!conversationId) {
        return nil;
    }
    __block LCIMConversation *conv = nil;
    dispatch_sync(self->_internalSerialQueue, ^{
        conv = [self->_conversationManager conversationForId:conversationId];
    });
    return conv;
}

- (void)getConversationsFromMemoryWith:(NSArray<NSString *> *)conversationIds
                              callback:(void (^)(NSArray<LCIMConversation *> * _Nullable))callback
{
    if (!conversationIds || conversationIds.count == 0) {
        [self invokeInUserInteractQueue:^{
            callback(nil);
        }];
        return;
    }
    [self addOperationToInternalSerialQueue:^(LCIMClient *client) {
        NSMutableArray<LCIMConversation *> *array = [NSMutableArray array];
        for (NSString *conversationId in conversationIds) {
            LCIMConversation *conv = [client->_conversationManager conversationForId:conversationId];
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
    [self addOperationToInternalSerialQueue:^(LCIMClient *client) {
        [client->_conversationManager removeConversationsWithIds:conversationIds];
        [client invokeInUserInteractQueue:^{
            callback();
        }];
    }];
}

- (void)removeAllConversationsInMemoryWith:(void (^)(void))callback
{
    [self addOperationToInternalSerialQueue:^(LCIMClient *client) {
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
                [self addOperationToInternalSerialQueue:^(LCIMClient *client) {
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
        [self status] != LCIMClientStatusOpened) {
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
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        if (commandWrapper.error) {
            LCLoggerError(LCLoggerDomainIM, @"%@", commandWrapper.error);
        }
        [NSNotificationCenter.defaultCenter postNotificationName:@"Test.LCIMClient.reportDeviceToken"
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
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
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
                    LCIMErrorCode code = LCIMErrorCodeInvalidCommand;
                    LCError(code, LCIMErrorMessage(code), nil);
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

- (LCIMConversationQuery *)conversationQuery
{
    LCIMConversationQuery *query = [[LCIMConversationQuery alloc] init];
    query.client = self;
    return query;
}

- (LCIMConversation *)conversationWithKeyedConversation:(LCIMKeyedConversation *)keyedConversation
{
    AssertNotRunInQueue(self->_internalSerialQueue);
    NSString *conversationId = nil;
    NSMutableDictionary *rawDataDic = [keyedConversation.rawDataDic mutableCopy];
    if (rawDataDic) {
        conversationId = [NSString _lc_decoding:rawDataDic key:LCIMConversationKeyObjectId];
    } else {
        rawDataDic = [NSMutableDictionary dictionary];
        if (keyedConversation.conversationId) {
            conversationId = keyedConversation.conversationId;
            rawDataDic[LCIMConversationKeyObjectId] = conversationId;
        }
        if (keyedConversation.creator) {
            rawDataDic[LCIMConversationKeyCreator] = keyedConversation.creator;
        }
        if (keyedConversation.createAt) {
            rawDataDic[LCIMConversationKeyCreatedAt] = [LCDate stringFromDate:keyedConversation.createAt];
        }
        if (keyedConversation.updateAt) {
            rawDataDic[LCIMConversationKeyUpdatedAt] = [LCDate stringFromDate:keyedConversation.updateAt];
        }
        if (keyedConversation.name) {
            rawDataDic[LCIMConversationKeyName] = keyedConversation.name;
        }
        if (keyedConversation.members) {
            rawDataDic[LCIMConversationKeyMembers] = keyedConversation.members;
        }
        if (keyedConversation.attributes) {
            rawDataDic[LCIMConversationKeyAttributes] = keyedConversation.attributes;
        }
        if (keyedConversation.uniqueId) {
            rawDataDic[LCIMConversationKeyUniqueId] = keyedConversation.uniqueId;
        }
        if (keyedConversation.unique) {
            rawDataDic[LCIMConversationKeyUnique] = @(keyedConversation.unique);
        }
        if (keyedConversation.transient) {
            rawDataDic[LCIMConversationKeyTransient] = @(keyedConversation.transient);
        }
        if (keyedConversation.system) {
            rawDataDic[LCIMConversationKeySystem] = @(keyedConversation.system);
        }
        if (keyedConversation.temporary) {
            rawDataDic[LCIMConversationKeyTemporary] = @(keyedConversation.temporary);
        }
        if (keyedConversation.temporaryTTL) {
            rawDataDic[LCIMConversationKeyTemporaryTTL] = @(keyedConversation.temporaryTTL);
        }
        if (keyedConversation.muted) {
            rawDataDic[LCIMConversationKeyMutedMembers] = @(keyedConversation.muted);
        }
    }
    if (keyedConversation.lastMessage) {
        LCIMMessage *message = keyedConversation.lastMessage;
        [rawDataDic removeObjectsForKeys:({
            @[LCIMConversationKeyLastMessageContent,
              LCIMConversationKeyLastMessageId,
              LCIMConversationKeyLastMessageFrom,
              LCIMConversationKeyLastMessageTimestamp,
              LCIMConversationKeyLastMessagePatchTimestamp,
              LCIMConversationKeyLastMessageMentionAll,
              LCIMConversationKeyLastMessageMentionPids];
        })];
        if (message.content) {
            rawDataDic[LCIMConversationKeyLastMessageContent] = message.content;
        }
        if (message.messageId) {
            rawDataDic[LCIMConversationKeyLastMessageId] = message.messageId;
        }
        if (message.clientId) {
            rawDataDic[LCIMConversationKeyLastMessageFrom] = message.clientId;
        }
        if (message.sendTimestamp) {
            rawDataDic[LCIMConversationKeyLastMessageTimestamp] = @(message.sendTimestamp);
        }
        if (message.updatedAt) {
            rawDataDic[LCIMConversationKeyLastMessagePatchTimestamp] = @(message.updatedAt.timeIntervalSince1970 * 1000.0);
        }
        if (message.mentionAll) {
            rawDataDic[LCIMConversationKeyLastMessageMentionAll] = @(message.mentionAll);
        }
        if (message.mentionList) {
            rawDataDic[LCIMConversationKeyLastMessageMentionPids] = message.mentionList;
        }
    }
    if (!conversationId) {
        return nil;
    }
    __block LCIMConversation *conv = nil;
    dispatch_sync(self->_internalSerialQueue, ^{
        conv = [self->_conversationManager conversationForId:conversationId];
        if (!conv) {
            conv = [LCIMConversation conversationWithRawJSONData:rawDataDic client:self];
            if (conv) {
                [self->_conversationManager insertConversation:conv];
            }
        }
    });
    return conv;
}

- (void)conversation:(LCIMConversation *)conversation didUpdateForKeys:(NSArray<LCIMConversationUpdatedKey> *)keys
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    if (keys.count == 0) {
        return;
    }
    
    id <LCIMClientDelegate> delegate = self->_delegate;
    SEL sel = @selector(conversation:didUpdateForKey:);
    if (delegate && [delegate respondsToSelector:sel]) {
        for (LCIMConversationUpdatedKey key in keys) {
            [self invokeInUserInteractQueue:^{
                [delegate conversation:conversation didUpdateForKey:key];
            }];
        }
    }
}

+ (LCIMProtocol)IMProtocol {
    return LCIMProtocol3;
}

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
