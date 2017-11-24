//
//  LCIMMessageCacheStore.m
//  AVOS
//
//  Created by Tang Tianyong on 5/21/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMMessageCacheStore.h"
#import "LCIMMessageCacheStoreSQL.h"
#import "AVIMMessage.h"
#import "AVIMMessage_Internal.h"
#import "AVIMTypedMessage.h"
#import "AVIMTypedMessage_Internal.h"
#import "LCDatabaseMigrator.h"

@interface LCIMMessageCacheStore ()

@property (copy, readwrite) NSString *conversationId;

@end

@implementation LCIMMessageCacheStore

- (instancetype)initWithClientId:(NSString *)clientId conversationId:(NSString *)conversationId {
    self = [super initWithClientId:clientId];

    if (self) {
        _conversationId = [conversationId copy];
    }

    return self;
}

- (NSNumber *)timestampForMessage:(AVIMMessage *)message {
    NSTimeInterval ts = message.sendTimestamp ?: [self currentTimestamp];
    return [NSNumber numberWithDouble:ts];
}

- (NSNumber *)receiptTimestampForMessage:(AVIMMessage *)message {
    return [NSNumber numberWithDouble:message.deliveredTimestamp];
}

- (NSNumber *)readTimestampForMessage:(AVIMMessage *)message {
    return [NSNumber numberWithDouble:message.readTimestamp];
}

- (NSNumber *)patchTimestampForMessage:(AVIMMessage *)message {
    double timestamp = 0;

    if (message.updatedAt)
        timestamp = [message.updatedAt timeIntervalSince1970] * 1000.0;

    return [NSNumber numberWithDouble:timestamp];
}

- (NSDate *)dateFromTimestamp:(double)timestamp {
    if (!timestamp)
        return nil;

    return [NSDate dateWithTimeIntervalSince1970:timestamp / 1000.0];
}

- (NSTimeInterval)currentTimestamp {
    return [[NSDate date] timeIntervalSince1970] * 1000;
}

- (NSArray *)updationRecordForMessage:(AVIMMessage *)message {
    return @[
        message.clientId,
        @(message.mentionAll),
        message.mentionList ? [NSKeyedArchiver archivedDataWithRootObject:message.mentionList] : [NSNull null],
        [self timestampForMessage:message],
        [self receiptTimestampForMessage:message],
        [self readTimestampForMessage:message],
        [self patchTimestampForMessage:message],
        [message.payload dataUsingEncoding:NSUTF8StringEncoding],
        @(message.status),
        self.conversationId,
        message.messageId
    ];
}

- (NSArray *)replacingRecordForMessage:(AVIMMessage *)message withBreakpoint:(BOOL)breakpoint {
    NSAssert(message.seq > 0, @"Message must has a sequence number.");

    NSMutableArray *record = [[self insertionRecordForMessage:message withBreakpoint:breakpoint] mutableCopy];
    [record insertObject:@(message.seq) atIndex:0];

    return record;
}

- (NSArray *)insertionRecordForMessage:(AVIMMessage *)message withBreakpoint:(BOOL)breakpoint {
    return @[
        message.messageId ?: [NSNull null],
        self.conversationId,
        message.clientId,
        @(message.mentionAll),
        message.mentionList ? [NSKeyedArchiver archivedDataWithRootObject:message.mentionList] : [NSNull null],
        [self timestampForMessage:message],
        [self receiptTimestampForMessage:message],
        [self readTimestampForMessage:message],
        [self patchTimestampForMessage:message],
        [message.payload dataUsingEncoding:NSUTF8StringEncoding],
        @(message.status),
        @(breakpoint)
    ];
}

- (void)insertOrUpdateMessage:(AVIMMessage *)message {
    [self insertOrUpdateMessage:message withBreakpoint:NO];
}

- (void)insertOrUpdateMessage:(AVIMMessage *)message withBreakpoint:(BOOL)breakpoint {
    LCIM_OPEN_DATABASE(db, ({
        if (message.seq) {
            NSArray *args = [self replacingRecordForMessage:message withBreakpoint:breakpoint];
            [db executeUpdate:LCIM_SQL_REPLACE_MESSAGE withArgumentsInArray:args];
        } else {
            NSArray *args = [self insertionRecordForMessage:message withBreakpoint:breakpoint];
            [db executeUpdate:LCIM_SQL_INSERT_MESSAGE withArgumentsInArray:args];

            /* Assign sequence number to message. */
            LCResultSet *resultSet = [db executeQuery:LCIM_SQL_LAST_MESSAGE_SEQ];

            if ([resultSet next])
                message.seq = [resultSet longLongIntForColumn:@"seq"];

            [resultSet close];
        }
    }));
}

