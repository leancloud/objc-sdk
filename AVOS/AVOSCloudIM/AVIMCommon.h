//
//  AVIMCommon.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVOSCloud/AVOSCloud.h>

@class AVIMConversation;
@class AVIMChatRoom;
@class AVIMTemporaryConversation;

NS_ASSUME_NONNULL_BEGIN

// MARK: - Error

/// error code
typedef NS_ENUM(NSInteger, AVIMErrorCode) {
    /// 41XX
    AVIMErrorCodeSessionConflict = 4111,
    AVIMErrorCodeSessionTokenExpired = 4112,
    /// 90XX
    AVIMErrorCodeCommandTimeout = 9000,
    AVIMErrorCodeConnectionLost = 9001,
    AVIMErrorCodeClientNotOpen = 9002,
    AVIMErrorCodeInvalidCommand = 9003,
    AVIMErrorCodeCommandDataLengthTooLong = 9008,
    /// 91XX
    AVIMErrorCodeConversationNotFound = 9100,
    AVIMErrorCodeUpdatingMessageNotAllowed = 9120,
    AVIMErrorCodeUpdatingMessageNotSent = 9121,
    AVIMErrorCodeOwnerPromotionNotAllowed = 9130,
};

/// error user info key
FOUNDATION_EXPORT NSString * const kAVIMCodeKey;
FOUNDATION_EXPORT NSString * const kAVIMAppCodeKey;
FOUNDATION_EXPORT NSString * const kAVIMReasonKey;
FOUNDATION_EXPORT NSString * const kAVIMDetailKey;

// MARK: - Client

/// client status
typedef NS_ENUM(NSUInteger, AVIMClientStatus) {
    AVIMClientStatusNone = 0,
    AVIMClientStatusOpening = 1,
    AVIMClientStatusOpened = 2,
    AVIMClientStatusPaused = 3,
    AVIMClientStatusResuming = 4,
    AVIMClientStatusClosing = 5,
    AVIMClientStatusClosed = 6,
};

/// open option for client
typedef NS_ENUM(NSUInteger, AVIMClientOpenOption) {
    /// Default Option.
    /// if seted 'tag', then use 'ForceOpen' to open client, this will let other clients(has the same ID and Tag) to be kicked or can't reopen, and now only this client online.
    /// if not seted 'tag', open client with this option is just a normal open action, it will not kick other client.
    AVIMClientOpenOptionForceOpen = 0,
    /// if seted 'tag', then use 'Reopen' option to open client, if client has not been kicked, it can be opened, else if client has been kicked, it can't be opened.
    /// if not seted 'tag', open client with this option is just a normal open action, it will not be kicked by other client.
    AVIMClientOpenOptionReopen = 1,
};

// MARK: - Conversation

/// option for create conversation
typedef NS_OPTIONS(uint64_t, AVIMConversationOption) {
    /// Default conversation. At most allow 500 people to join the conversation.
    AVIMConversationOptionNone = 0,
    /// Unique conversation. If the server detects the conversation with that members exists, will return it instead of creating a new one.
    AVIMConversationOptionUnique = 1 << 0,
    /// Transient conversation. No headcount limits. But the functionality is limited. No offline messages, no offline notifications, etc.
    AVIMConversationOptionTransient = 1 << 1,
    /// Temporary conversation
    AVIMConversationOptionTemporary = 1 << 2,
};

/// key for updated property of conversation
typedef NSString * const AVIMConversationUpdatedKey NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastMessage;
FOUNDATION_EXPORT AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastMessageAt;
FOUNDATION_EXPORT AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastReadAt;
FOUNDATION_EXPORT AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastDeliveredAt;
FOUNDATION_EXPORT AVIMConversationUpdatedKey AVIMConversationUpdatedKeyUnreadMessagesCount;
FOUNDATION_EXPORT AVIMConversationUpdatedKey AVIMConversationUpdatedKeyUnreadMessagesMentioned;

