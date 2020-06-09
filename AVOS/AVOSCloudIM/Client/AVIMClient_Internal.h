//
//  AVIM.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon_Internal.h"
#import "AVIMClient.h"
#import "LCRTMConnection.h"

#import "AVApplication_Internal.h"

@class LCIMConversationCache;
@class AVIMClientInternalConversationManager;
@class AVIMClientPushManager;
@class AVIMSignature;

#if DEBUG
void assertContextOfQueue(dispatch_queue_t queue, BOOL isRunIn);
#define AssertRunInQueue(queue) assertContextOfQueue(queue, true);
#define AssertNotRunInQueue(queue) assertContextOfQueue(queue, false);
#else
#define AssertRunInQueue(queue)
#define AssertNotRunInQueue(queue)
#endif

@interface LCIMProtobufCommandWrapper : NSObject

@property (nonatomic) AVIMGenericCommand *outCommand;
@property (nonatomic) AVIMGenericCommand *inCommand;
@property (nonatomic) NSError *error;

- (void)setCallback:(void (^)(LCIMProtobufCommandWrapper *commandWrapper))callback;
- (BOOL)hasCallback;
- (void)executeCallbackAndSetItToNil;

@end

@interface AVIMClient () <LCRTMConnectionDelegate>

@property (nonatomic, readonly) NSLock *lock;
@property (nonatomic, readonly) dispatch_queue_t internalSerialQueue;
@property (nonatomic, readonly) dispatch_queue_t signatureQueue;
@property (nonatomic, readonly) dispatch_queue_t userInteractQueue;
@property (nonatomic, readonly) LCRTMConnection *connection;
@property (nonatomic, readonly) LCRTMServiceConsumer *serviceConsumer;
@property (nonatomic, readonly) LCRTMConnectionDelegator *connectionDelegator;
@property (nonatomic, readonly) AVIMClientInternalConversationManager *conversationManager;
@property (nonatomic, readonly) AVIMClientPushManager *pushManager;
@property (nonatomic, readonly) LCIMConversationCache *conversationCache;

+ (NSMutableDictionary *)sessionProtocolOptions;

- (instancetype)initWithClientId:(NSString *)clientId
                             tag:(NSString *)tag
                    installation:(AVInstallation *)installation LC_WARN_UNUSED_RESULT;

- (instancetype)initWithUser:(AVUser *)user
                         tag:(NSString *)tag
                installation:(AVInstallation *)installation LC_WARN_UNUSED_RESULT;

- (void)addOperationToInternalSerialQueue:(void (^)(AVIMClient *client))block;

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper;

- (void)getSignatureWithConversationId:(NSString *)conversationId
                                action:(AVIMSignatureAction)action
                     actionOnClientIds:(NSArray<NSString *> *)actionOnClientIds
                              callback:(void (^)(AVIMSignature *signature))callback;

- (void)getSessionTokenWithForcingRefresh:(BOOL)forcingRefresh
                                 callback:(void (^)(NSString *sessionToken, NSError *error))callback;

- (void)conversation:(AVIMConversation *)conversation didUpdateForKeys:(NSArray<AVIMConversationUpdatedKey> *)keys;

@end
