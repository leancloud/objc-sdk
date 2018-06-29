//
//  AVIM.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMAvailability.h"
#import "AVIMCommon.h"
#import "AVIMSignature.h"
#import "AVIMConversationMemberInfo.h"

@class AVIMConversation;
@class AVIMKeyedConversation;
@class AVIMMessage;
@class AVIMTypedMessage;
@class AVIMConversationQuery;
@class AVUser;

@protocol AVIMClientDelegate;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, AVIMClientStatus) {
    AVIMClientStatusNone = 0,
    AVIMClientStatusOpening,
    AVIMClientStatusOpened,
    AVIMClientStatusPaused,
    AVIMClientStatusResuming,
    AVIMClientStatusClosing,
    AVIMClientStatusClosed
};

typedef NS_ENUM(NSUInteger, AVIMClientOpenOption) {
    /*
     Default Option.
     if seted 'tag', then use 'ForceOpen' to open client, this will let other clients(has the same ID and Tag) to be kicked or can't reopen, and now only this client online.
     if not seted 'tag', open client with this option is just a normal open action, it will not kick other client.
     */
    AVIMClientOpenOptionForceOpen = 0,
    /*
     if seted 'tag', then use 'Reopen' option to open client, if client has not been kicked, it can be opened, else if client has been kicked, it can't be opened.
     if not seted 'tag', open client with this option is just a normal open action, it will not be kicked by other client.
     */
    AVIMClientOpenOptionReopen
};

typedef NS_OPTIONS(uint64_t, AVIMConversationOption) {
    /*
     Default conversation. At most allow 500 people to join the conversation.
     */
    AVIMConversationOptionNone = 0,
    /*
     Unique conversation. If the server detects the conversation with that members exists, will return it instead of creating a new one.
     */
    AVIMConversationOptionUnique = 1 << 0,
    /*
     Transient conversation. No headcount limits. But the functionality is limited. No offline messages, no offline notifications, etc.
     */
    AVIMConversationOptionTransient = 1 << 1,
    /*
     Temporary conversation
     */
    AVIMConversationOptionTemporary = 1 << 2
};

typedef NSString * const AVIMConversationUpdatedKey NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastMessage;
FOUNDATION_EXPORT AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastMessageAt;
FOUNDATION_EXPORT AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastReadAt;
FOUNDATION_EXPORT AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastDeliveredAt;
FOUNDATION_EXPORT AVIMConversationUpdatedKey AVIMConversationUpdatedKeyUnreadMessagesCount;
FOUNDATION_EXPORT AVIMConversationUpdatedKey AVIMConversationUpdatedKeyUnreadMessagesMentioned;

@interface AVIMClient : NSObject

/*!
 Set what server will issues for offline messages when client did login.
 
 @param enabled Set `YES` if you want server just issues the count of offline messages in each conversation.
 Set `NO` if you want server issues concrete offline messages.
 Defaults to `NO`.
 */
+ (void)setUnreadNotificationEnabled:(BOOL)enabled;

/*!
 * 设置实时通信的超时时间，默认 30 秒。
 * @param seconds 超时时间，单位是秒。
 */
+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds;

/**
 No thread-safe for getter & setter. recommend setting after instantiation.
 */
@property (nonatomic, weak, nullable) id <AVIMClientDelegate> delegate;

/*
 No thread-safe for getter & setter. recommend setting after instantiation.
 */
@property (nonatomic, weak, nullable) id <AVIMSignatureDataSource> signatureDataSource;

/**
 The ID of this Client.
 */
@property (nonatomic, strong, readonly, nonnull) NSString *clientId;

/**
 The `AVUser` of this Client.
 */
@property (nonatomic, strong, readonly, nullable) AVUser *user;

/**
 The Tag of this Client.
 */
@property (nonatomic, strong, readonly, nullable) NSString *tag;

/**
 控制是否打开历史消息查询本地缓存的功能, 默认开启
 */
@property (nonatomic, assign) BOOL messageQueryCacheEnabled;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/**
 Initialization method.
 
 @note `clientId`'s length should in range [1, 64].
 
 @param clientId Identifie of this Client.
 @return Instance.
 */
