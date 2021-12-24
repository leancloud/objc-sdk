//
//  LCIMConversation.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMCommon.h"
#import "LCIMMessage.h"
#import "LCIMMessageOption.h"

@class LCIMClient;
@class LCIMKeyedConversation;
@class LCIMRecalledMessage;
@class LCIMConversationMemberInfo;

NS_ASSUME_NONNULL_BEGIN

@interface LCIMMessageIntervalBound : NSObject

@property (nonatomic, copy, nullable) NSString *messageId;
@property (nonatomic, assign) int64_t timestamp;
@property (nonatomic, assign) BOOL closed;

- (instancetype)initWithMessageId:(nullable NSString *)messageId
                        timestamp:(int64_t)timestamp
                           closed:(BOOL)closed;

@end

@interface LCIMMessageInterval : NSObject

@property (nonatomic, strong) LCIMMessageIntervalBound *startIntervalBound;
@property (nonatomic, strong, nullable) LCIMMessageIntervalBound *endIntervalBound;

- (instancetype)initWithStartIntervalBound:(LCIMMessageIntervalBound *)startIntervalBound
                          endIntervalBound:(nullable LCIMMessageIntervalBound *)endIntervalBound;

@end

@interface LCIMOperationFailure : NSObject

@property (nonatomic, assign) NSInteger code;
@property (nonatomic, strong, nullable) NSString *reason;
@property (nonatomic, strong, nullable) NSArray<NSString *> *clientIds;

@end

@interface LCIMConversation : NSObject

/**
 *  The ID of the client which the conversation belongs to.
 */
@property (nonatomic, strong, readonly, nullable) NSString *clientId;

/**
 *  The ID of the conversation.
 */
@property (nonatomic, strong, readonly, nullable) NSString *conversationId;

/**
 *  The clientId of the conversation creator.
 */
@property (nonatomic, strong, readonly, nullable) NSString *creator;

/// The creation time of the conversation.
@property (nonatomic, strong, readonly, nullable) NSDate *createdAt;

/// The last updating time of the conversation. When fields like name, members changes, this time will changes.
@property (nonatomic, strong, readonly, nullable) NSDate *updatedAt;

/**
 *  The last message in this conversation.
 *  @attention Getter method may query lastMessage from SQL, this may take a long time, be careful to use getter method in main thread.
 */
@property (nonatomic, strong, readonly, nullable) LCIMMessage *lastMessage;

/**
 *  The send timestamp of the last message in this conversation.
 */
@property (nonatomic, strong, readonly, nullable) NSDate *lastMessageAt;

/**
 *  The last timestamp your message read by other.
 */
@property (nonatomic, strong, readonly, nullable) NSDate *lastReadAt;

/**
 *  The last timestamp your message delivered to other.
 */
@property (nonatomic, strong, readonly, nullable) NSDate *lastDeliveredAt;

/**
 *  The count of unread messages in current conversation.
 */
@property (nonatomic, assign, readonly) NSUInteger unreadMessagesCount;

/**
 *  A flag indicates whether an unread message mentioned you.
 */
@property (nonatomic, assign) BOOL unreadMessagesMentioned;

/**
 *  The name of this conversation. Can be changed by update:callback: .
 */
@property (nonatomic, strong, readonly, nullable) NSString *name;

/**
 *  The ids of the clients who join the conversation. Can be changed by addMembersWithClientIds:callback: or removeMembersWithClientIds:callback: .
 */
@property (nonatomic, strong, readonly, nullable) NSArray<NSString *> *members;

/**
 *  The attributes of the conversation. Intend to save any extra data of the conversation.
 *  Can be set when creating the conversation or can be updated by update:callback: .
 */
@property (nonatomic, strong, readonly, nullable) NSDictionary *attributes;

/**
 Unique ID of Unique Conversation.
 */
@property (nonatomic, strong, readonly, nullable) NSString *uniqueId;

/**
 Indicate whether it is a unique conversation.
 */
@property (nonatomic, assign, readonly) BOOL unique;

/**
 *  Indicate whether it is a transient conversation. 
 *  @see LCIMConversationOptionTransient
 */
@property (nonatomic, assign, readonly) BOOL transient;

/**
 Indicate whether it is a system conversation.
 */
@property (nonatomic, assign, readonly) BOOL system;

/**
 Indicate whether it is a temporary conversation.
 */
@property (nonatomic, assign, readonly) BOOL temporary;