/// Conversation Member Role.
typedef NS_ENUM(NSUInteger, AVIMConversationMemberRole) {
    /// Privilege: Owner > Manager > Member
    AVIMConversationMemberRoleMember = 0,
    AVIMConversationMemberRoleManager = 1,
    AVIMConversationMemberRoleOwner = 2,
};

// MARK: - Query

/// Query Option
typedef NS_OPTIONS(uint64_t, AVIMConversationQueryOption) {
    AVIMConversationQueryOptionNone = 0,
    AVIMConversationQueryOptionCompact = 1 << 0, /**< 不返回成员列表 */
    AVIMConversationQueryOptionWithMessage = 1 << 1, /**< 返回对话最近一条消息 */
};

/// Cache policy
typedef NS_ENUM(NSUInteger, AVIMCachePolicy) {
    /// Query from server and do not save result to local cache.
    kAVIMCachePolicyIgnoreCache = 0,
    /// Only query from local cache.
    kAVIMCachePolicyCacheOnly = 1,
    /// Only query from server, and save result to local cache.
    kAVIMCachePolicyNetworkOnly = 2,
    /// Firstly query from local cache, if fails, query from server.
    kAVIMCachePolicyCacheElseNetwork = 3,
    /// Firstly query from server, if fails, query local cache.
    kAVIMCachePolicyNetworkElseCache = 4,
    /// Firstly query from local cache, then query from server. The callback will be called twice.
    kAVIMCachePolicyCacheThenNetwork = 5,
};

// MARK: - Message

/// Enumerations that define message query direction.
typedef NS_ENUM(NSUInteger, AVIMMessageQueryDirection) {
    AVIMMessageQueryDirectionFromNewToOld = 0,
    AVIMMessageQueryDirectionFromOldToNew = 1,
};

// MARK: - Signature

/// Signature Action
typedef NSString * const AVIMSignatureAction NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT AVIMSignatureAction AVIMSignatureActionOpen;
FOUNDATION_EXPORT AVIMSignatureAction AVIMSignatureActionStart;
FOUNDATION_EXPORT AVIMSignatureAction AVIMSignatureActionAdd;
FOUNDATION_EXPORT AVIMSignatureAction AVIMSignatureActionRemove;
FOUNDATION_EXPORT AVIMSignatureAction AVIMSignatureActionBlock;
FOUNDATION_EXPORT AVIMSignatureAction AVIMSignatureActionUnblock;

// MARK: - Deprecated

typedef void(^AVIMBooleanResultBlock)(BOOL, NSError * _Nullable);
typedef void(^AVIMIntegerResultBlock)(NSInteger, NSError * _Nullable);
typedef void(^AVIMArrayResultBlock)(NSArray * _Nullable, NSError * _Nullable);
typedef void(^AVIMConversationResultBlock)(AVIMConversation * _Nullable, NSError * _Nullable);
typedef void(^AVIMChatRoomResultBlock)(AVIMChatRoom * _Nullable, NSError * _Nullable);
typedef void(^AVIMTemporaryConversationResultBlock)(AVIMTemporaryConversation * _Nullable, NSError * _Nullable);
typedef void(^AVIMProgressBlock)(NSInteger);

FOUNDATION_EXPORT NSString * const AVIMUserOptionUseUnread __deprecated_msg("deprecated. use +[AVIMClient setUnreadNotificationEnabled:] instead.");
FOUNDATION_EXPORT NSString * const AVIMUserOptionCustomProtocols __deprecated_msg("deprecated. do not use it any more.");

typedef uint64_t AVIMMessageSendOption __deprecated_msg("deprecated. use AVIMMessageOption instead.");
enum : AVIMMessageSendOption {
    AVIMMessageSendOptionNone = 0,
    AVIMMessageSendOptionTransient = 1 << 0,
    AVIMMessageSendOptionRequestReceipt = 1 << 1,
} __deprecated_msg("deprecated. use AVIMMessageOption instead.");

NS_ASSUME_NONNULL_END
