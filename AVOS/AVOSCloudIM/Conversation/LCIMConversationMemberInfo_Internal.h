//
//  LCIMConversationMemberInfo_Internal.h
//  LeanCloud
//
//  Created by zapcannon87 on 2018/4/9.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "LCIMConversationMemberInfo.h"
#import "LCIMCommon_Internal.h"

LCIMConversationMemberRoleKey LCIMConversationMemberInfo_role_to_key(LCIMConversationMemberRole role);
LCIMConversationMemberRole LCIMConversationMemberInfo_key_to_role(LCIMConversationMemberRoleKey key);

@class LCIMConversation;

@interface LCIMConversationMemberInfo ()

- (instancetype)initWithRawJSONData:(NSMutableDictionary *)rawJSONData conversation:(LCIMConversation *)conversation;

- (void)updateRawJSONDataWithKey:(NSString *)key object:(id)object;

@end
