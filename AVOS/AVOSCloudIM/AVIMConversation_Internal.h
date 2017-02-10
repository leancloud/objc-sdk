//
//  AVIMConversation_Internal.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/12/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMConversation.h"

#define KEY_NAME @"name"
#define KEY_ATTR @"attr"
#define KEY_TIMESTAMP @"timestamp"
#define KEY_DATA @"data"
#define KEY_FROM @"from"
#define KEY_MSGID @"msgId"
#define KEY_LAST_MESSAGE_AT @"lm"
#define KEY_LAST_MESSAGE @"msg"
#define KEY_LAST_MESSAGE_FROM @"msg_from"
#define KEY_LAST_MESSAGE_MID @"msg_mid"
#define KEY_LAST_MESSAGE_TIMESTAMP @"msg_timestamp"


@class AVIMConversationUpdateBuilder;

@interface AVIMConversation ()

@property (nonatomic, copy)   NSString     *name;            /**< 对话名字 */
@property (nonatomic, strong) NSDate       *createAt;        /**< 创建时间 */
@property (nonatomic, strong) NSDate       *updateAt;        /**< 最后更新时间 */
@property (nonatomic, strong) NSDate       *lastMessageAt;   /**< 对话中最后一条消息的发送时间 */
@property (nonatomic, strong) NSDictionary *attributes;      /**< 自定义属性 */
@property (nonatomic, assign) BOOL          muted;           /**< 静音状态 */
@property (nonatomic, assign) BOOL          transient;       /**< 是否为临时会话（开放群组） */
@property (nonatomic, strong) AVIMMessage  *lastMessage;     /**< 对话中最后一条消息 */

@property (nonatomic, assign) int64_t latestReadTimestampFromPeer;

@property (nonatomic, assign) int64_t latestDeliveredTimestampFromPeer;

- (instancetype)initWithConversationId:(NSString *)conversationId;
- (void)setConversationId:(NSString *)conversationId;
- (void)setMembers:(NSArray *)members;
- (void)setCreator:(NSString *)creator;
- (void)setImClient:(AVIMClient *)imClient;
- (void)addMembers:(NSArray *)members;
- (void)addMember:(NSString *)clientId;
- (void)removeMembers:(NSArray *)members;
- (void)removeMember:(NSString *)clientId;

- (void)setKeyedConversation:(AVIMKeyedConversation *)keyedConversation;

+ (NSDictionary *)filterCustomAttributesFromDictionary:(NSDictionary *)dictionary;

@end
