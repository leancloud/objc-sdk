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

extern NSInteger const kLC_Code_SessionTokenExpired;

extern NSString * const kTemporaryConversationIdPrefix;

@interface AVIMClient () <AVIMWebSocketWrapperDelegate>

+ (NSMutableDictionary *)_userOptions;

+ (void)_assertClientIdsIsValid:(NSArray *)clientIds;

/// Hold the staged message, which is sent by current client and waiting for receipt.
@property (nonatomic, strong) NSMutableDictionary   *stagedMessages;
@property (nonatomic, strong) LCIMConversationCache *conversationCache;

/**
 Conversations's Memory Cache Container.
 */
@property (nonatomic, strong) NSMutableDictionary *conversationDictionary;

- (instancetype)initWithClientId:(NSString *)clientId
                             tag:(NSString *)tag
                    installation:(AVInstallation *)installation LC_WARN_UNUSED_RESULT;

- (instancetype)initWithUser:(AVUser *)user
                         tag:(NSString *)tag
                installation:(AVInstallation *)installation LC_WARN_UNUSED_RESULT;

- (void)sendCommand:(AVIMGenericCommand *)command;

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper;

- (void)stageMessage:(AVIMMessage *)message;
- (void)unstageMessageForId:(NSString *)messageId;
- (AVIMMessage *)stagedMessageForId:(NSString *)messageId LC_WARN_UNUSED_RESULT;

- (void)resetUnreadMessagesCountForConversation:(AVIMConversation *)conversation;

- (void)updateReceipt:(NSDate *)date
       ofConversation:(AVIMConversation *)conversation
               forKey:(NSString *)key;

- (dispatch_queue_t)internalSerialQueue LC_WARN_UNUSED_RESULT;

- (void)addOperationToInternalSerialQueue:(void (^)(AVIMClient *client))block;

- (void)getSignatureWithConversationId:(NSString *)conversationId
                                action:(AVIMSignatureAction)action
                     actionOnClientIds:(NSArray<NSString *> *)actionOnClientIds
                              callback:(void (^)(AVIMSignature *signature))callback;

- (void)getSessionTokenWithForcingRefresh:(BOOL)forcingRefresh
                                 callback:(void (^)(NSString *sessionToken, NSError *error))callback;

/*
 Conversation Memory Cache
 */
- (AVIMConversation *)getConversationWithId:(NSString *)convId
                              orNewWithType:(LCIMConvType)convType LC_WARN_UNUSED_RESULT;

/*
 Thread-unsafe
 */
///

- (AVIMClientStatus)threadUnsafe_status LC_WARN_UNUSED_RESULT;

- (id<AVIMClientDelegate>)threadUnsafe_delegate LC_WARN_UNUSED_RESULT;

///

@end
