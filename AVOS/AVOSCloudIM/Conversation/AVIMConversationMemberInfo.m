//
//  AVIMConversationMemberInfo.m
//  AVOS
//
//  Created by zapcannon87 on 2018/4/9.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMConversationMemberInfo_Internal.h"
#import "AVIMConversation_Internal.h"
#import "AVUtils.h"

AVIMConversationMemberRoleKey AVIMConversationMemberInfo_role_to_key(AVIMConversationMemberRole role)
{
    switch (role)
    {
        case AVIMConversationMemberRoleMember:
            return AVIMConversationMemberRoleKeyMember;
        case AVIMConversationMemberRoleManager:
            return AVIMConversationMemberRoleKeyManager;
        case AVIMConversationMemberRoleOwner:
            return AVIMConversationMemberRoleKeyOwner;
        default:
            return nil;
    }
}

AVIMConversationMemberRole AVIMConversationMemberInfo_key_to_role(AVIMConversationMemberRoleKey key)
{
    AVIMConversationMemberRole role = AVIMConversationMemberRoleMember;
    if ([key isEqualToString:AVIMConversationMemberRoleKeyMember]) {
        role = AVIMConversationMemberRoleMember;
    } else if ([key isEqualToString:AVIMConversationMemberRoleKeyManager]) {
        role = AVIMConversationMemberRoleManager;
    } else if ([key isEqualToString:AVIMConversationMemberRoleKeyOwner]) {
        role = AVIMConversationMemberRoleOwner;
    }
    return role;
}

@implementation AVIMConversationMemberInfo {
    __weak AVIMConversation *_conversation;
    NSMutableDictionary *_rawJSONData;
    NSLock *_lock;
}

+ (instancetype)new
{
    [NSException raise:NSInternalInconsistencyException format:@"not allow."];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException format:@"not allow."];
    return nil;
}

- (instancetype)initWithRawJSONData:(NSMutableDictionary *)rawJSONData conversation:(AVIMConversation *)conversation
{
    self = [super init];
    if (self) {
        self->_rawJSONData = rawJSONData;
        self->_conversation = conversation;
        self->_lock = [[NSLock alloc] init];
    }
    return self;
}

- (void)internalSyncLock:(void (^)(void))block
{
    [self->_lock lock];
    block();
    [self->_lock unlock];
}

- (void)updateRawJSONDataWithKey:(NSString *)key object:(id)object
{
    [self internalSyncLock:^{
        self->_rawJSONData[key] = object;
    }];
}

- (NSString *)conversationId
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString _lc_decoding:self->_rawJSONData key:AVIMConversationMemberInfoKeyConversationId];
    }];
    return value;
}

- (NSString *)memberId
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString _lc_decoding:self->_rawJSONData key:AVIMConversationMemberInfoKeyMemberId];
    }];
    return value;
}

- (AVIMConversationMemberRole)role
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString _lc_decoding:self->_rawJSONData key:AVIMConversationMemberInfoKeyRole];
    }];
    return AVIMConversationMemberInfo_key_to_role(value);
}

- (BOOL)isOwner
{
    return [self->_conversation.creator isEqualToString:self.memberId];
}

@end
