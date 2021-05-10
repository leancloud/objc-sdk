//
//  LCIMConversationMemberInfo.m
//  LeanCloud
//
//  Created by zapcannon87 on 2018/4/9.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "LCIMConversationMemberInfo_Internal.h"
#import "LCIMConversation_Internal.h"
#import "LCUtils.h"

LCIMConversationMemberRoleKey LCIMConversationMemberInfo_role_to_key(LCIMConversationMemberRole role)
{
    switch (role)
    {
        case LCIMConversationMemberRoleMember:
            return LCIMConversationMemberRoleKeyMember;
        case LCIMConversationMemberRoleManager:
            return LCIMConversationMemberRoleKeyManager;
        case LCIMConversationMemberRoleOwner:
            return LCIMConversationMemberRoleKeyOwner;
        default:
            return nil;
    }
}

LCIMConversationMemberRole LCIMConversationMemberInfo_key_to_role(LCIMConversationMemberRoleKey key)
{
    LCIMConversationMemberRole role = LCIMConversationMemberRoleMember;
    if ([key isEqualToString:LCIMConversationMemberRoleKeyMember]) {
        role = LCIMConversationMemberRoleMember;
    } else if ([key isEqualToString:LCIMConversationMemberRoleKeyManager]) {
        role = LCIMConversationMemberRoleManager;
    } else if ([key isEqualToString:LCIMConversationMemberRoleKeyOwner]) {
        role = LCIMConversationMemberRoleOwner;
    }
    return role;
}

@implementation LCIMConversationMemberInfo {
    __weak LCIMConversation *_conversation;
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

- (instancetype)initWithRawJSONData:(NSMutableDictionary *)rawJSONData conversation:(LCIMConversation *)conversation
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
        value = [NSString _lc_decoding:self->_rawJSONData key:LCIMConversationMemberInfoKeyConversationId];
    }];
    return value;
}

- (NSString *)memberId
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString _lc_decoding:self->_rawJSONData key:LCIMConversationMemberInfoKeyMemberId];
    }];
    return value;
}

- (LCIMConversationMemberRole)role
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString _lc_decoding:self->_rawJSONData key:LCIMConversationMemberInfoKeyRole];
    }];
    return LCIMConversationMemberInfo_key_to_role(value);
}

- (BOOL)isOwner
{
    return [self->_conversation.creator isEqualToString:self.memberId];
}

@end
