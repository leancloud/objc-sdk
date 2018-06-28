//
//  AVIMConversationMemberInfo.h
//  AVOS
//
//  Created by zapcannon87 on 2018/4/9.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Conversation Member Role
 
 - AVIMConversationMemberRoleMember: Member
 - AVIMConversationMemberRoleManager: Manager
 */
typedef NS_ENUM(NSUInteger, AVIMConversationMemberRole) {
    AVIMConversationMemberRoleMember = 0,
    AVIMConversationMemberRoleManager = 1,
    AVIMConversationMemberRoleOwner = 2,
};

@interface AVIMConversationMemberInfo : NSObject

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
- (AVIMConversationMemberRole)role;

/**
 Whether is the creator of the conversation.

 @return Bool.
 */
- (BOOL)isOwner;

@end

NS_ASSUME_NONNULL_END
