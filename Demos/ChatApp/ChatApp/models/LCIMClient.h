//
//  LCIMClient.h
//  ChatApp
//
//  Created by Qihe Bian on 12/10/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCCommon.h"
#import "LCMessageEntity.h"

#define LC_NOTIFICATION_MESSAGE_UPDATED @"LC_NOTIFICATION_MESSAGE_UPDATED"
#define LC_NOTIFICATION_CONVERSATION_UPDATED @"LC_NOTIFICATION_CONVERSATION_UPDATED"

typedef enum : NSUInteger {
    LCConversationTypeSingle = 1,
    LCConversationTypeGroup
} LCConversationType;

@interface LCIMClient : NSObject
@property(nonatomic, strong, readonly)NSArray *conversations;
+ (instancetype)sharedInstance;

- (void)openWithCallback:(AVIMBooleanResultBlock)callback;
- (void)close;
- (void)clearDataAndClose;
- (void)createConversationWithUserId:(NSString *)userId callback:(AVIMConversationResultBlock)callback;
- (void)createConversationWithUserIds:(NSArray *)userIds callback:(AVIMConversationResultBlock)callback;
- (void)queryConversationsWithCallback:(AVIMArrayResultBlock)callback;
- (void)fetchOrCreateConversationWithUserId:(NSString *)userId callback:(AVIMConversationResultBlock)callback;
- (void)sendText:(NSString *)text conversation:(AVIMConversation *)conversation callback:(AVIMBooleanResultBlock)callback;
- (NSArray *)messagesForConversationId:(NSString *)conversationId;
- (LCMessageEntity *)latestMessageForConversationId:(NSString *)conversationId;
- (void)updateConversation:(AVIMConversation *)conversation withName:(NSString *)name attributes:(NSDictionary *)attributes callback:(AVIMBooleanResultBlock)callback;
- (void)addUserIds:(NSArray *)userIds toConversation:(AVIMConversation *)conversation callback:(AVIMBooleanResultBlock)callback;
@end
