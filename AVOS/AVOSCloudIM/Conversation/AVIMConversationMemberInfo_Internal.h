//
//  AVIMConversationMemberInfo_Internal.h
//  AVOS
//
//  Created by zapcannon87 on 2018/4/9.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMConversationMemberInfo.h"

extern NSString * const kAVIMConversationMemberRoleMember_string;
extern NSString * const kAVIMConversationMemberRoleManager_string;

extern NSString * AVIMConversationMemberInfo_StringFromRole(AVIMConversationMemberRole role);

@class AVIMConversation;

@interface AVIMConversationMemberInfo ()

- (instancetype)initWithJSON:(NSDictionary *)JSON conversation:(AVIMConversation *)conversation;

- (void)updateRawJSONDataWithKey:(NSString *)key object:(id)object;

@end
