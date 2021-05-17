//
//  LCIMCommon.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "Foundation.h"

@class LCIMConversation;
@class LCIMChatRoom;
@class LCIMTemporaryConversation;

NS_ASSUME_NONNULL_BEGIN

// MARK: Error

/// error code
typedef NS_ENUM(NSInteger, LCIMErrorCode) {
    /// 41XX
    LCIMErrorCodeSessionConflict            = 4111,
    LCIMErrorCodeSessionTokenExpired        = 4112,
    /// 90XX
    LCIMErrorCodeCommandTimeout             = 9000,
    LCIMErrorCodeConnectionLost             = 9001,
    LCIMErrorCodeClientNotOpen              = 9002,
    LCIMErrorCodeInvalidCommand             = 9003,
    LCIMErrorCodeCommandDataLengthTooLong   = 9008,
    /// 91XX
    LCIMErrorCodeConversationNotFound       = 9100,
    LCIMErrorCodeUpdatingMessageNotAllowed  = 9120,
    LCIMErrorCodeUpdatingMessageNotSent     = 9121,
    LCIMErrorCodeOwnerPromotionNotAllowed   = 9130,
};

/// error user info key
FOUNDATION_EXPORT NSString * const kLCIMCodeKey;
FOUNDATION_EXPORT NSString * const kLCIMAppCodeKey;
FOUNDATION_EXPORT NSString * const kLCIMAppMsgKey;
FOUNDATION_EXPORT NSString * const kLCIMReasonKey;
FOUNDATION_EXPORT NSString * const kLCIMDetailKey;

// MARK: Client

/// client status
typedef NS_ENUM(NSUInteger, LCIMClientStatus) {
    LCIMClientStatusNone        = 0,
    LCIMClientStatusOpening     = 1,
    LCIMClientStatusOpened      = 2,
    LCIMClientStatusPaused      = 3,
    LCIMClientStatusResuming    = 4,
    LCIMClientStatusClosing     = 5,
    LCIMClientStatusClosed      = 6,
};

/// open option for client
typedef NS_ENUM(NSUInteger, LCIMClientOpenOption) {
    /// Default Option.
    /// if seted 'tag', then use 'ForceOpen' to open client, this will let other clients(has the same ID and Tag) to be kicked or can't reopen, and now only this client online.
    /// if not seted 'tag', open client with this option is just a normal open action, it will not kick other client.
    LCIMClientOpenOptionForceOpen   = 0,
    /// if seted 'tag', then use 'Reopen' option to open client, if client has not been kicked, it can be opened, else if client has been kicked, it can't be opened.
    /// if not seted 'tag', open client with this option is just a normal open action, it will not be kicked by other client.
    LCIMClientOpenOptionReopen      = 1,
};

// MARK: Conversation

/// key for updated property of conversation
typedef NSString * LCIMConversationUpdatedKey NS_STRING_ENUM;
FOUNDATION_EXPORT LCIMConversationUpdatedKey const LCIMConversationUpdatedKeyLastMessage;
FOUNDATION_EXPORT LCIMConversationUpdatedKey const LCIMConversationUpdatedKeyLastMessageAt;
FOUNDATION_EXPORT LCIMConversationUpdatedKey const LCIMConversationUpdatedKeyLastReadAt;
FOUNDATION_EXPORT LCIMConversationUpdatedKey const LCIMConversationUpdatedKeyLastDeliveredAt;
FOUNDATION_EXPORT LCIMConversationUpdatedKey const LCIMConversationUpdatedKeyUnreadMessagesCount;
FOUNDATION_EXPORT LCIMConversationUpdatedKey const LCIMConversationUpdatedKeyUnreadMessagesMentioned;

/// Conversation Member Role.
typedef NS_ENUM(NSUInteger, LCIMConversationMemberRole) {
    /// Privilege: Owner > Manager > Member
    LCIMConversationMemberRoleMember    = 0,
    LCIMConversationMemberRoleManager   = 1,
    LCIMConversationMemberRoleOwner     = 2,
};

// MARK: Query

/// Query Option
typedef NS_OPTIONS(uint64_t, LCIMConversationQueryOption) {
    /// Default.
    LCIMConversationQueryOptionNone         = 0,
    /// Conversation without members.
    LCIMConversationQueryOptionCompact      = 1 << 0,
    /// Conversation with last message.
    LCIMConversationQueryOptionWithMessage  = 1 << 1,
};

/// Cache policy
typedef NS_ENUM(NSUInteger, LCIMCachePolicy) {
    /// Query from server and do not save result to local cache.
    kLCIMCachePolicyIgnoreCache         = 0,
    /// Only query from local cache.
    kLCIMCachePolicyCacheOnly           = 1,
    /// Only query from server, and save result to local cache.
    kLCIMCachePolicyNetworkOnly         = 2,
    /// Firstly query from local cache, if fails, query from server.
    kLCIMCachePolicyCacheElseNetwork    = 3,
    /// Firstly query from server, if fails, query local cache.
    kLCIMCachePolicyNetworkElseCache    = 4,
    /// Firstly query from local cache, then query from server. The callback will be called twice.
    kLCIMCachePolicyCacheThenNetwork    = 5,
};

// MARK: Message

/// Enumerations that define message query direction.
typedef NS_ENUM(NSUInteger, LCIMMessageQueryDirection) {
    LCIMMessageQueryDirectionFromNewToOld = 0,
    LCIMMessageQueryDirectionFromOldToNew = 1,
};

// MARK: Signature

/// Signature Action
typedef NSString * LCIMSignatureAction NS_STRING_ENUM;
FOUNDATION_EXPORT LCIMSignatureAction const LCIMSignatureActionOpen;
FOUNDATION_EXPORT LCIMSignatureAction const LCIMSignatureActionStart;
FOUNDATION_EXPORT LCIMSignatureAction const LCIMSignatureActionAdd;
FOUNDATION_EXPORT LCIMSignatureAction const LCIMSignatureActionRemove;
FOUNDATION_EXPORT LCIMSignatureAction const LCIMSignatureActionBlock;
FOUNDATION_EXPORT LCIMSignatureAction const LCIMSignatureActionUnblock;

// MARK: Misc

typedef void(^LCIMBooleanResultBlock)(BOOL, NSError * _Nullable);
typedef void(^LCIMIntegerResultBlock)(NSInteger, NSError * _Nullable);
typedef void(^LCIMArrayResultBlock)(NSArray * _Nullable, NSError * _Nullable);
typedef void(^LCIMConversationResultBlock)(LCIMConversation * _Nullable, NSError * _Nullable);
typedef void(^LCIMChatRoomResultBlock)(LCIMChatRoom * _Nullable, NSError * _Nullable);
typedef void(^LCIMTemporaryConversationResultBlock)(LCIMTemporaryConversation * _Nullable, NSError * _Nullable);
typedef void(^LCIMProgressBlock)(NSInteger);

NS_ASSUME_NONNULL_END