/**
 Temporary Conversation's Time to Live.
 */
@property (nonatomic, assign, readonly) NSUInteger temporaryTTL;

/**
 *  Muting status. If muted, when you have offline messages, will not receive Apple APNS notification.
 *  Can be changed by muteWithCallback: or unmuteWithCallback:.
 */
@property (nonatomic, assign, readonly) BOOL muted;

/**
 *  The LCIMClient object which this conversation belongs to.
 */
@property (nonatomic, weak, readonly, nullable) LCIMClient *imClient;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/**
 * Add custom property for conversation.
 *
 * @param object The property value.
 * @param key    The property name.
 */
- (void)setObject:(id _Nullable)object forKey:(NSString *)key;

/**
 * Support to use subscript to set custom property.
 *
 * @see -[LCIMConversation setObject:forKey:]
 */
- (void)setObject:(id _Nullable)object forKeyedSubscript:(NSString *)key;

/*!
 * Get custom property value for conversation.
 *
 * @param key The custom property name.
 *
 * @return The custom property value.
 */
- (id _Nullable)objectForKey:(NSString *)key;

/**
 * Support to use subscript to set custom property.
 *
 * @see -[LCIMConversation objectForKey:]
 */
- (id _Nullable)objectForKeyedSubscript:(NSString *)key;

/*!
 Creates an LCIMKeyedConversation object for serialization.
 @return LCIMKeyedConversation object.
 */
- (LCIMKeyedConversation * _Nullable)keyedConversation;

// MARK: - RCP Timestamps & Read

/*!
 Fetches last receipt timestamps of the message.
 */
- (void)fetchReceiptTimestampsInBackground;

/*!
 Marks the latest message sent by other members as read.
 The message sender will receives a read notification.
 */
- (void)readInBackground;

// MARK: - Conversation Update

/*!
 Fetches latest data from the cloud.
 @param callback - A callback on results.
 */
- (void)fetchWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 Sends updates to the cloud.
 @param callback - A callback on results.
 */
- (void)updateWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

// MARK: - Conversation Mute

/*!
 Turns off the offline notifications of this conversation.
 @param callback - A callback on results.
 */
- (void)muteWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 Turns on the offline notifications of this conversation. 
 @param callback - A callback on results.
 */
- (void)unmuteWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

// MARK: - Members

/*!
 Joins this conversation.
 @param callback － A callback on results. 
 */
- (void)joinWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 Quits from this conversation.
 @param callback － A callback on results.
 */
- (void)quitWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 Adds members to this conversation.
 @param clientIds － Member list.
 @param callback － A callback on results.
 */
- (void)addMembersWithClientIds:(NSArray<NSString *> *)clientIds
                       callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 Removes members from this conversation.
 @param clientIds - Member list.
 @param callback - A callback on results. 
 */
- (void)removeMembersWithClientIds:(NSArray<NSString *> *)clientIds
                          callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 Counts the members of this conversation.
 @param callback － A callback on results.
 */
- (void)countMembersWithCallback:(void (^)(NSInteger count, NSError * _Nullable error))callback;

// MARK: - Message Send

/*!
 Sends a message to this conversation.
 @param message － The message to send.
 @param callback － A callback on results.
 */
- (void)sendMessage:(LCIMMessage *)message
           callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 Sends a message to this conversation. 
 @param message － The message to send.
 @param option － Message sending options.
 @param callback － A callback on results.
 */
- (void)sendMessage:(LCIMMessage *)message
             option:(LCIMMessageOption * _Nullable)option
           callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 Sends a message to this conversation.
 @param message － The message to send. 
 @param progressBlock - A callback on uploading progress. This is only applicable to uploading files. This callback will not be invoked when sending a text message.
 @param callback － A callback on results.
 */
- (void)sendMessage:(LCIMMessage *)message
      progressBlock:(void (^ _Nullable)(NSInteger progress))progressBlock
           callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 Sends a message to this conversation. 
 @param message － The message to send. 
 @param option － Message sending options. 
 @param progressBlock - A callback on uploading progress. This is only applicable to uploading files. This callback will not be invoked when sending a text message. 
 @param callback － A callback on results. 
 */
- (void)sendMessage:(LCIMMessage *)message
             option:(nullable LCIMMessageOption *)option
      progressBlock:(void (^ _Nullable)(NSInteger progress))progressBlock
           callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

// MARK: - Message Update

