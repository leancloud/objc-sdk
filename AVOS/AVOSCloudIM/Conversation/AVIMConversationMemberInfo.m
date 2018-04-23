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

NSString * const kAVIMConversationMemberRoleMember_string = @"Member";
NSString * const kAVIMConversationMemberRoleManager_string = @"Manager";

NSString * AVIMConversationMemberInfo_StringFromRole(AVIMConversationMemberRole role)
{
    switch (role) {
        case AVIMConversationMemberRoleMember:
            return kAVIMConversationMemberRoleMember_string;
        case AVIMConversationMemberRoleManager:
            return kAVIMConversationMemberRoleManager_string;
        default:
            return nil;
    }
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

- (instancetype)initWithJSON:(NSDictionary *)JSON conversation:(AVIMConversation *)conversation
{
    self = [super init];
    
    if (self) {
        
        _rawJSONData = JSON.mutableCopy ?: [NSMutableDictionary dictionary];
        
        _conversation = conversation;
        
        _lock = [[NSLock alloc] init];
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
        
        value = [NSString lc__decodingDictionary:self->_rawJSONData key:@"cid"];
    }];
    
    return value;
}

- (NSString *)memberId
{
    __block NSString *value = nil;
    
    [self internalSyncLock:^{
        
        /*
         exist two key for member id.
         */
        
        value = [NSString lc__decodingDictionary:self->_rawJSONData key:@"clientId"];
        
        if (!value) {
            
            value = [NSString lc__decodingDictionary:self->_rawJSONData key:@"peerId"];
        }
    }];
    
    return value;
}

- (AVIMConversationMemberRole)role
{
    __block NSString *value = nil;
    
    [self internalSyncLock:^{
        
        value = [NSString lc__decodingDictionary:self->_rawJSONData key:@"role"];
    }];
    
    AVIMConversationMemberRole role = AVIMConversationMemberRoleMember;
    
    if ([value isEqualToString:kAVIMConversationMemberRoleMember_string]) {
        
        role = AVIMConversationMemberRoleMember;
    }
    else if ([value isEqualToString:kAVIMConversationMemberRoleManager_string]) {
        
        role = AVIMConversationMemberRoleManager;
    }
    
    return role;
}

- (BOOL)isOwner
{
    AVIMConversation *conversation = self->_conversation;
    
    if (!conversation) {
        
        return false;
    }
    
    return [conversation.creator isEqualToString:self.memberId] ? true : false;
}

@end
