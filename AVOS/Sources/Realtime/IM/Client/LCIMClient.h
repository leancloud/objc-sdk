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

/// The option of conversation creation.
@interface LCIMConversationCreationOption : NSObject

/// The name of the conversation.
@property (nonatomic, nullable) NSString *name;

/// The attributes of the conversation.
@property (nonatomic, nullable) NSDictionary *attributes;

/// Create or get an unique conversation, default is `true`.
@property (nonatomic) BOOL isUnique;

/// The time interval for the life of the temporary conversation.
@property (nonatomic) NSUInteger timeToLive;

@end

/// IM Client.
@interface LCIMClient : NSObject

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

/// The current status of this client, see `LCIMClientStatus`.
@property (nonatomic, readonly) LCIMClientStatus status;

/// The control switch for message query cache, default is `true`.
@property (nonatomic) BOOL messageQueryCacheEnabled;

// MARK: Init

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/// Initializing with an ID.
/// @param clientId The length of the ID should in range `[1, 64]`.
/// @param error Throws exception when error occurred.
- (nullable instancetype)initWithClientId:(NSString *)clientId
                                    error:(NSError * __autoreleasing *)error;

/// Initializing with an ID and a tag.
/// @param clientId The length of the ID should in range `[1, 64]`.
/// @param tag Using a tag to specify the context, `@"default"` is reserved.
/// @param error Throws exception when error occurred.
- (nullable instancetype)initWithClientId:(NSString *)clientId
                                      tag:(NSString * _Nullable)tag
                                    error:(NSError * __autoreleasing *)error;

/// Initializing with an `LCUser`.
/// @param user The user should have logged in.
/// @param error Throws exception when error occurred.
- (nullable instancetype)initWithUser:(LCUser *)user
                                error:(NSError * __autoreleasing *)error;

/// Initializing with an `LCUser` and a tag.
/// @param user The user should have logged in.
/// @param tag Using a tag to specify the context, `@"default"` is reserved.
/// @param error Throws exception when error occurred.
- (nullable instancetype)initWithUser:(LCUser *)user
                                  tag:(NSString * _Nullable)tag
                                error:(NSError * __autoreleasing *)error;

// MARK: Open & Close

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

// MARK: Conversation Creation

/// Create a Normal Conversation. Default is a Normal Unique Conversation.
/// @param clientIds The set of client ID. it's the members of the conversation which will be created. the initialized members always contains current client's ID. if the created conversation is unique, and server has one unique conversation with the same members, that unique conversation will be returned.
/// @param callback Result callback.
- (void)createConversationWithClientIds:(NSArray<NSString *> *)clientIds
                               callback:(void (^)(LCIMConversation * _Nullable conversation, NSError * _Nullable error))callback;

/// Create a Normal Conversation. Default is a Normal Unique Conversation.
/// @param clientIds The set of client ID. it's the members of the conversation which will be created. the initialized members always contains current client's ID. if the created conversation is unique, and server has one unique conversation with the same members, that unique conversation will be returned.
/// @param option See `LCIMConversationCreationOption`.
/// @param callback Result callback.
- (void)createConversationWithClientIds:(NSArray<NSString *> *)clientIds
                                 option:(LCIMConversationCreationOption * _Nullable)option
                               callback:(void (^)(LCIMConversation * _Nullable conversation, NSError * _Nullable error))callback;

/// Create a Chat Room.
/// @param callback Result callback.
- (void)createChatRoomWithCallback:(void (^)(LCIMChatRoom * _Nullable chatRoom, NSError * _Nullable error))callback;

/// Create a Chat Room.
/// @param option See `LCIMConversationCreationOption`.
/// @param callback Result callback.
- (void)createChatRoomWithOption:(LCIMConversationCreationOption * _Nullable)option
                        callback:(void (^)(LCIMChatRoom * _Nullable chatRoom, NSError * _Nullable error))callback;

/// Create a Temporary Conversation. Temporary Conversation is unique in it's Life Cycle.
/// @param clientIds The set of client ID. it's the members of the conversation which will be created. the initialized members always contains this client's ID.
/// @param callback Result callback.
- (void)createTemporaryConversationWithClientIds:(NSArray<NSString *> *)clientIds
                                        callback:(void (^)(LCIMTemporaryConversation * _Nullable temporaryConversation, NSError * _Nullable error))callback;

/// Create a Temporary Conversation. Temporary Conversation is unique in it's Life Cycle.
/// @param clientIds The set of client ID. it's the members of the conversation which will be created. the initialized members always contains this client's ID.
/// @param option See `LCIMConversationCreationOption`.
/// @param callback Result callback.
- (void)createTemporaryConversationWithClientIds:(NSArray<NSString *> *)clientIds
                                          option:(LCIMConversationCreationOption * _Nullable)option
                                        callback:(void (^)(LCIMTemporaryConversation * _Nullable temporaryConversation, NSError * _Nullable error))callback;

// MARK: Conversation Cache

/**
 Get a Exist Conversation Retained by this Client.
 Thread-safe & Sync.
 
 @param conversationId conversationId
 @return if the Conversation Exist, return the Instance; if not, return nil.
 */
- (LCIMConversation * _Nullable)conversationForId:(NSString *)conversationId;


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


- (LCIMConversation * _Nullable)conversationWithKeyedConversation:(LCIMKeyedConversation *)keyedConversation;

// MARK: Conversation Query

/// Create a new conversation query.
- (LCIMConversationQuery *)conversationQuery;

// MARK: Online Query

/*!
 Query online clients within the given array of clients.

 @note Currently, It only supports to query 20 clients at most.

 @param clients  An array of clients you want to query.
 @param callback The callback of query.
 */
- (void)queryOnlineClientsInClients:(NSArray<NSString *> *)clients
                           callback:(void (^)(NSArray<NSString *> * _Nullable clientIds, NSError * _Nullable error))callback;

@end

NS_ASSUME_NONNULL_END
