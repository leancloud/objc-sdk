//
//  AVIMConversation.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"
#import "AVIMMessage.h"
#import "AVIMTypedMessage.h"
#import "AVIMConversationUpdateBuilder.h"
#import "AVIMKeyedConversation.h"
#import "AVIMAvailability.h"
#import "AVIMMessageOption.h"

@class AVIMClient;

typedef uint64_t AVIMMessageSendOption AVIM_DEPRECATED("Deprecated in AVOSCloudIM SDK 3.4.0. Use AVIMMessageOption instead.");

enum : AVIMMessageSendOption {
    /// Default message.
    AVIMMessageSendOptionNone = 0,
    /// Transient message. Not saved in the sever. Discard if the receiver is offline.
    AVIMMessageSendOptionTransient = 1 << 0,
    /// When receiver receives the message, in sender part, -[AVIMClientDelegate conversation:messageDelivered:] will be called.
    AVIMMessageSendOptionRequestReceipt = 1 << 1,
} AVIM_DEPRECATED("Deprecated in AVOSCloudIM SDK 3.4.0. Use AVIMMessageOption instead.");

NS_ASSUME_NONNULL_BEGIN

@interface AVIMConversation : NSObject

/**
 *  The ID of the client which the conversation belongs to.
 */
@property (nonatomic, copy, readonly, nullable) NSString       *clientId;

/**
 *  The ID of the conversation.
 */
@property (nonatomic, copy, readonly, nullable) NSString       *conversationId;

/**
 *  The clientId of the conversation creator.
 */
@property (nonatomic, copy, readonly, nullable) NSString       *creator;

/**
 *  The creation time of the conversation.
 */
@property (nonatomic, strong, readonly, nullable) NSDate       *createAt;

/**
 *  The last updating time of the conversation. When fields like name, members changes, this time will changes.
 */
@property (nonatomic, strong, readonly, nullable) NSDate       *updateAt;

/**
 *  The last message in this conversation.
 *  @attention Getter method may query lastMessage from SQL, this may take a long time, be careful to use getter method in main thread.
 */
@property (nonatomic, strong, readonly, nullable) AVIMMessage  *lastMessage;

/**
 *  The send timestamp of the last message in this conversation.
 */
@property (nonatomic, strong, readonly, nullable) NSDate       *lastMessageAt;

/**
 *  The name of this conversation. Can be changed by update:callback: .
 */
@property (nonatomic, copy, readonly, nullable) NSString     *name;

/**
 *  The ids of the clients who join the conversation. Can be changed by addMembersWithClientIds:callback: or removeMembersWithClientIds:callback: .
 */
@property (nonatomic, strong, readonly, nullable) NSArray      *members;

/**
 *  The attributes of the conversation. Intend to save any extra data of the conversation.
 *  Can be set when creating the conversation or can be updated by update:callback: .
 */
@property (nonatomic, strong, readonly, nullable) NSDictionary *attributes;

/**
 *  Indicate whether it is a transient conversation. 
 *  @see AVIMConversationOptionTransient
 */
@property (nonatomic, assign, readonly) BOOL transient;

/**
 *  Muting status. If muted, when you have offline messages, will not receive Apple APNS notification.
 *  Can be changed by muteWithCallback: or unmuteWithCallback:.
 */
@property (nonatomic, assign, readonly) BOOL muted;

/**
 *  The AVIMClient object which this conversation belongs to.
 */
@property (nonatomic, weak, readonly, nullable)   AVIMClient   *imClient;

/**
 * Add custom property for conversation.
 *
 * @param object The property value.
 * @param key    The property name.
 */
- (void)setObject:(nullable id)object forKey:(NSString *)key;

/*!
 * Get custom property value for conversation.
 * @param key The custom property name.
 * @return The custom property value.
 */
- (nullable id)objectForKey:(NSString *)key;

/*!
 创建一个 AVIMKeyedConversation 对象。用于序列化，方便保存在本地。
 @return AVIMKeyedConversation 对象。
 */
