//
//  LCIMCacheStore.m
//  AVOS
//
//  Created by Tang Tianyong on 8/29/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMCacheStore.h"
#import "AVPersistenceUtils.h"
#import "LCIMMessageCacheStoreSQL.h"
#import "LCIMConversationCacheStoreSQL.h"
#import "LCDatabaseMigrator.h"

@interface LCIMCacheStore ()

@property (copy, readwrite) NSString *clientId;

@end

@implementation LCIMCacheStore {
    LCDatabaseQueue *_databaseQueue;
}

+ (NSString *)databasePathWithName:(NSString *)name {
    return [AVPersistenceUtils messageCacheDatabasePathWithName:name];
}

- (instancetype)initWithClientId:(NSString *)clientId {
    self = [super init];

    if (self) {
        _clientId = [clientId copy];
    }

    return self;
}

- (LCDatabaseQueue *)databaseQueue {
    @synchronized(self) {
        if (_databaseQueue)
            return _databaseQueue;

        if (self.clientId) {
            NSString *path = [[self class] databasePathWithName:self.clientId];
            _databaseQueue = [LCDatabaseQueue databaseQueueWithPath:path];

            if (_databaseQueue) {
                [self databaseQueueDidLoad];
                [self migrateDatabaseIfNeeded:path];
            }
        }
    }

    return _databaseQueue;
}

- (void)databaseQueueDidLoad {
    LCIM_OPEN_DATABASE(db, ({
        db.logsErrors = LCIM_SHOULD_LOG_ERRORS;

        [db executeUpdate:LCIM_SQL_CREATE_MESSAGE_TABLE];
        [db executeUpdate:LCIM_SQL_CREATE_MESSAGE_UNIQUE_INDEX];

        [db executeUpdate:LCIM_SQL_CREATE_CONVERSATION_TABLE];
    }));
}

- (void)migrateDatabaseIfNeeded:(NSString *)databasePath {
    LCDatabaseMigrator *migrator = [[LCDatabaseMigrator alloc] initWithDatabasePath:databasePath];

    [migrator executeMigrations:@[
        [LCDatabaseMigration migrationWithBlock:^(LCDatabase *db) {
            [db executeUpdate:@"ALTER TABLE conversation ADD COLUMN muted INTEGER"];
        }],

        [LCDatabaseMigration migrationWithBlock:^(LCDatabase *db) {
            [db executeUpdate:@"ALTER TABLE conversation ADD COLUMN last_message BLOB"];
        }],

        [LCDatabaseMigration migrationWithBlock:^(LCDatabase *db) {
            [db executeUpdate:@"ALTER TABLE message ADD COLUMN read_timestamp REAL"];
        }],

        [LCDatabaseMigration migrationWithBlock:^(LCDatabase *db) {
            [db executeUpdate:@"ALTER TABLE message ADD COLUMN patch_timestamp REAL"];
        }],

        /* Add an auto-increment primary key 'seq'. It has two main purposes:
           1. A secondary sorting for unsent message and sent message whose timestamps are the same.
           2. An index for unsent message which the ID will change after sent.
         */
        [LCDatabaseMigration migrationWithBlock:^(LCDatabase *db) {
            NSString *statements = @("\
CREATE TABLE IF NOT EXISTS message_seq(                                                                          \
    seq INTEGER PRIMARY KEY AUTOINCREMENT, message_id TEXT,                                                      \
    conversation_id TEXT, from_peer_id TEXT, timestamp REAL,                                                     \
    receipt_timestamp REAL, read_timestamp REAL, patch_timestamp REAL,                                           \
    payload BLOB, status INTEGER, breakpoint BOOL);                                                              \
                                                                                                                 \
CREATE UNIQUE INDEX IF NOT EXISTS message_unique_index ON message_seq(conversation_id, message_id, timestamp);   \
                                                                                                                 \
CREATE INDEX IF NOT EXISTS message_index_conversation_id ON message_seq(conversation_id);                        \
CREATE INDEX IF NOT EXISTS message_index_message_id ON message_seq(message_id);                                  \
CREATE INDEX IF NOT EXISTS message_index_timestamp ON message_seq(timestamp);                                    \
                                                                                                                 \
INSERT INTO message_seq(                                                                                         \
    message_id, conversation_id, from_peer_id, payload, timestamp,                                               \
    receipt_timestamp, read_timestamp, patch_timestamp, status, breakpoint)                                      \
SELECT                                                                                                           \
    message_id, conversation_id, from_peer_id, payload, timestamp,                                               \
    receipt_timestamp, read_timestamp, patch_timestamp, status, breakpoint                                       \
FROM message ORDER BY timestamp;                                                                                 \
                                                                                                                 \
DROP TABLE IF EXISTS message;                                                                                    \
ALTER TABLE message_seq RENAME TO message;");
            [db executeStatements:statements];
        }]
    ]];
}

- (void)dealloc {
    [_databaseQueue close];
}

@end
