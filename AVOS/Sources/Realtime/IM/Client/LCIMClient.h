//
//  LCIMClient.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMCommon.h"
#import "LCIMClientProtocol.h"

@class LCIMConversation;
@class LCIMChatRoom;
@class LCIMServiceConversation;
@class LCIMTemporaryConversation;
@class LCIMKeyedConversation;
@class LCIMConversationQuery;
@protocol LCIMSignatureDataSource;

NS_ASSUME_NONNULL_BEGIN

/// IM Client.
@interface LCIMClient : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/*!
 Set what server will issues for offline messages when client did login.
 
 @param enabled Set `YES` if you want server just issues the count of offline messages in each conversation.
 Set `NO` if you want server issues concrete offline messages.
 Defaults to `NO`.
 */
+ (void)setUnreadNotificationEnabled:(BOOL)enabled;

/// Set up connecting timeout, default is `60` seconds.
/// @param seconds The interval of timeout.
+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds;

/// The delegate for `LCIMClientDelegate`.
@property (nonatomic, weak, nullable) id<LCIMClientDelegate> delegate;

/// The delegate for `LCIMSignatureDataSource`.
@property (nonatomic, weak, nullable) id<LCIMSignatureDataSource> signatureDataSource;

/// The ID of this client.
@property (nonatomic, readonly) NSString *clientId;

/// The `LCUser` of this client.
@property (nonatomic, readonly, nullable) LCUser *user;

/// The tag of this client.
@property (nonatomic, readonly, nullable) NSString *tag;

/// The control switch for message query cache, default is `true`.
@property (nonatomic) BOOL messageQueryCacheEnabled;

/// Initializing with an ID.
/// @param clientId The length of the ID should in range `[1, 64]`.
- (nullable instancetype)initWithClientId:(NSString *)clientId LC_WARN_UNUSED_RESULT;

/// Initializing with an ID.
/// @param clientId The length of the ID should in range `[1, 64]`.
/// @param error Throws exception when error occurred.
- (nullable instancetype)initWithClientId:(NSString *)clientId
                                    error:(NSError * __autoreleasing *)error LC_WARN_UNUSED_RESULT;

/// Initializing with an ID and a tag.
/// @param clientId The length of the ID should in range `[1, 64]`.
/// @param tag Using a tag to specify the context, `@"default"` is reserved.
- (nullable instancetype)initWithClientId:(NSString *)clientId
                                      tag:(NSString * _Nullable)tag LC_WARN_UNUSED_RESULT;

/// Initializing with an ID and a tag.
/// @param clientId The length of the ID should in range `[1, 64]`.
/// @param tag Using a tag to specify the context, `@"default"` is reserved.
/// @param error Throws exception when error occurred.
- (nullable instancetype)initWithClientId:(NSString *)clientId
                                      tag:(NSString * _Nullable)tag
                                    error:(NSError * __autoreleasing *)error LC_WARN_UNUSED_RESULT;

/// Initializing with an `LCUser`.
/// @param user The user should have logged in.
- (nullable instancetype)initWithUser:(LCUser *)user LC_WARN_UNUSED_RESULT;

/// Initializing with an `LCUser`.
/// @param user The user should have logged in.
/// @param error Throws exception when error occurred.
- (nullable instancetype)initWithUser:(LCUser *)user
                                error:(NSError * __autoreleasing *)error LC_WARN_UNUSED_RESULT;

/// Initializing with an `LCUser` and a tag.
/// @param user The user should have logged in.
/// @param tag Using a tag to specify the context, `@"default"` is reserved.
- (nullable instancetype)initWithUser:(LCUser *)user
                                  tag:(NSString * _Nullable)tag LC_WARN_UNUSED_RESULT;

/// Initializing with an `LCUser` and a tag.
/// @param user The user should have logged in.
/// @param tag Using a tag to specify the context, `@"default"` is reserved.
/// @param error Throws exception when error occurred.
- (nullable instancetype)initWithUser:(LCUser *)user
                                  tag:(NSString * _Nullable)tag
                                error:(NSError * __autoreleasing *)error LC_WARN_UNUSED_RESULT;

