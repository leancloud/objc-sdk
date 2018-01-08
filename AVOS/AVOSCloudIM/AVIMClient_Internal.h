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

/*
 Use dispatch's specific to Assert ('current queue' == 'imClient')
 */
///
#ifdef DEBUG

static void *imClientQueue_specific_key;
static void *imClientQueue_specific_value;

#define AssertRunInIMClientQueue NSAssert(dispatch_get_specific(imClientQueue_specific_key) == imClientQueue_specific_value, @"This internal method should run in `imClientQueue`.")

#endif
///

@interface AVIMClient ()

+ (NSMutableDictionary *)_userOptions;
+ (dispatch_queue_t)imClientQueue;
+ (BOOL)checkErrorForSignature:(AVIMSignature *)signature command:(AVIMGenericCommand *)command;
+ (void)_assertClientIdsIsValid:(NSArray *)clientIds;

@property (nonatomic, copy)   NSString              *clientId;
@property (nonatomic, assign) AVIMClientStatus       status;
@property (nonatomic, strong) AVIMWebSocketWrapper  *socketWrapper;

/// Hold the staged message, which is sent by current client and waiting for receipt.
@property (nonatomic, strong) NSMutableDictionary   *stagedMessages;

@property (nonatomic, strong) AVIMGenericCommand    *openCommand;
@property (nonatomic, assign) int32_t                openTimes;
@property (nonatomic, copy)   NSString              *tag;
@property (nonatomic, assign) BOOL                   onceOpened;

@property (nonatomic, assign) int64_t                lastPatchTimestamp;
@property (nonatomic, assign) int64_t                lastUnreadTimestamp;

@property (nonatomic, strong) LCIMConversationCache *conversationCache;

/**
 Conversations's Memory Cache Container.
 */
@property (nonatomic, strong) NSMutableDictionary *conversationDictionary;

- (void)setStatus:(AVIMClientStatus)status;

- (void)sendCommand:(AVIMGenericCommand *)command;

- (AVIMSignature *)signatureWithClientId:(NSString *)clientId
                          conversationId:(NSString *)conversationId
                                  action:(NSString *)action
                       actionOnClientIds:(NSArray *)clientIds;

- (void)stageMessage:(AVIMMessage *)message;
- (void)unstageMessageForId:(NSString *)messageId;
- (AVIMMessage *)stagedMessageForId:(NSString *)messageId;

- (void)resetUnreadMessagesCountForConversation:(AVIMConversation *)conversation;

- (void)updateReceipt:(NSDate *)date
       ofConversation:(AVIMConversation *)conversation
               forKey:(NSString *)key;

/*
 Conversation Memory Cache
 */
- (AVIMConversation *)getConversationWithId:(NSString *)convId
                              orNewWithType:(LCIMConvType)convType
__attribute__((warn_unused_result));

@end
