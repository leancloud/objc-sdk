//
//  AVIMCommon_Internal.h
//  AVOS
//
//  Created by zapcannon87 on 2018/7/27.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"

/// { kAVIMUserOptionUseUnread: true } support unread notification feature. use `lc.protobuf2.3`
/// { kAVIMUserOptionUseUnread: false } not support unread notification feature. use `lc.protobuf2.1`
static NSString * const kAVIMUserOptionUseUnread = @"AVIMUserOptionUseUnread";

/// some limit
static NSUInteger const kClientIdLengthLimit = 64;
static NSString * const kClientTagDefault = @"default";
static NSString * const kTemporaryConversationIdPrefix = @"_tmp:";

/// ref: https://github.com/leancloud/avoscloud-push
typedef NS_OPTIONS(NSUInteger, LCIMSessionConfigOptions) {
    LCIMSessionConfigOptionsPatchMessage                        = 1 << 0,
    LCIMSessionConfigOptionsTemporaryConversationMessage        = 1 << 1,
    LCIMSessionConfigOptionsAutoBindDeviceidAndInstallation     = 1 << 2,
    LCIMSessionConfigOptionsTransientMessageACK                 = 1 << 3,
    LCIMSessionConfigOptionsNotification                        = 1 << 4,
    LCIMSessionConfigOptionsPartialFailedMessage                = 1 << 5,
    LCIMSessionConfigOptionsGroupChatRCP                        = 1 << 6,
};

/// conversation property key
typedef NSString * AVIMConversationKey NS_STRING_ENUM;
static AVIMConversationKey const AVIMConversationKeyObjectId                    = @"objectId";
static AVIMConversationKey const AVIMConversationKeyUniqueId                    = @"uniqueId";
static AVIMConversationKey const AVIMConversationKeyName                        = @"name";
static AVIMConversationKey const AVIMConversationKeyCreator                     = @"c";
static AVIMConversationKey const AVIMConversationKeyCreatedAt                   = @"createdAt";
static AVIMConversationKey const AVIMConversationKeyUpdatedAt                   = @"updatedAt";
static AVIMConversationKey const AVIMConversationKeyLastMessageAt               = @"lm";
static AVIMConversationKey const AVIMConversationKeyAttributes                  = @"attr";
static AVIMConversationKey const AVIMConversationKeyMembers                     = @"m";
static AVIMConversationKey const AVIMConversationKeyMutedMembers                = @"mu";
static AVIMConversationKey const AVIMConversationKeyUnique                      = @"unique";
static AVIMConversationKey const AVIMConversationKeyTransient                   = @"tr";
static AVIMConversationKey const AVIMConversationKeySystem                      = @"sys";
static AVIMConversationKey const AVIMConversationKeyTemporary                   = @"temp";
static AVIMConversationKey const AVIMConversationKeyTemporaryTTL                = @"ttl";
static AVIMConversationKey const AVIMConversationKeyConvType                    = @"conv_type";
static AVIMConversationKey const AVIMConversationKeyLastMessageContent          = @"msg";
static AVIMConversationKey const AVIMConversationKeyLastMessageId               = @"msg_mid";
static AVIMConversationKey const AVIMConversationKeyLastMessageFrom             = @"msg_from";
static AVIMConversationKey const AVIMConversationKeyLastMessageTimestamp        = @"msg_timestamp";
static AVIMConversationKey const AVIMConversationKeyLastMessagePatchTimestamp   = @"patch_timestamp";
static AVIMConversationKey const AVIMConversationKeyLastMessageBinary           = @"bin";
static AVIMConversationKey const AVIMConversationKeyLastMessageMentionAll       = @"mention_all";
static AVIMConversationKey const AVIMConversationKeyLastMessageMentionPids      = @"mention_pids";

/// Use this enum to match command's value(`convType`)
typedef NS_ENUM(NSUInteger, LCIMConvType) {
    LCIMConvTypeNormal      = 1,
    LCIMConvTypeTransient   = 2,
    LCIMConvTypeSystem      = 3,
    LCIMConvTypeTemporary   = 4,
};

typedef NSString * AVIMConversationMemberInfoKey NS_STRING_ENUM;
static AVIMConversationMemberInfoKey const AVIMConversationMemberInfoKeyConversationId  = @"cid";
static AVIMConversationMemberInfoKey const AVIMConversationMemberInfoKeyMemberId        = @"clientId";
static AVIMConversationMemberInfoKey const AVIMConversationMemberInfoKeyRole            = @"role";

typedef NSString * AVIMConversationMemberRoleKey NS_STRING_ENUM;
static AVIMConversationMemberRoleKey const AVIMConversationMemberRoleKeyMember      = @"Member";
static AVIMConversationMemberRoleKey const AVIMConversationMemberRoleKeyManager     = @"Manager";
static AVIMConversationMemberRoleKey const AVIMConversationMemberRoleKeyOwner       = @"Owner";
