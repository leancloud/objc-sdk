//
//  AVIMConversationMemberInfo_Internal.h
//  AVOS
//
//  Created by zapcannon87 on 2018/4/9.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMConversationMemberInfo.h"
#import "AVIMCommon_Internal.h"

AVIMConversationMemberRoleKey AVIMConversationMemberInfo_role_to_key(AVIMConversationMemberRole role);
AVIMConversationMemberRole AVIMConversationMemberInfo_key_to_role(AVIMConversationMemberRoleKey key);

@class AVIMConversation;

@interface AVIMConversationMemberInfo ()

- (instancetype)initWithRawJSONData:(NSMutableDictionary *)rawJSONData conversation:(AVIMConversation *)conversation;

- (void)updateRawJSONDataWithKey:(NSString *)key object:(id)object;

@end
