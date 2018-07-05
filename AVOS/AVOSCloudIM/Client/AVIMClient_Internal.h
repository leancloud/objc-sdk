//
//  AVIM.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMClient.h"
#import "AVIMWebSocketWrapper.h"
#import "LCIMConversationCache.h"
#import "AVIMConversation_Internal.h"

@class AVInstallation;

#if DEBUG
#define AssertRunInInternalSerialQueue(client) [client assertRunInInternalSerialQueue]
#define AssertNotRunInInternalSerialQueue(client) [client assertNotRunInInternalSerialQueue]
#else
#define AssertRunInInternalSerialQueue(client)
#define AssertNotRunInInternalSerialQueue(client)
#endif

FOUNDATION_EXPORT NSUInteger const kLC_ClientId_MaxLength;
FOUNDATION_EXPORT NSInteger const kLC_Code_SessionTokenExpired;
FOUNDATION_EXPORT NSString * const kTemporaryConversationIdPrefix;

@interface AVIMClient () <AVIMWebSocketWrapperDelegate>

#if DEBUG
@property (nonatomic, copy) void (^ assertInternalQuietCallback)(NSError *error);
- (void)assertRunInInternalSerialQueue;
- (void)assertNotRunInInternalSerialQueue;
#endif

+ (NSMutableDictionary *)_userOptions;

- (instancetype)initWithClientId:(NSString *)clientId
                             tag:(NSString *)tag
                    installation:(AVInstallation *)installation LC_WARN_UNUSED_RESULT;

- (instancetype)initWithUser:(AVUser *)user
                         tag:(NSString *)tag
                installation:(AVInstallation *)installation LC_WARN_UNUSED_RESULT;

- (dispatch_queue_t)internalSerialQueue LC_WARN_UNUSED_RESULT;
- (dispatch_queue_t)userInteractQueue LC_WARN_UNUSED_RESULT;

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

- (void)cacheConversationToMemory:(AVIMConversation *)conversation;

- (AVIMConversation *)getConversationFromMemory:(NSString *)conversationId LC_WARN_UNUSED_RESULT;

- (LCIMConversationCache *)conversationCache LC_WARN_UNUSED_RESULT;

- (void)sendCommand:(AVIMGenericCommand *)command;

@end
