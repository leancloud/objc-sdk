//
//  LCIMConversationMemberInfo.h
//  LeanCloud
//
//  Created by zapcannon87 on 2018/4/9.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "LCIMCommon.h"

NS_ASSUME_NONNULL_BEGIN

@interface LCIMConversationMemberInfo : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/**
 Member's conversation's id.

 @return Conversation id.
 */
- (NSString * _Nullable)conversationId;

/**
 Equal to client id.

 @return Member id.
 */
- (NSString * _Nullable)memberId;

/**
 Member's role

 @return Role
 */
- (LCIMConversationMemberRole)role;

/**
 Whether is the creator of the conversation.

 @return Bool.
 */
- (BOOL)isOwner;

@end

NS_ASSUME_NONNULL_END
