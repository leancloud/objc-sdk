//
//  AVIMClientProtocol.h
//  AVOS
//
//  Created by ZapCannon87 on 2018/7/24.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"

@class AVIMClient;
@class AVIMConversation;
@class AVIMMessage;
@class AVIMTypedMessage;

NS_ASSUME_NONNULL_BEGIN

/// this protocol defines methods to handle the events about client, conversation, message and so on.
@protocol AVIMClientDelegate <NSObject>

// MARK: - Required

/**
 
 Client Paused.
 
 Common Scenario:
 
 1. Network Unreachable
 
 2. iOS App in Background
 
 3. ... ...
 
 Client will Auto Resuming if environment become Normal.
 
 @param imClient imClient
 */
- (void)imClientPaused:(AVIMClient *)imClient;

/**
 
 Client is Resuming.
 
 Common Scenario:
 
 1. Network from Unreachable to Reachable
 
 2. iOS App from Background to Foreground
 
 3. ... ...
 
 Client is Resuming the Session.
 
 @param imClient imClient
 */
- (void)imClientResuming:(AVIMClient *)imClient;

/**
 Client is Resumed from Paused Status and now its Status is Opened.
 
 @param imClient imClient
 */
- (void)imClientResumed:(AVIMClient *)imClient;

/**
 Client Closed with an Error and will not resume.
 
 @param imClient imClient
 @param error Something Wrong
 */
- (void)imClientClosed:(AVIMClient *)imClient error:(NSError * _Nullable)error;

// MARK: - Optional

@optional

/*!
 客户端下线通知。
 @param client 已下线的 client。
 @param error 错误信息。
 */
- (void)client:(AVIMClient *)client didOfflineWithError:(NSError * _Nullable)error;

/*!
 接收到新的普通消息。
 @param conversation － 所属对话
 @param message - 具体的消息
 */
- (void)conversation:(AVIMConversation *)conversation didReceiveCommonMessage:(AVIMMessage *)message;

/*!
 接收到新的富媒体消息。
 @param conversation － 所属对话
 @param message - 具体的消息
 */
- (void)conversation:(AVIMConversation *)conversation didReceiveTypedMessage:(AVIMTypedMessage *)message;

/*!
 消息已投递给对方。
 @param conversation － 所属对话
 @param message - 具体的消息
 */
- (void)conversation:(AVIMConversation *)conversation messageDelivered:(AVIMMessage *)message;

/**
 Invoking when the sent message has been updated.
 
 @param conversation The conversation which the sent message belongs to.
 @param message      The updated message.
 */
- (void)conversation:(AVIMConversation *)conversation messageHasBeenUpdated:(AVIMMessage *)message;

/*!
 对话中有新成员加入时所有成员都会收到这一通知。
 @param conversation － 所属对话
 @param clientIds - 加入的新成员列表
 @param clientId - 邀请者的 id
 */
- (void)conversation:(AVIMConversation *)conversation membersAdded:(NSArray<NSString *> * _Nullable)clientIds byClientId:(NSString * _Nullable)clientId;

/*!
 对话中有成员离开时所有剩余成员都会收到这一通知。
 @param conversation － 所属对话
 @param clientIds - 离开的成员列表
 @param clientId - 操作者的 id
 */
- (void)conversation:(AVIMConversation *)conversation membersRemoved:(NSArray<NSString *> * _Nullable)clientIds byClientId:(NSString * _Nullable)clientId;

/*!
 当前用户被邀请加入对话的通知。
 @param conversation － 所属对话
 @param clientId - 邀请者的 id
 */
- (void)conversation:(AVIMConversation *)conversation invitedByClientId:(NSString * _Nullable)clientId;

/*!
 当前用户被踢出对话的通知。
 @param conversation － 所属对话
 @param clientId - 操作者的 id
 */
- (void)conversation:(AVIMConversation *)conversation kickedByClientId:(NSString * _Nullable)clientId;

/*!
 Notification for conversation property update.
 You can use this method to handle the properties that will be updated dynamicly during conversation's lifetime,
 for example, unread message count, last message and receipt timestamp, etc.
 
 @param conversation The updated conversation.
 @param key          The property name of updated conversation.
 */
