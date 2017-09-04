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

@class AVIMConversation;
@class AVIMKeyedConversation;
@class AVIMMessage;
@class AVIMTypedMessage;
@class AVIMConversationQuery;
@class AVIMClientOpenOption;
@class AVUser;

@protocol AVIMClientDelegate;

typedef NS_ENUM(NSUInteger, AVIMClientStatus) {
    /// Initial client status.
    AVIMClientStatusNone,
    /// Indicate the client is connecting the server now.
    AVIMClientStatusOpening,
    /// Indicate the client connected the server.
    AVIMClientStatusOpened,
    /// Indicate the connection paused. Usually for the network reason.
    AVIMClientStatusPaused,
    /// Indicate the connection is recovering.
    AVIMClientStatusResuming,
    /// Indicate the connection is closing.
    AVIMClientStatusClosing,
    /// Indicate the connection is closed.
    AVIMClientStatusClosed
};

typedef NS_OPTIONS(uint64_t, AVIMConversationOption) {
    /// Default conversation. At most allow 500 people to join the conversation.
    AVIMConversationOptionNone      = 0,
    /// Transient conversation. No headcount limits. But the functionality is limited. No offline messages, no offline notifications, etc.
    AVIMConversationOptionTransient = 1 << 0,
    /// Unique conversation. If the server detects the conversation with that members exists, will return it instead of creating a new one.
    AVIMConversationOptionUnique    = 1 << 1,
};

NS_ASSUME_NONNULL_BEGIN

@interface AVIMClient : NSObject

/**
 *  The delegate which implements AVIMClientDelegate protocol. It handles these events: connecting status changes, message coming and members of the conversation changes.
 */
@property (nonatomic, weak, nullable) id<AVIMClientDelegate> delegate;

/**
 *  The delegate which implements AVIMSignatureDataSource protocol. It is used to fetching signature from your server, and return an AVIMSignature object.
 */
@property (nonatomic, weak, nullable) id<AVIMSignatureDataSource> signatureDataSource;

/**
 *  The ID of the current client. Usually the user's ID.
 */
@property (nonatomic, copy, readonly, nullable) NSString *clientId;

/**
 The user that you login as a client.
 */
@property (nonatomic, strong, readonly, nullable) AVUser *user;

/**
 * Tag of current client.
 * @brief If tag is not nil and "default", offline mechanism is enabled.
 * @discussion If one client id login on two different devices, previous opened client will be gone offline by later opened client.
 */
@property (nonatomic, copy, readonly, nullable) NSString *tag;

/**
 *  The connecting status of the current client.
 */
@property (nonatomic, readonly, assign) AVIMClientStatus status;

/**
 * 控制是否打开历史消息查询的本地缓存功能,默认开启
 */
@property (nonatomic, assign) BOOL messageQueryCacheEnabled;

/*!
 Initializes a newly allocated client.
 @param clientId Identifier of client, nonnull requierd.
 */
- (instancetype)initWithClientId:(NSString *)clientId;

/*!
 Initializes a newly allocated client.
 @param clientId Identifier of client, nonnull requierd.
 @param tag      Tag of client.
 */
- (instancetype)initWithClientId:(NSString *)clientId tag:(nullable NSString *)tag;

/*!
 Initializes client with an user.

 @seealso It's a convenience initializer of <code>-[AVIMClient initWithUser:tag:]</code>
 */
- (instancetype)initWithUser:(AVUser *)user;

/*!
 Initializes client with an user and a tag.

 This method allows you to use an user as a client to login to IM.
 Using user as an IM client has some extra benifits. For example, It will activate
 login signature to improve security. Besides that, you can also take advantage of
 the friendship relations of users.

 @note You should enable login signature option in application console before you call this method.

 @param user An user who has logged in.
 @param tag  Tag of client.
 */
- (instancetype)initWithUser:(AVUser *)user tag:(nullable NSString *)tag;

/*!
 * 设置用户选项。
 * 该接口用于控制 AVIMClient 的一些细节行为。
 * @param userOptions 用户选项。
 */
+ (void)setUserOptions:(NSDictionary *)userOptions AVIM_DEPRECATED("Deprecated in v5.1.0. Do not use it any more.");

/*!
 Set what server will issues for offline messages when client did login.

 @param enabled Set `YES` if you want server just issues the count of offline messages in each conversation.
                Set `NO` if you want server issues concrete offline messages.
                Defaults to `NO`.
 */
+ (void)setUnreadNotificationEnabled:(BOOL)enabled;

/*!
 * 设置实时通信的超时时间，默认 15 秒。
 * @param seconds 超时时间，单位是秒。
 */
+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds;

/*!
 开启某个账户的聊天
 @param callback － 聊天开启之后的回调
 */
- (void)openWithCallback:(AVIMBooleanResultBlock)callback;

/*!
 * Open client with option.
 * @param option   Option to open client.
 * @param callback Callback for openning client.
 * @brief Open client with option of which the properties will override client's default option.
 */
- (void)openWithOption:(nullable AVIMClientOpenOption *)option callback:(AVIMBooleanResultBlock)callback;

/*!
 结束某个账户的聊天
 @param callback － 聊天关闭之后的回调
 */
- (void)closeWithCallback:(AVIMBooleanResultBlock)callback;

/*!
 创建一个新的用户对话。
 在单聊的场合，传入对方一个 clientId 即可；群聊的时候，支持同时传入多个 clientId 列表
 @param name - 会话名称。
 @param clientIds - 聊天参与者（发起人除外）的 clientId 列表。
 @param callback － 对话建立之后的回调
 */
