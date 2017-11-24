//
//  LCIMMessageCacheStore.h
//  AVOS
//
//  Created by Tang Tianyong on 5/21/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMCacheStore.h"

@class AVIMMessage;

@interface LCIMMessageCacheStore : LCIMCacheStore

@property (nonatomic, readonly, copy) NSString *conversationId;

- (instancetype)initWithClientId:(NSString *)clientId conversationId:(NSString *)conversationId;

- (void)insertOrUpdateMessage:(AVIMMessage *)message;
- (void)insertOrUpdateMessage:(AVIMMessage *)message withBreakpoint:(BOOL)breakpoint;

- (void)insertOrUpdateMessages:(NSArray<AVIMMessage *> *)messages;

- (void)updateBreakpoint:(BOOL)breakpoint forMessages:(NSArray *)messages;
- (void)updateBreakpoint:(BOOL)breakpoint forMessage:(AVIMMessage *)message;

- (void)updateMessageWithoutBreakpoint:(AVIMMessage *)message;

- (void)updateEntries:(NSDictionary<NSString *, id> *)entries forMessageId:(NSString *)messageId;

- (void)deleteMessage:(AVIMMessage *)message;

- (BOOL)containMessage:(AVIMMessage *)message;

- (AVIMMessage *)messageForId:(NSString *)messageId;

- (AVIMMessage *)getMessageById:(NSString *)messageId timestamp:(int64_t)timestamp;

- (AVIMMessage *)nextMessageForId:(NSString *)messageId timestamp:(int64_t)timestamp;

- (NSArray *)messagesBeforeTimestamp:(int64_t)timestamp
                           messageId:(NSString *)messageId
                               limit:(NSUInteger)limit;

- (NSArray *)latestMessagesWithLimit:(NSUInteger)limit;

- (AVIMMessage *)latestNoBreakpointMessage;

- (void)cleanCache;

@end
