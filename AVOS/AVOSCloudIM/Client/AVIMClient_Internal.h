//
//  AVIM.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMClient.h"
#import "AVIMWebSocketWrapper.h"

@class LCIMConversationCache;
@class AVIMClientInternalConversationManager;

#if DEBUG
void assertContextOfQueue(dispatch_queue_t queue, BOOL isRunIn);
#define AssertRunInQueue(queue) assertContextOfQueue(queue, true);
#define AssertNotRunInQueue(queue) assertContextOfQueue(queue, false);
#else
#define AssertRunInQueue(queue)
#define AssertNotRunInQueue(queue)
#endif

FOUNDATION_EXPORT NSUInteger const clientIdLengthLimit;
FOUNDATION_EXPORT NSInteger const errorCodeSessionTokenExpired;
FOUNDATION_EXPORT NSString * const kTemporaryConversationIdPrefix;

@interface AVIMClient () <AVIMWebSocketWrapperDelegate>

#if DEBUG
@property (nonatomic, copy) void (^ assertInternalQuietCallback)(NSError *error);
#endif
@property (nonatomic, strong, readonly) dispatch_queue_t internalSerialQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t userInteractQueue;
@property (nonatomic, strong, readonly) AVIMClientInternalConversationManager *conversationManager;
@property (nonatomic, strong, readonly) LCIMConversationCache *conversationCache;

+ (NSMutableDictionary *)_userOptions;

- (instancetype)initWithClientId:(NSString *)clientId
                             tag:(NSString *)tag
                    installation:(AVInstallation *)installation LC_WARN_UNUSED_RESULT;

- (instancetype)initWithUser:(AVUser *)user
                         tag:(NSString *)tag
                installation:(AVInstallation *)installation LC_WARN_UNUSED_RESULT;

- (void)addOperationToInternalSerialQueue:(void (^)(AVIMClient *client))block;

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper;

- (void)_sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper;

- (void)getSignatureWithConversationId:(NSString *)conversationId
                                action:(AVIMSignatureAction)action
                     actionOnClientIds:(NSArray<NSString *> *)actionOnClientIds
                              callback:(void (^)(AVIMSignature *signature))callback;

- (void)getSessionTokenWithForcingRefresh:(BOOL)forcingRefresh
                                 callback:(void (^)(NSString *sessionToken, NSError *error))callback;

- (void)conversation:(AVIMConversation *)conversation didUpdateForKeys:(NSArray<AVIMConversationUpdatedKey> *)keys;

- (void)sendCommand:(AVIMGenericCommand *)command;

@end