- (AVIMKeyedConversation *)keyedConversation;

/*!
 拉取服务器最新数据。
 @param callback － 结果回调
 @return None.
 */
- (void)fetchWithCallback:(AVIMBooleanResultBlock)callback;

/*!
 发送更新。
 @param callback － 结果回调
 @return None.
 */
- (void)updateWithCallback:(AVIMBooleanResultBlock)callback;

/*!
 加入对话。
 @param callback － 结果回调
 @return None.
 */
- (void)joinWithCallback:(AVIMBooleanResultBlock)callback;

/*!
 离开对话。
 @param callback － 结果回调
 @return None.
 */
- (void)quitWithCallback:(AVIMBooleanResultBlock)callback;

/*!
 静音，不再接收此对话的离线推送。
 @param callback － 结果回调
 @return None.
 */
- (void)muteWithCallback:(AVIMBooleanResultBlock)callback;

/*!
 取消静音，开始接收此对话的离线推送。
 @param callback － 结果回调
 @return None.
 */
- (void)unmuteWithCallback:(AVIMBooleanResultBlock)callback;

/*!
 标记该会话已读。
 将服务端该会话的未读消息数置零。
 */
- (void)markAsReadInBackground;

/*!
 标记该消息已读。
 @attention 服务端会将对话最后一条消息之前的消息状态都标记为已读。
 */
- (void)markAsReadInBackgroundForLastMessage;

/*!
 标记该消息已读。
 @param callback － 结果回调
 @attention 服务端会将对话最后一条消息之前的消息状态都标记为已读。
 */
- (void)markAsReadInBackgroundForLastMessageWithCallback:(AVIMBooleanResultBlock)callback;

/*!
 邀请新成员加入对话。
 @param clientIds － 成员列表
 @param callback － 结果回调
 @return None.
 */
- (void)addMembersWithClientIds:(NSArray *)clientIds
                       callback:(AVIMBooleanResultBlock)callback;

/*!
 从对话踢出部分成员。
 @param clientIds － 成员列表
 @param callback － 结果回调
 @return None.
 */
- (void)removeMembersWithClientIds:(NSArray *)clientIds
                          callback:(AVIMBooleanResultBlock)callback;

/*!
 查询成员人数（开放群组即为在线人数）。
 @param callback － 结果回调
 @return None.
 */
- (void)countMembersWithCallback:(AVIMIntegerResultBlock)callback;

/*!
 往对话中发送消息。
 @param message － 消息对象
 @param callback － 结果回调
 @return None.
 */
- (void)sendMessage:(AVIMMessage *)message
           callback:(AVIMBooleanResultBlock)callback;

/*!
 往对话中发送消息。
 @param message － 消息对象
 @param option － 消息发送选项
 @param progressBlock - 发送进度回调。仅对文件上传有效，发送文本消息时不进行回调。
 @param callback － 结果回调
 @return None.
 */
- (void)sendMessage:(AVIMMessage *)message
             option:(nullable AVIMMessageOption *)option
           callback:(AVIMBooleanResultBlock)callback;

/*!
 往对话中发送消息。
 @param message － 消息对象
 @param progressBlock - 发送进度回调。仅对文件上传有效，发送文本消息时不进行回调。
 @param callback － 结果回调
 @return None.
 */
- (void)sendMessage:(AVIMMessage *)message
      progressBlock:(nullable AVIMProgressBlock)progressBlock
           callback:(AVIMBooleanResultBlock)callback;

/*!
 往对话中发送消息。
 @param message － 消息对象
 @param option － 消息发送选项
 @param progressBlock - 发送进度回调。仅对文件上传有效，发送文本消息时不进行回调。
 @param callback － 结果回调
 @return None.
 */
- (void)sendMessage:(AVIMMessage *)message
             option:(nullable AVIMMessageOption *)option
      progressBlock:(nullable AVIMProgressBlock)progressBlock
           callback:(AVIMBooleanResultBlock)callback;

