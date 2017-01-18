//
//  LCIMMessageReceiptCacheStore.h
//  AVOS
//
//  Created by 陈宜龙 on 06/01/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCIMCacheStore.h"
@class AVIMMessage;
@class AVIMConversation;

@interface LCIMMessageReceiptCacheStore : LCIMCacheStore
@property (nonatomic, readonly, copy) NSString *conversationId;

- (instancetype)initWithClientId:(NSString *)clientId conversationId:(NSString *)conversationId;

- (void)insertMessages:(NSArray *)messages;
- (void)insertMessage:(AVIMMessage *)message;

- (void)deleteConversation:(AVIMConversation *)conversation;

- (void)updateMessages:(NSArray *)messages;
- (void)updateMessage:(NSArray *)message;

- (int64_t)latestReadTimestampFromPeer;

- (int64_t)latestDeliveredTimestampFromPeer;

@end
