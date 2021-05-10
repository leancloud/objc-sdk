//
//  LCIMCommon_Internal.h
//  LeanCloud
//
//  Created by zapcannon87 on 2018/7/27.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "LCIMCommon.h"

/// { kLCIMUserOptionUseUnread: true } support unread notification feature. use `lc.protobuf2.3`
/// { kLCIMUserOptionUseUnread: false } not support unread notification feature. use `lc.protobuf2.1`
static NSString * const kLCIMUserOptionUseUnread = @"LCIMUserOptionUseUnread";

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
    LCIMSessionConfigOptionsOmitPeerID                          = 1 << 7,
};

/// conversation property key
typedef NSString * LCIMConversationKey NS_STRING_ENUM;
static LCIMConversationKey const LCIMConversationKeyObjectId                    = @"objectId";
static LCIMConversationKey const LCIMConversationKeyUniqueId                    = @"uniqueId";
static LCIMConversationKey const LCIMConversationKeyName                        = @"name";
static LCIMConversationKey const LCIMConversationKeyCreator                     = @"c";
static LCIMConversationKey const LCIMConversationKeyCreatedAt                   = @"createdAt";
static LCIMConversationKey const LCIMConversationKeyUpdatedAt                   = @"updatedAt";
static LCIMConversationKey const LCIMConversationKeyLastMessageAt               = @"lm";
static LCIMConversationKey const LCIMConversationKeyAttributes                  = @"attr";
static LCIMConversationKey const LCIMConversationKeyMembers                     = @"m";
static LCIMConversationKey const LCIMConversationKeyMutedMembers                = @"mu";
static LCIMConversationKey const LCIMConversationKeyUnique                      = @"unique";
static LCIMConversationKey const LCIMConversationKeyTransient                   = @"tr";
static LCIMConversationKey const LCIMConversationKeySystem                      = @"sys";
static LCIMConversationKey const LCIMConversationKeyTemporary                   = @"temp";
static LCIMConversationKey const LCIMConversationKeyTemporaryTTL                = @"ttl";
static LCIMConversationKey const LCIMConversationKeyConvType                    = @"conv_type";
static LCIMConversationKey const LCIMConversationKeyLastMessageContent          = @"msg";
static LCIMConversationKey const LCIMConversationKeyLastMessageId               = @"msg_mid";
static LCIMConversationKey const LCIMConversationKeyLastMessageFrom             = @"msg_from";
static LCIMConversationKey const LCIMConversationKeyLastMessageTimestamp        = @"msg_timestamp";
static LCIMConversationKey const LCIMConversationKeyLastMessagePatchTimestamp   = @"patch_timestamp";
static LCIMConversationKey const LCIMConversationKeyLastMessageBinary           = @"bin";
static LCIMConversationKey const LCIMConversationKeyLastMessageMentionAll       = @"mention_all";
static LCIMConversationKey const LCIMConversationKeyLastMessageMentionPids      = @"mention_pids";

/// Use this enum to match command's value(`convType`)
typedef NS_ENUM(NSUInteger, LCIMConvType) {
    LCIMConvTypeUnknown     = 0,
    LCIMConvTypeNormal      = 1,
    LCIMConvTypeTransient   = 2,
    LCIMConvTypeSystem      = 3,
    LCIMConvTypeTemporary   = 4,
};

typedef NSString * LCIMConversationMemberInfoKey NS_STRING_ENUM;
static LCIMConversationMemberInfoKey const LCIMConversationMemberInfoKeyConversationId  = @"cid";
static LCIMConversationMemberInfoKey const LCIMConversationMemberInfoKeyMemberId        = @"clientId";
static LCIMConversationMemberInfoKey const LCIMConversationMemberInfoKeyRole            = @"role";

typedef NSString * LCIMConversationMemberRoleKey NS_STRING_ENUM;
static LCIMConversationMemberRoleKey const LCIMConversationMemberRoleKeyMember      = @"Member";
static LCIMConversationMemberRoleKey const LCIMConversationMemberRoleKeyManager     = @"Manager";
static LCIMConversationMemberRoleKey const LCIMConversationMemberRoleKeyOwner       = @"Owner";