- (void)insertOrUpdateMessages:(NSArray<AVIMMessage *> *)messages {
    for (AVIMMessage *message in messages)
        [self insertOrUpdateMessage:message];
}

- (void)updateBreakpoint:(BOOL)breakpoint forMessages:(NSArray *)messages {
    LCIM_OPEN_DATABASE(db, ({
        for (AVIMMessage *message in messages) {
            NSArray *args = @[
                @(breakpoint),
                self.conversationId,
                message.messageId
            ];

            [db executeUpdate:LCIM_SQL_UPDATE_MESSAGE_BREAKPOINT withArgumentsInArray:args];
        }
    }));
}

- (void)updateBreakpoint:(BOOL)breakpoint forMessage:(AVIMMessage *)message {
    [self updateBreakpoint:breakpoint forMessages:@[message]];
}

- (void)updateMessageWithoutBreakpoint:(AVIMMessage *)message {
    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = [self updationRecordForMessage:message];
        [db executeUpdate:LCIM_SQL_UPDATE_MESSAGE withArgumentsInArray:args];
    }));
}

- (void)updateEntries:(NSDictionary<NSString *,id> *)entries forMessageId:(NSString *)messageId {
    if (!messageId)
        return;
    if (!entries.count)
        return;

    NSMutableArray *keys   = [NSMutableArray array];
    NSMutableArray *values = [NSMutableArray array];

    for (NSString *key in entries) {
        [keys addObject:key];
        [values addObject:entries[key]];
    }

    NSArray *assignmentPairs = ({
        NSMutableArray *pairs = [NSMutableArray array];
        for (NSString *key in keys)
            [pairs addObject:[NSString stringWithFormat:@"%@ = ?", key]];
        pairs;
    });
    NSString *assignmentClause = [assignmentPairs componentsJoinedByString:@", "];
    NSString *statement = [NSString stringWithFormat:LCIM_SQL_UPDATE_MESSAGE_ENTRIES_FMT, assignmentClause];

    [values addObject:self.conversationId];
    [values addObject:messageId];

    LCIM_OPEN_DATABASE(db, ({
        [db executeUpdate:statement withArgumentsInArray:values];
    }));
}

- (void)deleteMessage:(AVIMMessage *)message {
    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[
            self.conversationId,
            @(message.seq),
            message.messageId ?: [NSNull null]
        ];
        [db executeUpdate:LCIM_SQL_DELETE_MESSAGE withArgumentsInArray:args];
    }));
}

- (BOOL)containMessage:(AVIMMessage *)message {
    return [self messageForId:message.messageId] != nil;
}

- (NSArray *)messagesBeforeTimestamp:(int64_t)timestamp
                           messageId:(NSString *)messageId
                               limit:(NSUInteger)limit
{
    NSMutableArray *messages = [NSMutableArray array];

    LCIM_OPEN_DATABASE(db, ({
        LCResultSet *result = nil;

        if (messageId) {
            NSArray *args = @[self.conversationId, @(timestamp), @(timestamp), messageId, @(limit)];
            result = [db executeQuery:LCIM_SQL_SELECT_MESSAGE_LESS_THAN_TIMESTAMP_AND_ID withArgumentsInArray:args];
        } else {
            NSArray *args = @[self.conversationId, @(timestamp), @(limit)];
            result = [db executeQuery:LCIM_SQL_SELECT_MESSAGE_LESS_THAN_TIMESTAMP withArgumentsInArray:args];
        }

        while ([result next]) {
            [messages insertObject:[self messageForRecord:result] atIndex:0];
        }

        [result close];
    }));

    return messages;
}