- (instancetype)initWithClientId:(NSString *)clientId LC_WARN_UNUSED_RESULT;

/**
 Initialization method.
 
 @note `clientId`'s length should in range [1, 64], `tag` should not use @"default".

 @param clientId Identifie of this Client.
 @param tag Set it to implement only one client online.
 @return Instance.
 */
- (instancetype)initWithClientId:(NSString *)clientId tag:(NSString * _Nullable)tag LC_WARN_UNUSED_RESULT;

/**
 Initialization method.

 @param user The `AVUser` of this Client.
 @return Instance.
 */
- (instancetype)initWithUser:(AVUser *)user LC_WARN_UNUSED_RESULT;

/**
 Initialization method.
 
 @note `tag` should not use @"default".

 @param user The `AVUser` of this Client.
 @param tag Set it to implement only one client online.
 @return Instance.
 */
- (instancetype)initWithUser:(AVUser *)user tag:(NSString * _Nullable)tag LC_WARN_UNUSED_RESULT;

/**
 The Status of this Client.
 */
- (AVIMClientStatus)status LC_WARN_UNUSED_RESULT;

/**
 Start a Session with Server.
 It is similar to Login.
 
 @param callback Result Callback.
 */
- (void)openWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/**
 Start a Session with Server.
 It is similar to Login.
 
 @param openOption See more: `AVIMClientOpenOption`.
 @param callback Result Callback.
 */
- (void)openWithOption:(AVIMClientOpenOption)openOption
              callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/**
 End a Session with Server.
 It is similar to Logout.
 
 @param callback Result Callback.
 */
- (void)closeWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 创建一个新的用户对话。
 在单聊的场合，传入对方一个 clientId 即可；群聊的时候，支持同时传入多个 clientId 列表
 @param name - 会话名称。
 @param clientIds - 聊天参与者（发起人除外）的 clientId 列表。
 @param callback － 对话建立之后的回调
 */
- (void)createConversationWithName:(NSString * _Nullable)name
                         clientIds:(NSArray<NSString *> *)clientIds
                          callback:(void (^)(AVIMConversation * _Nullable conversation, NSError * _Nullable error))callback;

/**
 Create a new chat room conversation.
 
 @param name Name of the chat room.
 @param attributes Custom attributes of the chat room.
 @param callback Result of callback.
 */
- (void)createChatRoomWithName:(NSString * _Nullable)name
                    attributes:(NSDictionary * _Nullable)attributes
                      callback:(void (^)(AVIMChatRoom * _Nullable chatRoom, NSError * _Nullable error))callback;

/**
 Create a new temporary conversation.
 
 @param clientIds Member's client ID of conversation.
 @param ttl Use it to setup time to live of temporary conversation. it will not greater than a default max value(depend on server). if set Zero or Negtive, it will use max ttl, Unit of Measure: Second.
 @param callback Result of callback.
 */
- (void)createTemporaryConversationWithClientIds:(NSArray<NSString *> *)clientIds
                                      timeToLive:(int32_t)ttl
                                        callback:(void (^)(AVIMTemporaryConversation * _Nullable temporaryConversation, NSError * _Nullable error))callback;

/*!
 创建一个新的用户对话。
 在单聊的场合，传入对方一个 clientId 即可；群聊的时候，支持同时传入多个 clientId 列表
 @param name - 会话名称。
 @param clientIds - 聊天参与者（发起人除外）的 clientId 列表。
 @param attributes - 会话的自定义属性。
 @param options － 可选参数，可以使用或 “|” 操作表示多个选项
 @param callback － 对话建立之后的回调
 */
- (void)createConversationWithName:(NSString * _Nullable)name
                         clientIds:(NSArray<NSString *> *)clientIds
                        attributes:(NSDictionary * _Nullable)attributes
                           options:(AVIMConversationOption)options
                          callback:(void (^)(AVIMConversation * _Nullable conversation, NSError * _Nullable error))callback;

/**
 Create a New Conversation.

 @param name Name of the Conversation.
 @param clientIds Array of Other Client's ID
 @param attributes Custom Attributes
 @param options Option of the Conversation's Type
 @param temporaryTTL Temporary Conversation's Time to Live, Unit of Measure: Second.
 @param callback Result callback
 */
