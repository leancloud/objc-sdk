//
//  AVIMConversationMemberInfo_Internal.h
//  AVOS
//
//  Created by zapcannon87 on 2018/4/9.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMConversationMemberInfo.h"

typedef NSString * const kAVIMConversationMemberInfoKey NS_TYPED_EXTENSIBLE_ENUM;
static kAVIMConversationMemberInfoKey kAVIMConversationMemberInfoKey_conversationId = @"cid";
static kAVIMConversationMemberInfoKey kAVIMConversationMemberInfoKey_memberId_1 = @"clientId";
static kAVIMConversationMemberInfoKey kAVIMConversationMemberInfoKey_memberId_2 = @"peerId";
static kAVIMConversationMemberInfoKey kAVIMConversationMemberInfoKey_role = @"role";

typedef NSString * const kAVIMConversationMemberRole NS_TYPED_EXTENSIBLE_ENUM;
static kAVIMConversationMemberRole kAVIMConversationMemberRoleMember = @"Member";
static kAVIMConversationMemberRole kAVIMConversationMemberRoleManager = @"Manager";
static kAVIMConversationMemberRole kAVIMConversationMemberRoleOwner = @"Owner";

FOUNDATION_EXPORT NSString * AVIMConversationMemberInfo_role_to_key(AVIMConversationMemberRole role);
FOUNDATION_EXPORT AVIMConversationMemberRole AVIMConversationMemberInfo_key_to_role(kAVIMConversationMemberRole key);

@class AVIMConversation;

@interface AVIMConversationMemberInfo ()

- (instancetype)initWithRawJSONData:(NSMutableDictionary *)rawJSONData conversation:(AVIMConversation *)conversation;

- (void)updateRawJSONDataWithKey:(NSString *)key object:(id)object;

@end
