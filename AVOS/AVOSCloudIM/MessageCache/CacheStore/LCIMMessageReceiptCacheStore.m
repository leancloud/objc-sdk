//
//  LCIMMessageReceiptCacheStore.m
//  AVOS
//
//  Created by 陈宜龙 on 06/01/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCIMMessageReceiptCacheStore.h"
#import "LCIMMessageReceiptCacheStoreSQL.h"
#import "AVIMMessage.h"
#import "LCDatabaseMigrator.h"
#import "AVIMConversation.h"
#import "LCIMConversationCache.h"

@interface LCIMMessageReceiptCacheStore ()

@property (copy, readwrite) NSString *conversationId;

@end

@implementation LCIMMessageReceiptCacheStore

- (void)databaseQueueDidLoad {
    [self.databaseQueue inDatabase:^(LCDatabase *db) {
        db.logsErrors = LCIM_SHOULD_LOG_ERRORS;
        
        [db executeUpdate:LCIM_SQL_CREATE_MESSAGE_RCP_TABLE];
    }];
    
    [self migrateDatabaseIfNeeded:self.databaseQueue.path];
}

- (void)migrateDatabaseIfNeeded:(NSString *)databasePath {
    LCDatabaseMigrator *migrator = [[LCDatabaseMigrator alloc] initWithDatabasePath:databasePath];
    [migrator executeMigrations:@[
                                  // Migrations of each database version
                                  ]];
}

- (instancetype)initWithClientId:(NSString *)clientId conversationId:(NSString *)conversationId {
    self = [super initWithClientId:clientId];
    
    if (self) {
        _conversationId = [conversationId copy];
    }
    
    return self;
}

- (void)insertMessages:(NSArray *)messages {
    LCIM_OPEN_DATABASE(db, ({
        for (AVIMMessage *message in messages) {
            NSArray *args = [self insertionRecordForMessage:message];
            [db executeUpdate:LCIM_SQL_INSERT_MESSAGE_RCP withArgumentsInArray:args];
        }
    }));
}

- (void)insertMessage:(AVIMMessage *)message {
    [self insertMessages:@[message]];
}

- (void)deleteConversation:(AVIMConversation *)conversation {
    [self deleteConversationForId:conversation.conversationId];
}

- (void)deleteConversationForId:(NSString *)conversationId {
    if (!conversationId) return;
    
    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[conversationId];
        [db executeUpdate:LCIM_SQL_DELETE_CONVERSATION withArgumentsInArray:args];
    }));
}

- (void)updateMessages:(NSArray *)messages {
    LCIM_OPEN_DATABASE(db, ({
        for (AVIMMessage *message in messages) {
            LCIM_OPEN_DATABASE(db, ({
                NSArray *args = [self updationRecordForMessage:message];
                [db executeUpdate:LCIM_SQL_UPDATE_MESSAGE_RCP withArgumentsInArray:args];
            }));
        }
    }));
}

- (void)updateMessage:(NSArray *)message {
    [self updateMessages:@[ message ]];
}

- (int64_t)latestReadTimestampFromPeer {
   __block int64_t readTimestamp = 0;
    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[
                          self.conversationId,
                          @(AVIMMessageStatusRead)
                          ];
        LCResultSet *result  = [db executeQuery:LCIM_SQL_SELECT_READ_TIMESTAMP withArgumentsInArray:args];
        while ([result next]) {
            readTimestamp = [result longLongIntForColumn:LCIM_FIELD_READ_TIMESTAMP];
        }
        
        [result close];
    }));
    
    return readTimestamp;
}

- (int64_t)latestDeliveredTimestampFromPeer {
    __block int64_t deliveredTimestamp = 0;
    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[
                          self.conversationId,
                          @(AVIMMessageStatusDelivered)
                          ];
        LCResultSet *result  = [db executeQuery:LCIM_SQL_SELECT_RECEIPT_TIMESTAMP withArgumentsInArray:args];
        while ([result next]) {
            deliveredTimestamp = [result longLongIntForColumn:LCIM_FIELD_RECEIPT_TIMESTAMP];
        }
        
        [result close];
    }));
    
    return deliveredTimestamp;
}

#pragma mark -
#pragma mark - Private Methods

- (NSNumber *)receiptTimestampForMessage:(AVIMMessage *)message {
    return [NSNumber numberWithDouble:message.deliveredTimestamp];
}

- (NSNumber *)readTimestampForMessage:(AVIMMessage *)message {
    return [NSNumber numberWithDouble:message.readTimestamp];
}

- (NSTimeInterval)currentTimestamp {
    return [[NSDate date] timeIntervalSince1970] * 1000;
}

- (NSArray *)insertionRecordForMessage:(AVIMMessage *)message {
    return @[
             self.conversationId,
             @(message.status),
             [self receiptTimestampForMessage:message],
             [self readTimestampForMessage:message],
             ];
}

- (NSArray *)updationRecordForMessage:(AVIMMessage *)message {
    return @[
             [self receiptTimestampForMessage:message],
             [self readTimestampForMessage:message],
             @(message.status),
             self.conversationId,
             ];
}

@end