/*!
 Replace a message you sent with a new message.

 @param oldMessage The message you've sent which will be replaced by newMessage.
 @param newMessage A new message.
 @param callback   Callback of message update.
 */
- (void)updateMessage:(LCIMMessage *)oldMessage
         toNewMessage:(LCIMMessage *)newMessage
             callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 Recall a message.

 @param oldMessage The message you've sent which will be replaced by newMessage.
 @param callback   Callback of message update.
 */
- (void)recallMessage:(LCIMMessage *)oldMessage
             callback:(void (^)(BOOL succeeded, NSError * _Nullable error, LCIMRecalledMessage * _Nullable recalledMessage))callback;

// MARK: - Message Cache

/*!
 Add a message to cache.

 @param message The message to be cached.
 */
- (void)addMessageToCache:(LCIMMessage *)message;

/*!
 Remove a message from cache.

 @param message The message which you want to remove from cache.
 */
- (void)removeMessageFromCache:(LCIMMessage *)message;

// MARK: - Message Query

/*!
 Queries recent messages from the cloud.
 @param limit The default is 20. The maximum is 1000.
 @param callback A callback on returned results.
 */
- (void)queryMessagesFromServerWithLimit:(NSUInteger)limit
                                callback:(void (^)(NSArray<LCIMMessage *> * _Nullable messages, NSError * _Nullable error))callback;

/*!
 Queries recent messages from the cache. 
 @param limit The default is 20. The maximum is 1000.
 @return An array of messages.
 */
- (NSArray *)queryMessagesFromCacheWithLimit:(NSUInteger)limit;

/*!
 Queries recent messages.
 @param limit The default is 20. The maximum is 1000.
 @param callback A callback on returned results.
 */
- (void)queryMessagesWithLimit:(NSUInteger)limit
                      callback:(void (^)(NSArray<LCIMMessage *> * _Nullable messages, NSError * _Nullable error))callback;

/*!
 Queries historical messages.
 @warning `timestamp` must equal to the timestamp of the message that messageId equal to `messageId`, if the `timestamp` and `messageId` not match, continuity of querying message can't guarantee.
 
 @param messageId Messages before this message.
 @param timestamp Messages before this timestamp.
 @param limit The default is 20. The maximum is 1000. 
 @param callback A callback on returned results.
 */
- (void)queryMessagesBeforeId:(NSString *)messageId
                    timestamp:(int64_t)timestamp
                        limit:(NSUInteger)limit
                     callback:(void (^)(NSArray<LCIMMessage *> * _Nullable messages, NSError * _Nullable error))callback;

/**
 Query messages from a message to an another message with specified direction applied.

 @param interval  A message interval.
 @param direction Direction of message query.
 @param limit     Limit of messages you want to query.
 @param callback  Callback of query request.
 */
- (void)queryMessagesInInterval:(nullable LCIMMessageInterval *)interval
                      direction:(LCIMMessageQueryDirection)direction
                          limit:(NSUInteger)limit
                       callback:(void (^)(NSArray<LCIMMessage *> * _Nullable messages, NSError * _Nullable error))callback;

/**
 Query Specific Media Type Message from Server.

 @param type Specific Media Type you want to query, see `LCIMMessageMediaType`.
 @param limit Limit of messages you want to query.
 @param messageId If set it and MessageId is Valid, the Query Result is Decending base on Timestamp and will Not Include the Message that its messageId is this parameter.
 @param timestamp Set Zero or Negative, it will query from latest Message and result include the latest Message; Set a valid timestamp, the Query Result is Decending base on Timestamp and will Not Include the Message that its timestamp is this parameter.
 @param callback Result callback.
 */
- (void)queryMediaMessagesFromServerWithType:(LCIMMessageMediaType)type
                                       limit:(NSUInteger)limit
                               fromMessageId:(NSString * _Nullable)messageId
                               fromTimestamp:(int64_t)timestamp
                                    callback:(void (^)(NSArray<LCIMMessage *> * _Nullable messages, NSError * _Nullable error))callback;

// MARK: - Member Info

/**
 Get all member info. using cache as a default.

 @param callback Result callback.
 */
- (void)getAllMemberInfoWithCallback:(void (^)(NSArray<LCIMConversationMemberInfo *> * _Nullable memberInfos, NSError * _Nullable error))callback;

/**
 Get all member info.

 @param ignoringCache Cache option.
 @param callback Result callback.
 */