- (void)createConversationWithName:(NSString * _Nullable)name
                         clientIds:(NSArray<NSString *> *)clientIds
                        attributes:(NSDictionary * _Nullable)attributes
                           options:(AVIMConversationOption)options
                      temporaryTTL:(int32_t)temporaryTTL
                          callback:(void (^)(AVIMConversation * _Nullable conversation, NSError * _Nullable error))callback;

/**
 Get a Exist Conversation Retained by this Client.
 Thread-safe & Sync.
 
 @param conversationId conversationId
 @return if the Conversation Exist, return the Instance; if not, return nil.
 */
- (AVIMConversation * _Nullable)conversationForId:(NSString *)conversationId LC_WARN_UNUSED_RESULT;


/**
 Get Conversations Retained by this Client.
 Thread-safe & Async.

 @param conversationIds ID array.
 @param callback Result.
 */
- (void)getConversationsFromMemoryWith:(NSArray<NSString *> *)conversationIds
                              callback:(void (^)(NSArray<AVIMConversation *> * _Nullable conversations))callback;

/**
 Remove Conversations Retained by this Client.
 Thread-safe & Async.
 
 @param conversationIds Array of conversation's ID
 @param callback Result of Callback, always means success.
 */
- (void)removeConversationsInMemoryWith:(NSArray<NSString *> *)conversationIds
                               callback:(void (^)(void))callback;

/**
 Remove all Conversations Retained by this Client.
 Thread-safe & Async.
 
 @param callback Result of Callback, always means success.
 */
- (void)removeAllConversationsInMemoryWith:(void (^)(void))callback;

/*!
 创建一个绑定到当前 client 的会话。
 @param keyedConversation AVIMKeyedConversation 对象。
 @return 已绑定到当前 client 的会话。
 */
- (AVIMConversation * _Nullable)conversationWithKeyedConversation:(AVIMKeyedConversation *)keyedConversation LC_WARN_UNUSED_RESULT;

/*!
 构造一个对话查询对象
 @return 对话查询对象.
 */
- (AVIMConversationQuery *)conversationQuery LC_WARN_UNUSED_RESULT;

/*!
 Query online clients within the given array of clients.

 @note Currently, It only supports to query 20 clients at most.

 @param clients  An array of clients you want to query.
 @param callback The callback of query.
 */
- (void)queryOnlineClientsInClients:(NSArray<NSString *> *)clients
                           callback:(void (^)(NSArray<NSString *> * _Nullable clientIds, NSError * _Nullable error))callback;

@end

/**
 *  The AVIMClientDelegate protocol defines methods to handle these events: connecting status changes, message comes and members of the conversation changes.
 */
@protocol AVIMClientDelegate <NSObject>

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
 Callback which called when a message has been updated.
 
 @param conversation The conversation which the message belongs to.
 @param message      The new message which has been updated.
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
- (void)imClientPaused:(AVIMClient *)imClient error:(NSError *)error
__deprecated_msg("use -[imClientClosed:error:] instead.");

/*!
 收到未读通知。在该终端上线的时候，服务器会将对话的未读数发送过来。未读数可通过 -[AVIMConversation markAsReadInBackground] 清零，服务端不会自动清零。
 @param conversation 所属会话。
 @param unread 未读消息数量。
 */
- (void)conversation:(AVIMConversation *)conversation didReceiveUnread:(NSInteger)unread
AVIM_DEPRECATED("Deprecated in AVOSCloudIM SDK 4.3.0. Instead, use `-[AVIMClientDelegate conversation:propertyDidUpdate:]` instead.");

@end

@interface AVIMClient (AVDeprecated)

/*!
 * 设置用户选项。
 * 该接口用于控制 AVIMClient 的一些细节行为。
 * @param userOptions 用户选项。
 */
+ (void)setUserOptions:(NSDictionary *)userOptions
AVIM_DEPRECATED("Deprecated in v5.1.0. Do not use it any more.");

@end

NS_ASSUME_NONNULL_END
