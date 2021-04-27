//
//  AVIMConversationMemberInfo_Internal.h
//  AVOS
//
//  Created by zapcannon87 on 2018/4/9.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMConversationMemberInfo.h"
#import "LCIMCommon_Internal.h"

LCIMConversationMemberRoleKey AVIMConversationMemberInfo_role_to_key(LCIMConversationMemberRole role);
LCIMConversationMemberRole AVIMConversationMemberInfo_key_to_role(LCIMConversationMemberRoleKey key);

@class AVIMConversation;

@interface AVIMConversationMemberInfo ()

- (instancetype)initWithRawJSONData:(NSMutableDictionary *)rawJSONData conversation:(AVIMConversation *)conversation;

- (void)updateRawJSONDataWithKey:(NSString *)key object:(id)object;

@end
