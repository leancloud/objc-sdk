//
//  LCIMMessageCache.m
//  LeanCloud
//
//  Created by Tang Tianyong on 5/5/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "Foundation.h"

#import "LCPersistenceUtils.h"
#import "LCIMMessageCache.h"
#import "LCIMMessageCacheStore.h"
#import "LCIMMessage.h"
#import "LCIMMessage_Internal.h"
#import "LCIMCommon.h"

@interface LCIMMessageCache ()

@property (readonly) NSString *dbPath;

- (instancetype)initWithClientId:(NSString *)clientId;

/*!
 * Cache store of conversation.
 * @param conversationId Conversation id of the cache store.
 */
- (LCIMMessageCacheStore *)cacheStoreWithConversationId:(NSString *)conversationId;

@end

@implementation LCIMMessageCache

+ (instancetype)cacheWithClientId:(NSString *)clientId {
    return [[self alloc] initWithClientId:clientId];
}

- (instancetype)initWithClientId:(NSString *)clientId {
    self = [super init];

    if (self) {
        _clientId = [clientId copy];
    }

    return self;
}

- (LCIMMessageCacheStore *)cacheStoreWithConversationId:(NSString *)conversationId {
    return [[LCIMMessageCacheStore alloc] initWithClientId:self.clientId conversationId:conversationId];
}

- (NSString *)dbPath {
    return [LCPersistenceUtils messageCacheDatabasePathWithName:self.clientId];
}

- (NSArray *)messagesOrderedByTimestampDescending:(NSArray *)messages {
    NSString *key = NSStringFromSelector(@selector(sendTimestamp));
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:key ascending:NO];

    messages = [messages sortedArrayUsingDescriptors:@[descriptor]];

    return messages;
}

- (NSArray *)messagesBeforeTimestamp:(int64_t)timestamp
                           messageId:(NSString *)messageId
                      conversationId:(NSString *)conversationId
                               limit:(NSUInteger)limit
                          continuous:(BOOL *)continuous
{
    LCIMMessageCacheStore *cacheStore = [self cacheStoreWithConversationId:conversationId];

    NSArray *cachedMessages = [cacheStore messagesBeforeTimestamp:timestamp
                                                        messageId:messageId
                                                            limit:limit];

    if (continuous) {
        *continuous = YES;

        for (LCIMMessage *message in cachedMessages) {
            if (message.breakpoint) {
                *continuous = NO;
                break;
            }
        }
    }

    return cachedMessages;
}

- (NSArray *)trimFirstAndLastObjectFromArray:(NSArray *)array {
    NSMutableArray *mutableArray = [array mutableCopy];

    // Remove latest message
    [mutableArray removeObjectAtIndex:0];

    // Remove newest message
    if ([mutableArray count]) {
        [mutableArray removeObjectAtIndex:[array count] - 1];
    }

    return [mutableArray copy];
}

- (void)addContinuousMessages:(NSArray *)messages forConversationId:(NSString *)conversationId
{
    if (messages.count == 0) { return; }

    NSMutableArray *allMessages = [[self messagesOrderedByTimestampDescending:messages] mutableCopy];

    LCIMMessage *oldestMessage = [allMessages lastObject];
    LCIMMessage *newestMessage = [allMessages firstObject];
    NSArray     *newerMessages = [allMessages subarrayWithRange:NSMakeRange(0, [allMessages count] - 1)];

    /* insert breakpoint message or update oldest message without breakpoint */
    [self insertMessageAndUpdateBreakpoint:oldestMessage forConversationId:conversationId];

    LCIMMessageCacheStore *cacheStore = [self cacheStoreWithConversationId:conversationId];

    BOOL newestMessageExisted = [cacheStore containMessage:newestMessage];

    /* Insert messages and remove their breakpoints */
    [cacheStore insertOrUpdateMessages:newerMessages];

    if (!newestMessageExisted) {
        LCIMMessage *nextMessage = [self nextMessageForMessage:newestMessage conversationId:conversationId];

        if (nextMessage) {
            [cacheStore updateBreakpoint:YES forMessage:nextMessage];
        }
    }
}

- (void)insertMessageAndUpdateBreakpoint:(LCIMMessage *)message forConversationId:(NSString *)conversationId {
    LCIMMessageCacheStore *cacheStore = [self cacheStoreWithConversationId:conversationId];

    if ([cacheStore containMessage:message]) {
        [cacheStore updateMessageWithoutBreakpoint:message];
    } else {
        [cacheStore insertOrUpdateMessage:message];
        [cacheStore updateBreakpoint:YES forMessage:message];
    }
}

- (void)deleteMessages:(NSArray *)messages forConversationId:(NSString *)conversationId {
    LCIMMessageCacheStore *cacheStore = [self cacheStoreWithConversationId:conversationId];

    for (LCIMMessage *message in messages) {
        LCIMMessage *nextMessage = [self nextMessageForMessage:message conversationId:conversationId];

        [cacheStore updateBreakpoint:YES forMessage:nextMessage];
        [cacheStore deleteMessage:message];
    }
}

- (LCIMMessage *)nextMessageForMessage:(LCIMMessage *)message conversationId:(NSString *)conversationId {
    LCIMMessageCacheStore *cacheStore = [self cacheStoreWithConversationId:conversationId];
    LCIMMessage *nextMessage = [cacheStore nextMessageForId:message.messageId timestamp:message.sendTimestamp];

    return nextMessage;
}

- (NSArray *)latestMessagesForConversationId:(NSString *)conversationId limit:(NSUInteger)limit {
    LCIMMessageCacheStore *cacheStore = [self cacheStoreWithConversationId:conversationId];
    NSArray *messages = [cacheStore latestMessagesWithLimit:limit];

    return messages;
}

- (BOOL)containMessage:(LCIMMessage *)message forConversationId:(NSString *)conversationId {
    LCIMMessageCacheStore *cacheStore = [self cacheStoreWithConversationId:conversationId];

    return [cacheStore containMessage:message];
}

- (void)updateMessage:(LCIMMessage *)message forConversationId:(NSString *)conversationId {
    LCIMMessageCacheStore *cacheStore = [self cacheStoreWithConversationId:conversationId];

    [cacheStore updateMessageWithoutBreakpoint:message];
}

- (void)deleteDatabase {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self dbPath]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[self dbPath] error:NULL];
    }
}

- (void)cleanCacheForConversationId:(NSString *)conversationId {
    if (!conversationId) {
        return;
    }

    LCIMMessageCacheStore *cacheStore = [self cacheStoreWithConversationId:conversationId];

    [cacheStore cleanCache];
}

- (void)cleanAllCache {
    [self deleteDatabase];
}

@end