- (AVIMMessage *)messageForId:(NSString *)messageId {
    if (!messageId) return nil;

    __block AVIMMessage *message = nil;

    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[self.conversationId, messageId];
        LCResultSet *result = [db executeQuery:LCIM_SQL_SELECT_MESSAGE_BY_ID withArgumentsInArray:args];

        if ([result next]) {
            message = [self messageForRecord:result];
        }

        [result close];
    }));

    return message;
}

- (AVIMMessage *)getMessageById:(NSString *)messageId timestamp:(int64_t)timestamp
{
    if (!messageId || !self.conversationId) { return nil; }
    
    __block AVIMMessage *message = nil;
    
    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[self.conversationId, messageId, @(timestamp)];
        LCResultSet *result = [db executeQuery:LCIM_SQL_SELECT_MESSAGE_BY_ID_AND_TIMESTAMP withArgumentsInArray:args];
        
        if ([result next]) {
            message = [self messageForRecord:result];
        }
        
        [result close];
    }));
    
    return message;
}

- (AVIMMessage *)nextMessageForId:(NSString *)messageId timestamp:(int64_t)timestamp {
    __block AVIMMessage *message = nil;

    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[
            self.conversationId,
            @(timestamp),
            @(timestamp),
            messageId
        ];

        LCResultSet *result = [db executeQuery:LCIM_SQL_SELECT_NEXT_MESSAGE withArgumentsInArray:args];

        if ([result next]) {
            message = [self messageForRecord:result];
        }

        [result close];
    }));

    return message;
}

- (id)messageForRecord:(LCResultSet *)record {
    AVIMMessage *message = nil;

    NSData *data = [record dataForColumn:LCIM_FIELD_PAYLOAD];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    AVIMTypedMessageObject *messageObject = [[AVIMTypedMessageObject alloc] initWithJSON:payload];

    if ([messageObject isValidTypedMessageObject]) {
        message = [AVIMTypedMessage messageWithMessageObject:messageObject];
    } else {
        message = [[AVIMMessage alloc] init];
    }

    message.seq                = [record longLongIntForColumn:@"seq"];
    message.messageId          = [record stringForColumn:LCIM_FIELD_MESSAGE_ID];
    message.conversationId     = [record stringForColumn:LCIM_FIELD_CONVERSATION_ID];
    message.clientId           = [record stringForColumn:LCIM_FIELD_FROM_PEER_ID];
    message.mentionAll         = [record boolForColumn:@"mention_all"];
    message.mentionList        = ({
        NSData *data = [record dataForColumn:@"mention_list"];
        NSArray *mentionList = data ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
        mentionList;
    });
    message.sendTimestamp      = [record longLongIntForColumn:LCIM_FIELD_TIMESTAMP];
    message.deliveredTimestamp = [record longLongIntForColumn:LCIM_FIELD_RECEIPT_TIMESTAMP];
    message.readTimestamp      = [record longLongIntForColumn:LCIM_FIELD_READ_TIMESTAMP];
    message.updatedAt          = [self dateFromTimestamp:[record doubleForColumn:LCIM_FIELD_PATCH_TIMESTAMP]];
    message.content            = payload;
    message.status             = [record intForColumn:LCIM_FIELD_STATUS];
    message.breakpoint         = [record boolForColumn:LCIM_FIELD_BREAKPOINT];
    message.localClientId      = self.clientId;

    return message;
}

- (NSArray *)latestMessagesWithLimit:(NSUInteger)limit {
    NSMutableArray *messages = [[NSMutableArray alloc] init];

    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[self.conversationId, @(limit)];
        LCResultSet *result = [db executeQuery:LCIM_SQL_LATEST_MESSAGE withArgumentsInArray:args];

        while ([result next]) {
            [messages insertObject:[self messageForRecord:result] atIndex:0];
        }

        [result close];
    }));

    return messages;
}

- (AVIMMessage *)latestNoBreakpointMessage {
    __block AVIMMessage *message = nil;

    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[self.conversationId];
        LCResultSet *result = [db executeQuery:LCIM_SQL_LATEST_NO_BREAKPOINT_MESSAGE withArgumentsInArray:args];

        if ([result next]) {
            message = [self messageForRecord:result];
        }

        [result close];
    }));

    return message;
}

- (void)cleanCache {
    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[self.conversationId];
        [db executeUpdate:LCIM_SQL_CLEAN_MESSAGE withArgumentsInArray:args];
    }));
}

@end
