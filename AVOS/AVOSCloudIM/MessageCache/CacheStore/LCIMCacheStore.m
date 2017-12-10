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

        [db executeUpdate:LCIM_SQL_CREATE_CONVERSATION_TABLE];
    }));
}

- (void)migrateDatabaseIfNeeded:(NSString *)databasePath {
    LCDatabaseMigrator *migrator = [[LCDatabaseMigrator alloc] initWithDatabasePath:databasePath];

    [migrator executeMigrations:@[
                                  
        [LCDatabaseMigration migrationWithBlock:^(LCDatabase *db) {
            // do-nothing operation 1, reserve for compatibility.
        }],
        
        [LCDatabaseMigration migrationWithBlock:^(LCDatabase *db) {
            // do-nothing operation 2, reserve for compatibility.
        }],

        [LCDatabaseMigration migrationWithBlock:^(LCDatabase *db) {
            [db executeUpdate:LCIM_SQL_MESSAGE_MIGRATION_V2];
        }],

        [LCDatabaseMigration migrationWithBlock:^(LCDatabase *db) {
            [db executeUpdate:LCIM_SQL_MESSAGE_MIGRATION_V3];
        }],

        [LCDatabaseMigration migrationWithBlock:^(LCDatabase *db) {
            [db executeStatements:LCIM_SQL_MESSAGE_MIGRATION_V4];
        }],

        [LCDatabaseMigration migrationWithBlock:^(LCDatabase *db) {
            LCResultSet *resultSet = [db executeQuery:LCIM_SQL_MESSAGE_UNIQUE_INDEX_INFO];
            BOOL hasIndex = [resultSet next];

            if (!hasIndex) {
                [db executeStatements:LCIM_SQL_REBUILD_MESSAGE_UNIQUE_INDEX];
            }

            [resultSet close];
        }]
    ]];
}

- (void)dealloc {
    [_databaseQueue close];
}

@end
