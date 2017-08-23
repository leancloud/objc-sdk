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

@interface AVIMClient ()

+ (NSMutableDictionary *)userOptions;
+ (dispatch_queue_t)imClientQueue;
+ (BOOL)checkErrorForSignature:(AVIMSignature *)signature command:(AVIMGenericCommand *)command;
+ (void)_assertClientIdsIsValid:(NSArray *)clientIds;

@property (nonatomic, copy)   NSString              *clientId;
@property (nonatomic, assign) AVIMClientStatus       status;
@property (nonatomic, strong) AVIMWebSocketWrapper  *socketWrapper;
@property (nonatomic, strong) NSMutableDictionary   *conversations;

/// Hold the staged message, which is sent by current client and waiting for receipt.
@property (nonatomic, strong) NSMutableDictionary   *stagedMessages;

@property (nonatomic, strong) AVIMGenericCommand    *openCommand;
@property (nonatomic, assign) int32_t                openTimes;
@property (nonatomic, copy)   NSString              *tag;
@property (nonatomic, assign) BOOL                   onceOpened;

@property (nonatomic, assign) int64_t                lastPatchTimestamp;
@property (nonatomic, assign) int64_t                lastUnreadTimestamp;

@property (nonatomic, strong) LCIMConversationCache *conversationCache;

- (void)setStatus:(AVIMClientStatus)status;
- (AVIMConversation *)conversationWithId:(NSString *)conversationId;
- (void)sendCommand:(AVIMGenericCommand *)command;
- (AVIMSignature *)signatureWithClientId:(NSString *)clientId conversationId:(NSString *)conversationId action:(NSString *)action actionOnClientIds:(NSArray *)clientIds;
- (void)stageMessage:(AVIMMessage *)message;
- (void)unstageMessageForId:(NSString *)messageId;
- (AVIMMessage *)stagedMessageForId:(NSString *)messageId;

/*!
 * Cache conversations to memory and sqlite.
 * @param conversations Conversations to be cached.
 */
- (void)cacheConversations:(NSArray *)conversations;

- (void)cacheConversationsIfNeeded:(NSArray *)conversations;

- (void)resetUnreadMessagesCountForConversation:(AVIMConversation *)conversation;

- (void)updateReceipt:(NSDate *)date
       ofConversation:(AVIMConversation *)conversation
               forKey:(NSString *)key;

@end
