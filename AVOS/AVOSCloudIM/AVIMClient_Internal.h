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

@interface AVIMClient () <AVIMWebSocketWrapperDelegate>

+ (NSMutableDictionary *)_userOptions;

+ (BOOL)checkErrorForSignature:(AVIMSignature *)signature command:(AVIMGenericCommand *)command;
+ (void)_assertClientIdsIsValid:(NSArray *)clientIds;

/// Hold the staged message, which is sent by current client and waiting for receipt.
@property (nonatomic, strong) NSMutableDictionary   *stagedMessages;
@property (nonatomic, strong) LCIMConversationCache *conversationCache;

/**
 Conversations's Memory Cache Container.
 */
@property (nonatomic, strong) NSMutableDictionary *conversationDictionary;

- (void)sendCommand:(AVIMGenericCommand *)command;

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper;

- (void)stageMessage:(AVIMMessage *)message;
- (void)unstageMessageForId:(NSString *)messageId;
- (AVIMMessage *)stagedMessageForId:(NSString *)messageId;

- (void)resetUnreadMessagesCountForConversation:(AVIMConversation *)conversation;

- (void)updateReceipt:(NSDate *)date
       ofConversation:(AVIMConversation *)conversation
               forKey:(NSString *)key;

/*
 Internal Serial Queue
 */
- (dispatch_queue_t)internalSerialQueue
__attribute__((warn_unused_result));

- (void)addOperationToInternalSerialQueueWithBlock:(void (^)(AVIMClient *client))block;

/*
 Signature
 */
- (AVIMSignature *)getSignatureByDataSourceWithAction:(NSString *)action
                                       conversationId:(NSString *)conversationId
                                            clientIds:(NSArray<NSString *> *)clientIds
__attribute__((warn_unused_result));

/*
 Conversation Memory Cache
 */
- (AVIMConversation *)getConversationWithId:(NSString *)convId
                              orNewWithType:(LCIMConvType)convType
__attribute__((warn_unused_result));

/*
 Thread-unsafe
 */
///

- (AVIMClientStatus)threadUnsafe_status
__attribute__((warn_unused_result));

- (id<AVIMClientDelegate>)threadUnsafe_delegate
__attribute__((warn_unused_result));

///

@end
