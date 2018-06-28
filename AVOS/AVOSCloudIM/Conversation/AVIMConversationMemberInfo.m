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

NSString * AVIMConversationMemberInfo_role_to_key(AVIMConversationMemberRole role)
{
    switch (role)
    {
        case AVIMConversationMemberRoleMember:
            return kAVIMConversationMemberRoleMember;
        case AVIMConversationMemberRoleManager:
            return kAVIMConversationMemberRoleManager;
        case AVIMConversationMemberRoleOwner:
            return kAVIMConversationMemberRoleOwner;
        default:
            return nil;
    }
}

AVIMConversationMemberRole AVIMConversationMemberInfo_key_to_role(kAVIMConversationMemberRole key)
{
    AVIMConversationMemberRole role = AVIMConversationMemberRoleMember;
    if ([key isEqualToString:kAVIMConversationMemberRoleMember]) {
        role = AVIMConversationMemberRoleMember;
    } else if ([key isEqualToString:kAVIMConversationMemberRoleManager]) {
        role = AVIMConversationMemberRoleManager;
    } else if ([key isEqualToString:kAVIMConversationMemberRoleOwner]) {
        role = AVIMConversationMemberRoleOwner;
    }
    return role;
}

@implementation AVIMConversationMemberInfo {
    __weak AVIMConversation *_conversation;
    NSMutableDictionary *_rawJSONData;
    NSLock *_lock;
}

+ (instancetype)new NS_UNAVAILABLE
{
    [NSException raise:NSInternalInconsistencyException
                format:@"This Method is Unavailable."];
    return nil;
}

- (instancetype)init NS_UNAVAILABLE
{
    [NSException raise:NSInternalInconsistencyException
                format:@"This Method is Unavailable."];
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
        value = [NSString lc__decodingDictionary:self->_rawJSONData key:kAVIMConversationMemberInfoKey_conversationId];
    }];
    return value;
}

- (NSString *)memberId
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        /*
         exist two key for member id. firstly decoding 'clientId', secondly decoding 'peerId'.
         */
        value = [NSString lc__decodingDictionary:self->_rawJSONData key:kAVIMConversationMemberInfoKey_memberId_1];
        if (!value) {
            value = [NSString lc__decodingDictionary:self->_rawJSONData key:kAVIMConversationMemberInfoKey_memberId_2];
        }
    }];
    return value;
}

- (AVIMConversationMemberRole)role
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString lc__decodingDictionary:self->_rawJSONData key:kAVIMConversationMemberInfoKey_role];
    }];
    return AVIMConversationMemberInfo_key_to_role(value);
}

- (BOOL)isOwner
{
    return [self->_conversation.creator isEqualToString:self.memberId];
}

@end
