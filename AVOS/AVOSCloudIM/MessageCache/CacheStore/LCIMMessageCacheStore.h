//
//  LCIMMessageCacheStore.h
//  AVOS
//
//  Created by Tang Tianyong on 5/21/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMCacheStore.h"

@class LCIMMessage;

@interface LCIMMessageCacheStore : LCIMCacheStore

@property (nonatomic, readonly, copy) NSString *conversationId;

- (instancetype)initWithClientId:(NSString *)clientId conversationId:(NSString *)conversationId;

- (void)insertOrUpdateMessage:(LCIMMessage *)message;
- (void)insertOrUpdateMessage:(LCIMMessage *)message withBreakpoint:(BOOL)breakpoint;

- (void)insertOrUpdateMessages:(NSArray<LCIMMessage *> *)messages;

- (void)updateBreakpoint:(BOOL)breakpoint forMessages:(NSArray *)messages;
- (void)updateBreakpoint:(BOOL)breakpoint forMessage:(LCIMMessage *)message;

- (void)updateMessageWithoutBreakpoint:(LCIMMessage *)message;

- (void)updateEntries:(NSDictionary<NSString *, id> *)entries forMessageId:(NSString *)messageId;

- (void)deleteMessage:(LCIMMessage *)message;

- (BOOL)containMessage:(LCIMMessage *)message;

- (LCIMMessage *)messageForId:(NSString *)messageId;

- (LCIMMessage *)getMessageById:(NSString *)messageId timestamp:(int64_t)timestamp;

- (LCIMMessage *)nextMessageForId:(NSString *)messageId timestamp:(int64_t)timestamp;

- (NSArray *)messagesBeforeTimestamp:(int64_t)timestamp
                           messageId:(NSString *)messageId
                               limit:(NSUInteger)limit;

- (NSArray *)latestMessagesWithLimit:(NSUInteger)limit;

- (LCIMMessage *)latestNoBreakpointMessage;

- (void)cleanCache;

@end
