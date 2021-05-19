//
//  LCIMClient.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMClient.h"
#import "LCIMCommon_Internal.h"
#import "LCRTMConnection.h"
#import "LCIMClientInternalConversationManager.h"
#import "LCIMSignature.h"
#import "LCIMConversationCache.h"

#import "LCApplication_Internal.h"

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
@property (nonatomic) void (^callback)(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper);

@end

@interface LCIMClient () <LCRTMConnectionDelegate>

@property (nonatomic, readonly) int64_t sessionConfigBitmap;
@property (nonatomic, readonly) NSLock *lock;
@property (nonatomic, readonly) dispatch_queue_t internalSerialQueue;
@property (nonatomic, readonly) dispatch_queue_t signatureQueue;
@property (nonatomic, readonly) dispatch_queue_t userInteractQueue;
@property (nonatomic, readonly) LCRTMConnection *connection;
@property (nonatomic, readonly) LCRTMServiceConsumer *serviceConsumer;
@property (nonatomic, readonly) LCRTMConnectionDelegator *connectionDelegator;
@property (nonatomic, readonly) LCInstallation *installation;
@property (nonatomic, readonly) LCIMClientInternalConversationManager *conversationManager;
@property (nonatomic, readonly) LCIMConversationCache *conversationCache;

@property (nonatomic) void (^openingCompletion)(BOOL, NSError *);
@property (nonatomic) LCIMClientOpenOption openingOption;
@property (nonatomic) NSString *sessionToken;
@property (nonatomic) NSDate *sessionTokenExpiration;
@property (nonatomic) int64_t lastUnreadNotifTime;
@property (nonatomic) int64_t lastPatchTime;
@property (nonatomic) NSString *currentDeviceToken;

- (instancetype)initWithClientId:(NSString *)clientId
                             tag:(NSString *)tag
                    installation:(LCInstallation *)installation
                           error:(NSError * __autoreleasing *)error LC_WARN_UNUSED_RESULT;

- (instancetype)initWithUser:(LCUser *)user
                         tag:(NSString *)tag
                installation:(LCInstallation *)installation
                       error:(NSError * __autoreleasing *)error LC_WARN_UNUSED_RESULT;

- (void)addOperationToInternalSerialQueue:(void (^)(LCIMClient *client))block;
- (void)invokeInUserInteractQueue:(void (^)(void))block;
- (void)invokeDelegateInUserInteractQueue:(void (^)(id<LCIMClientDelegate> delegate))block;

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper;

- (void)getSignatureWithConversationId:(NSString *)conversationId
                                action:(LCIMSignatureAction)action
                     actionOnClientIds:(NSArray<NSString *> *)actionOnClientIds
                              callback:(void (^)(LCIMSignature *signature))callback;

- (void)getSessionTokenWithForcingRefresh:(BOOL)forcingRefresh
                                 callback:(void (^)(NSString *sessionToken, NSError *error))callback;

- (void)conversation:(LCIMConversation *)conversation didUpdateForKeys:(NSArray<LCIMConversationUpdatedKey> *)keys;

@end