- (void)conversation:(AVIMConversation *)conversation didUpdateForKey:(AVIMConversationUpdatedKey)key;

/**
 Notification for conversation's attribution updated.
 
 @param conversation Updated conversation.
 @param date Updated date.
 @param clientId Client ID of doing updates.
 @param data Updated data.
 */
- (void)conversation:(AVIMConversation *)conversation didUpdateAt:(NSDate * _Nullable)date byClientId:(NSString * _Nullable)clientId updatedData:(NSDictionary * _Nullable)data;

/**
 Notification for conversation's member info updated.
 
 @param conversation Updated conversation.
 @param byClientId Client ID of doing update.
 @param memberId Client ID of being updated.
 @param role Updated role.
 */
- (void)conversation:(AVIMConversation *)conversation didMemberInfoUpdateBy:(NSString * _Nullable)byClientId memberId:(NSString * _Nullable)memberId role:(AVIMConversationMemberRole)role;

/**
 Notification for this client was blocked by other client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who blocking this client.
 */
- (void)conversation:(AVIMConversation *)conversation didBlockBy:(NSString * _Nullable)byClientId;

/**
 Notification for this client was Unblocked by other client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who unblocking this client.
 */
- (void)conversation:(AVIMConversation *)conversation didUnblockBy:(NSString * _Nullable)byClientId;

/**
 Notification for some other clients was blocked by a client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who blocking these clients.
 @param memberIds Being blocked clients's ID array.
 */
- (void)conversation:(AVIMConversation *)conversation didMembersBlockBy:(NSString * _Nullable)byClientId memberIds:(NSArray<NSString *> * _Nullable)memberIds;

/**
 Notification for some other clients was unblocked by a client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who unblocking these clients.
 @param memberIds Being unblocked clients's ID array.
 */
- (void)conversation:(AVIMConversation *)conversation didMembersUnblockBy:(NSString * _Nullable)byClientId memberIds:(NSArray<NSString *> * _Nullable)memberIds;

/**
 Notification for this client was muted by other client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who muting this client.
 */
- (void)conversation:(AVIMConversation *)conversation didMuteBy:(NSString * _Nullable)byClientId;

/**
 Notification for this client was Unmuted by other client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who unmuting this client.
 */
- (void)conversation:(AVIMConversation *)conversation didUnmuteBy:(NSString * _Nullable)byClientId;

/**
 Notification for some other clients was muted by a client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who muted these clients.
 @param memberIds Being muted clients's ID array.
 */
- (void)conversation:(AVIMConversation *)conversation didMembersMuteBy:(NSString * _Nullable)byClientId memberIds:(NSArray<NSString *> * _Nullable)memberIds;

/**
 Notification for some other clients was unmuted by a client in the conversation.
 
 @param conversation Conversation.
 @param byClientId Who unmuting these clients.
 @param memberIds Being unmuting clients's ID array.
 */
- (void)conversation:(AVIMConversation *)conversation didMembersUnmuteBy:(NSString * _Nullable)byClientId memberIds:(NSArray<NSString *> * _Nullable)memberIds;

/**
 *  当前聊天状态被暂停，常见于网络断开时触发。
 *  注意：该回调会覆盖 imClientPaused: 方法。
 *  @param imClient 相应的 imClient
 *  @param error    具体错误信息
 */
- (void)imClientPaused:(AVIMClient *)imClient error:(NSError *)error __deprecated_msg("deprecated. use -[imClientClosed:error:] instead.");

/*!
 收到未读通知。在该终端上线的时候，服务器会将对话的未读数发送过来。未读数可通过 -[AVIMConversation markAsReadInBackground] 清零，服务端不会自动清零。
 @param conversation 所属会话。
 @param unread 未读消息数量。
 */
- (void)conversation:(AVIMConversation *)conversation didReceiveUnread:(NSInteger)unread __deprecated_msg("deprecated. use -[conversation:didUpdateForKey:] instead.");

@end

NS_ASSUME_NONNULL_END
