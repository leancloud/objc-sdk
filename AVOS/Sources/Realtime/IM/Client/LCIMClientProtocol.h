//
//  LCIMClientProtocol.h
//  LeanCloud
//
//  Created by ZapCannon87 on 2018/7/24.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "LCIMCommon.h"

@class LCIMClient;
@class LCIMConversation;
@class LCIMMessage;
@class LCIMMessagePatchedReason;
@class LCIMTypedMessage;
@class LCIMRecalledMessage;

NS_ASSUME_NONNULL_BEGIN

/// This protocol defines methods to handle the events about client, conversation, message and so on.
@protocol LCIMClientDelegate <NSObject>

@optional

// MARK: Client

/// Client paused, means the connection lost.
///
/// Common Scenario:
///     * Network unreachable or interface changed.
///     * App enter background
///     * ...
///
/// @param imClient The client.
/// @param error The reason for pause.
- (void)imClientPaused:(LCIMClient *)imClient error:(NSError * _Nullable)error;

/// Client in resuming, invoked when the client try recover connection automatically.
/// @param imClient The client.
- (void)imClientResuming:(LCIMClient *)imClient;

/// Client resumed, means the client recover connection successfully.
/// @param imClient The client.
- (void)imClientResumed:(LCIMClient *)imClient;

/// Client closed and will not try recover connection automatically.
///
/// Common Scenario:
///     * code: `4111`, reason: `SESSION_CONFLICT`
///     * code: `4115`, reason: `KICKED_BY_APP`
///
/// @param imClient The client.
/// @param error The reason for close.
- (void)imClientClosed:(LCIMClient *)imClient error:(NSError * _Nullable)error;

// MARK: Conversation

/*!
 接收到新的普通消息。
 @param conversation － 所属对话
 @param message - 具体的消息
 */
- (void)conversation:(LCIMConversation *)conversation didReceiveCommonMessage:(LCIMMessage *)message;

/*!
 接收到新的富媒体消息。
 @param conversation － 所属对话
 @param message - 具体的消息
 */
- (void)conversation:(LCIMConversation *)conversation didReceiveTypedMessage:(LCIMTypedMessage *)message;

/*!
 消息已投递给对方。
 @param conversation － 所属对话
 @param message - 具体的消息
 */
- (void)conversation:(LCIMConversation *)conversation messageDelivered:(LCIMMessage *)message;

/// Invoking when the sent message has been updated.
/// @param conversation The conversation which the sent message belongs to.
/// @param message The updated message.
/// @param reason The reason when the message was forced to be modified by the server.
- (void)conversation:(LCIMConversation *)conversation messageHasBeenUpdated:(LCIMMessage *)message reason:(LCIMMessagePatchedReason * _Nullable)reason;

/// Invoking when the sent message has been recalled.
/// @param conversation The conversation which the sent message belongs to.
/// @param message The recalled message.
/// @param reason The reason when the message was forced to be modified by the server.
- (void)conversation:(LCIMConversation *)conversation messageHasBeenRecalled:(LCIMRecalledMessage *)message reason:(LCIMMessagePatchedReason * _Nullable)reason;

/*!
 对话中有新成员加入时所有成员都会收到这一通知。
 @param conversation － 所属对话
 @param clientIds - 加入的新成员列表
 @param clientId - 邀请者的 id
 */
- (void)conversation:(LCIMConversation *)conversation membersAdded:(NSArray<NSString *> * _Nullable)clientIds byClientId:(NSString * _Nullable)clientId;

/*!
 对话中有成员离开时所有剩余成员都会收到这一通知。
 @param conversation － 所属对话
 @param clientIds - 离开的成员列表
 @param clientId - 操作者的 id
 */
- (void)conversation:(LCIMConversation *)conversation membersRemoved:(NSArray<NSString *> * _Nullable)clientIds byClientId:(NSString * _Nullable)clientId;