/*!
 从服务端拉取该会话的最近 limit 条消息。
 @param limit 返回结果的数量，默认 20 条，最多 1000 条。
 @param callback 查询结果回调。
 @return None。
 */
- (void)queryMessagesFromServerWithLimit:(NSUInteger)limit
                                callback:(AVIMArrayResultBlock)callback;

/*!
 从缓存中查询该会话的最近 limit 条消息。
 @param limit 返回结果的数量，默认 20 条，最多 1000 条。
 @return 消息数组。
 */
- (NSArray *)queryMessagesFromCacheWithLimit:(NSUInteger)limit;

/*!
 获取该会话的最近 limit 条消息。
 @param limit 返回结果的数量，默认 20 条，最多 1000 条。
 @param callback 查询结果回调。
 @return None。
 */
- (void)queryMessagesWithLimit:(NSUInteger)limit
                      callback:(AVIMArrayResultBlock)callback;

/*!
 查询历史消息，获取某条消息或指定时间戳之前的 limit 条消息。
 @param messageId 此消息以前的消息。
 @param timestamp 此时间以前的消息。
 @param limit 返回结果的数量，默认 20 条，最多 1000 条。
 @param callback 查询结果回调。
 @return None。
 */
- (void)queryMessagesBeforeId:(nullable NSString *)messageId
                    timestamp:(int64_t)timestamp
                        limit:(NSUInteger)limit
                     callback:(AVIMArrayResultBlock)callback;
/*!
 * 拉取服务器最新的回执数据。
 * 该方法仅对“单聊”(也即：成员数为2的对话)有效
 */
- (void)fetchLatestReceiptTimestampIfNeededWithCallback:(AVIMBooleanResultBlock)callback;

@end

@interface AVIMConversation (AVDeprecated)

/*!
 往对话中发送消息。
 @param message － 消息对象
 @param options － 可选参数，可以使用或 “|” 操作表示多个选项
 @param callback － 结果回调
 @return None.
 */
- (void)sendMessage:(AVIMMessage *)message
            options:(AVIMMessageSendOption)options
           callback:(AVIMBooleanResultBlock)callback AVIM_DEPRECATED("Deprecated in AVOSCloudIM SDK 3.4.0. Use -[AVIMConversation sendMessage:option:callback:] instead.");

/*!
 往对话中发送消息。
 @param message － 消息对象
 @param options － 可选参数，可以使用或 “|” 操作表示多个选项
 @param progressBlock - 发送进度回调。仅对文件上传有效，发送文本消息时不进行回调。
 @param callback － 结果回调
 @return None.
 */
- (void)sendMessage:(AVIMMessage *)message
            options:(AVIMMessageSendOption)options
      progressBlock:(nullable AVIMProgressBlock)progressBlock
           callback:(AVIMBooleanResultBlock)callback AVIM_DEPRECATED("Deprecated in AVOSCloudIM SDK 3.4.0. Use -[AVIMConversation sendMessage:option:progressBlock:callback:] instead.");

/*!
 生成一个新的 AVIMConversationUpdateBuilder 实例。用于更新对话。
 @return 新的 AVIMConversationUpdateBuilder 实例.
 */
- (AVIMConversationUpdateBuilder *)newUpdateBuilder AVIM_DEPRECATED("Deprecated in AVOSCloudIM SDK 3.7.0. Use -[AVIMConversation setObject:forKey:] instead.");

/*!
 发送更新。
 @param updateDict － 需要更新的数据，可通过 AVIMConversationUpdateBuilder 生成
 @param callback － 结果回调
 @return None.
 */
- (void)update:(NSDictionary *)updateDict
      callback:(AVIMBooleanResultBlock)callback AVIM_DEPRECATED("Deprecated in AVOSCloudIM SDK 3.7.0. Use -[AVIMConversation updateWithCallback:] instead.");

@end

NS_ASSUME_NONNULL_END