- (void)getAllMemberInfoWithIgnoringCache:(BOOL)ignoringCache
                                 callback:(void (^)(NSArray<LCIMConversationMemberInfo *> * _Nullable memberInfos, NSError * _Nullable error))callback;

/**
 Get a member info by member id. using cache as a default.

 @param memberId Equal to client id.
 @param callback Result callback.
 */
- (void)getMemberInfoWithMemberId:(NSString *)memberId
                         callback:(void (^)(LCIMConversationMemberInfo * _Nullable memberInfo, NSError * _Nullable error))callback;

/**
 Get a member info by member id.

 @param ignoringCache Cache option.
 @param memberId Equal to client id.
 @param callback Result callback.
 */
- (void)getMemberInfoWithIgnoringCache:(BOOL)ignoringCache
                              memberId:(NSString *)memberId
                              callback:(void (^)(LCIMConversationMemberInfo * _Nullable memberInfo, NSError * _Nullable error))callback;

/**
 Change a member's role.

 @param memberId Equal to client id.
 @param role Changing role.
 @param callback Result callback.
 */
- (void)updateMemberRoleWithMemberId:(NSString *)memberId
                                role:(LCIMConversationMemberRole)role
                            callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

// MARK: - Member Block

/**
 Blocking some members in the conversation.

 @param memberIds Who will be blocked.
 @param callback Result callback.
 */
- (void)blockMembers:(NSArray<NSString *> *)memberIds
            callback:(void (^)(NSArray<NSString *> * _Nullable successfulIds, NSArray<LCIMOperationFailure *> * _Nullable failedIds, NSError * _Nullable error))callback;

/**
 Unblocking some members in the conversation.

 @param memberIds Who will be unblocked.
 @param callback Result callback.
 */
- (void)unblockMembers:(NSArray<NSString *> *)memberIds
              callback:(void (^)(NSArray<NSString *> * _Nullable successfulIds, NSArray<LCIMOperationFailure *> * _Nullable failedIds, NSError * _Nullable error))callback;

/**
 Query blocked members in the conversation.

 @param limit Count of the blocked members you want to query.
 @param next Offset, if callback's next is nil or empty, that means there is no more blocked members.
 @param callback Result callback.
 */
- (void)queryBlockedMembersWithLimit:(NSInteger)limit
                                next:(NSString * _Nullable)next
                            callback:(void (^)(NSArray<NSString *> * _Nullable blockedMemberIds, NSString * _Nullable next, NSError * _Nullable error))callback;

// MARK: - Member Mute

/**
 Muting some members in the conversation.
 
 @param memberIds Who will be muted.
 @param callback Result callback.
 */
- (void)muteMembers:(NSArray<NSString *> *)memberIds
           callback:(void (^)(NSArray<NSString *> * _Nullable successfulIds, NSArray<LCIMOperationFailure *> * _Nullable failedIds, NSError * _Nullable error))callback;

/**
 Unmuting some members in the conversation.
 
 @param memberIds Who will be unmuted.
 @param callback Result callback.
 */
- (void)unmuteMembers:(NSArray<NSString *> *)memberIds
             callback:(void (^)(NSArray<NSString *> * _Nullable successfulIds, NSArray<LCIMOperationFailure *> * _Nullable failedIds, NSError * _Nullable error))callback;

/**
 Query muted members in the conversation.
 
 @param limit Count of the muted members you want to query.
 @param next Offset, if callback's next is nil or empty, that means there is no more muted members.
 @param callback Result callback.
 */
- (void)queryMutedMembersWithLimit:(NSInteger)limit
                              next:(NSString * _Nullable)next
                          callback:(void (^)(NSArray<NSString *> * _Nullable mutedMemberIds, NSString * _Nullable next, NSError * _Nullable error))callback;

@end

@interface LCIMChatRoom : LCIMConversation

@end

@interface LCIMServiceConversation : LCIMConversation

/**
 Add ID of conversation's client to conversation's members.

 @param callback Result callback.
 */
- (void)subscribeWithCallback:(void(^)(BOOL, NSError * _Nullable))callback;

/**
 Remove ID of conversation's client from conversation's members.
 
 @param callback Result callback.
 */
- (void)unsubscribeWithCallback:(void(^)(BOOL, NSError * _Nullable))callback;

@end

@interface LCIMTemporaryConversation : LCIMConversation

@end

NS_ASSUME_NONNULL_END