/// The current status of this client, see `LCIMClientStatus`.
- (LCIMClientStatus)status;

/// Open this client before using instant messaging service,
/// this action use `LCIMClientOpenOptionForceOpen` as default open option.
/// @param callback The result callback.
- (void)openWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/// Open this client before using instant messaging service
/// @param openOption See `LCIMClientOpenOption`.
/// @param callback The result callback.
- (void)openWithOption:(LCIMClientOpenOption)openOption
              callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/// Close this client.
/// @param callback The result callback.
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
                          callback:(void (^)(LCIMConversation * _Nullable conversation, NSError * _Nullable error))callback;

/**
 Create a new chat room conversation.
 
 @param name Name of the chat room.
 @param attributes Custom attributes of the chat room.
 @param callback Result of callback.
 */
- (void)createChatRoomWithName:(NSString * _Nullable)name
                    attributes:(NSDictionary * _Nullable)attributes
                      callback:(void (^)(LCIMChatRoom * _Nullable chatRoom, NSError * _Nullable error))callback;

/**
 Create a new temporary conversation.
 
 @param clientIds Member's client ID of conversation.
 @param ttl Use it to setup time to live of temporary conversation. it will not greater than a default max value(depend on server). if set Zero or Negtive, it will use max ttl, Unit of Measure: Second.
 @param callback Result of callback.
 */
- (void)createTemporaryConversationWithClientIds:(NSArray<NSString *> *)clientIds
                                      timeToLive:(int32_t)ttl
                                        callback:(void (^)(LCIMTemporaryConversation * _Nullable temporaryConversation, NSError * _Nullable error))callback;

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
                           options:(LCIMConversationOption)options
                          callback:(void (^)(LCIMConversation * _Nullable conversation, NSError * _Nullable error))callback;

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
                           options:(LCIMConversationOption)options
                      temporaryTTL:(int32_t)temporaryTTL
                          callback:(void (^)(LCIMConversation * _Nullable conversation, NSError * _Nullable error))callback;

/**
 Get a Exist Conversation Retained by this Client.
 Thread-safe & Sync.
 
 @param conversationId conversationId
 @return if the Conversation Exist, return the Instance; if not, return nil.
 */
- (LCIMConversation * _Nullable)conversationForId:(NSString *)conversationId LC_WARN_UNUSED_RESULT;


/**
 Get Conversations Retained by this Client.
 Thread-safe & Async.

 @param conversationIds ID array.
 @param callback Result.
 */
- (void)getConversationsFromMemoryWith:(NSArray<NSString *> *)conversationIds
                              callback:(void (^)(NSArray<LCIMConversation *> * _Nullable conversations))callback;

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
 @param keyedConversation LCIMKeyedConversation 对象。
 @return 已绑定到当前 client 的会话。
 */
- (LCIMConversation * _Nullable)conversationWithKeyedConversation:(LCIMKeyedConversation *)keyedConversation LC_WARN_UNUSED_RESULT;

/*!
 构造一个对话查询对象
 @return 对话查询对象.
 */
- (LCIMConversationQuery *)conversationQuery LC_WARN_UNUSED_RESULT;

/*!
 Query online clients within the given array of clients.

 @note Currently, It only supports to query 20 clients at most.

 @param clients  An array of clients you want to query.
 @param callback The callback of query.
 */
- (void)queryOnlineClientsInClients:(NSArray<NSString *> *)clients
                           callback:(void (^)(NSArray<NSString *> * _Nullable clientIds, NSError * _Nullable error))callback;

@end

// MARK: Deprecated

@interface LCIMClient (Deprecated)

+ (void)setUserOptions:(NSDictionary *)userOptions
__deprecated_msg("Deprecated, DO NOT use it any more.");

@end

NS_ASSUME_NONNULL_END