- (void)createConversationWithName:(NSString *)name
                         clientIds:(NSArray *)clientIds
                          callback:(AVIMConversationResultBlock)callback;

/*!
 创建一个新的用户对话。
 在单聊的场合，传入对方一个 clientId 即可；群聊的时候，支持同时传入多个 clientId 列表
 @param name - 会话名称。
 @param clientIds - 聊天参与者（发起人除外）的 clientId 列表。
 @param attributes - 会话的自定义属性。
 @param options － 可选参数，可以使用或 “|” 操作表示多个选项
 @param callback － 对话建立之后的回调
 */
- (void)createConversationWithName:(NSString *)name
                         clientIds:(NSArray *)clientIds
                        attributes:(nullable NSDictionary *)attributes
                           options:(AVIMConversationOption)options
                          callback:(AVIMConversationResultBlock)callback;

/*!
 通过 conversationId 查找已激活会话。
 已激活会话是指通过查询、创建、或通过 KeyedConversation 所得到的会话。
 @param conversationId Conversation 的 id。
 @return 与 conversationId 匹配的会话，若找不到，返回 nil。
 */
- (nullable AVIMConversation *)conversationForId:(NSString *)conversationId;

/*!
 创建一个绑定到当前 client 的会话。
 @param keyedConversation AVIMKeyedConversation 对象。
 @return 已绑定到当前 client 的会话。
 */
- (AVIMConversation *)conversationWithKeyedConversation:(AVIMKeyedConversation *)keyedConversation;

/*!
 构造一个对话查询对象
 @return 对话查询对象.
 */
- (AVIMConversationQuery *)conversationQuery;

/*!
 Query online clients within the given array of clients.

 @note Currently, It only supports to query 20 clients at most.

 @param clients  An array of clients you want to query.
 @param callback The callback of query.
 */
- (void)queryOnlineClientsInClients:(NSArray<NSString *> *)clients callback:(AVIMArrayResultBlock)callback;

@end

/**
 *  The AVIMClientDelegate protocol defines methods to handle these events: connecting status changes, message comes and members of the conversation changes.
 */
@protocol AVIMClientDelegate <NSObject>
@optional

/**
 *  当前聊天状态被暂停，常见于网络断开时触发。
 *  @param imClient 相应的 imClient
 */
- (void)imClientPaused:(AVIMClient *)imClient;

/**
 *  当前聊天状态被暂停，常见于网络断开时触发。
 *  注意：该回调会覆盖 imClientPaused: 方法。
 *  @param imClient 相应的 imClient
 *  @param error    具体错误信息
 */
- (void)imClientPaused:(AVIMClient *)imClient error:(NSError *)error;

/**
 *  当前聊天状态开始恢复，常见于网络断开后开始重新连接。
 *  @param imClient 相应的 imClient
 */
- (void)imClientResuming:(AVIMClient *)imClient;

/**
 *  当前聊天状态已经恢复，常见于网络断开后重新连接上。
 *  @param imClient 相应的 imClient
 */
- (void)imClientResumed:(AVIMClient *)imClient;

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

/*!
 对话中有新成员加入时所有成员都会收到这一通知。
 @param conversation － 所属对话
 @param clientIds - 加入的新成员列表
 @param clientId - 邀请者的 id
 */
- (void)conversation:(AVIMConversation *)conversation membersAdded:(NSArray *)clientIds byClientId:(NSString *)clientId;

/*!
 对话中有成员离开时所有剩余成员都会收到这一通知。
 @param conversation － 所属对话
 @param clientIds - 离开的成员列表
 @param clientId - 操作者的 id
 */
- (void)conversation:(AVIMConversation *)conversation membersRemoved:(NSArray *)clientIds byClientId:(NSString *)clientId;

/*!
 当前用户被邀请加入对话的通知。
 @param conversation － 所属对话
 @param clientId - 邀请者的 id
 */
- (void)conversation:(AVIMConversation *)conversation invitedByClientId:(NSString *)clientId;

/*!
 当前用户被踢出对话的通知。
 @param conversation － 所属对话
 @param clientId - 操作者的 id
 */
- (void)conversation:(AVIMConversation *)conversation kickedByClientId:(NSString *)clientId;

/*!
  收到未读通知。在该终端上线的时候，服务器会将对话的未读数发送过来。未读数可通过 -[AVIMConversation markAsReadInBackground] 清零，服务端不会自动清零。
 @param conversation 所属会话。
 @param unread 未读消息数量。
 */
- (void)conversation:(AVIMConversation *)conversation didReceiveUnread:(NSInteger)unread AVIM_DEPRECATED("Deprecated in AVOSCloudIM SDK 4.3.0. Instead, use `-[AVIMClientDelegate conversation:propertyDidUpdate:]` instead.");

/*!
 Notification for conversation property update.
 You can use this method to handle the properties that will be updated dynamicly during conversation's lifetime,
 for example, unread message count, last message and receipt timestamp, etc.

 @param conversation The updated conversation.
 @param key          The property name of updated conversation.
 */
- (void)conversation:(AVIMConversation *)conversation didUpdateForKey:(NSString *)key;

/*!
 客户端下线通知。
 @param client 已下线的 client。
 @param error 错误信息。
 */
- (void)client:(AVIMClient *)client didOfflineWithError:(NSError *)error;

@end

@interface AVIMClient (AVDeprecated)

@end

NS_ASSUME_NONNULL_END