/*!
 当前用户被邀请加入对话的通知。
 @param conversation － 所属对话
 @param clientId - 邀请者的 id
 */
- (void)conversation:(LCIMConversation *)conversation invitedByClientId:(NSString * _Nullable)clientId;

/*!
 当前用户被踢出对话的通知。
 @param conversation － 所属对话
 @param clientId - 操作者的 id
 */
- (void)conversation:(LCIMConversation *)conversation kickedByClientId:(NSString * _Nullable)clientId;

/*!
 Notification for conversation property update.
 You can use this method to handle the properties that will be updated dynamicly during conversation's lifetime,
 for example, unread message count, last message and receipt timestamp, etc.
 
 @param conversation The updated conversation.
 @param key          The property name of updated conversation.
 */
- (void)conversation:(LCIMConversation *)conversation didUpdateForKey:(LCIMConversationUpdatedKey)key;

/// Notification for conversation's attribution updated.
/// @param conversation Updated conversation.
/// @param date Updated date.
/// @param clientId Client ID which do this update.
/// @param updatedData Updated data.
/// @param updatingData Updating data.
- (void)conversation:(LCIMConversation *)conversation didUpdateAt:(NSDate * _Nullable)date byClientId:(NSString * _Nullable)clientId updatedData:(NSDictionary * _Nullable)updatedData updatingData:(NSDictionary * _Nullable)updatingData;

/**
 Notification for conversation's member info updated.
 
 @param conversation Updated conversation.
 @param byClientId Client ID of doing update.
 @param memberId Client ID of being updated.
 @param role Updated role.
 */
- (void)conversation:(LCIMConversation *)conversation didMemberInfoUpdateBy:(NSString * _Nullable)byClientId memberId:(NSString * _Nullable)memberId role:(LCIMConversationMemberRole)role;

/**
 Notification for this client was blocked by other client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who blocking this client.
 */
- (void)conversation:(LCIMConversation *)conversation didBlockBy:(NSString * _Nullable)byClientId;

/**
 Notification for this client was Unblocked by other client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who unblocking this client.
 */
- (void)conversation:(LCIMConversation *)conversation didUnblockBy:(NSString * _Nullable)byClientId;

/**
 Notification for some other clients was blocked by a client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who blocking these clients.
 @param memberIds Being blocked clients's ID array.
 */
- (void)conversation:(LCIMConversation *)conversation didMembersBlockBy:(NSString * _Nullable)byClientId memberIds:(NSArray<NSString *> * _Nullable)memberIds;

/**
 Notification for some other clients was unblocked by a client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who unblocking these clients.
 @param memberIds Being unblocked clients's ID array.
 */
- (void)conversation:(LCIMConversation *)conversation didMembersUnblockBy:(NSString * _Nullable)byClientId memberIds:(NSArray<NSString *> * _Nullable)memberIds;

/**
 Notification for this client was muted by other client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who muting this client.
 */
- (void)conversation:(LCIMConversation *)conversation didMuteBy:(NSString * _Nullable)byClientId;

/**
 Notification for this client was Unmuted by other client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who unmuting this client.
 */
- (void)conversation:(LCIMConversation *)conversation didUnmuteBy:(NSString * _Nullable)byClientId;

/**
 Notification for some other clients was muted by a client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who muted these clients.
 @param memberIds Being muted clients's ID array.
 */
- (void)conversation:(LCIMConversation *)conversation didMembersMuteBy:(NSString * _Nullable)byClientId memberIds:(NSArray<NSString *> * _Nullable)memberIds;

/**
 Notification for some other clients was unmuted by a client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who unmuting these clients.
 @param memberIds Being unmuting clients's ID array.
 */
- (void)conversation:(LCIMConversation *)conversation didMembersUnmuteBy:(NSString * _Nullable)byClientId memberIds:(NSArray<NSString *> * _Nullable)memberIds;

@end

NS_ASSUME_NONNULL_END
