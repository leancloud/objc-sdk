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

FOUNDATION_EXPORT NSString *LCIMClientIdKey;
FOUNDATION_EXPORT NSString *LCIMConversationIdKey;
FOUNDATION_EXPORT NSString *LCIMConversationPropertyNameKey;
FOUNDATION_EXPORT NSString *LCIMConversationPropertyValueKey;
FOUNDATION_EXPORT NSNotificationName LCIMConversationPropertyUpdateNotification;

#define LCIM_NOTIFY_PROPERTY_UPDATE(clientId, conversationId, propname, propvalue)  \
do {                                                                                \
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];               \
                                                                                    \
    userInfo[LCIMClientIdKey]                  = (clientId);                        \
    userInfo[LCIMConversationIdKey]            = (conversationId);                  \
    userInfo[LCIMConversationPropertyNameKey]  = (propname);                        \
    userInfo[LCIMConversationPropertyValueKey] = (propvalue);                       \
                                                                                    \
    [[NSNotificationCenter defaultCenter]                                           \
      postNotificationName:LCIMConversationPropertyUpdateNotification               \
      object:nil                                                                    \
      userInfo:userInfo];                                                           \
} while(0)

FOUNDATION_EXPORT NSNotificationName LCIMConversationMessagePatchNotification;
FOUNDATION_EXPORT NSNotificationName LCIMConversationDidReceiveMessageNotification;

@interface AVIMConversation ()

@property (nonatomic, copy)   NSString     *name;
@property (nonatomic, strong) NSDate       *createAt;
@property (nonatomic, strong) NSDate       *updateAt;
@property (nonatomic, strong) AVIMMessage  *lastMessage;
@property (nonatomic, strong) NSDate       *lastMessageAt;
@property (nonatomic, strong) NSDate       *lastReadAt;
@property (nonatomic, strong) NSDate       *lastDeliveredAt;
@property (nonatomic, assign) NSUInteger    unreadMessagesCount;
@property (nonatomic, strong) NSDictionary *attributes;
@property (nonatomic, assign) BOOL          muted;
@property (nonatomic, assign) BOOL          transient;

@property (nonatomic, strong) NSMutableDictionary *properties;

@property (nonatomic, strong) NSHashTable<id<AVIMConversationDelegate>> *delegates;

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

@end
