//
//  LCKeyValueStore.m
//  AVOS
//
//  Created by Tang Tianyong on 6/26/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCKeyValueStore.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"

#define LC_FIELD_KEY    @"key"
#define LC_FIELD_VALUE  @"value"

#define LC_SQL_CREATE_TABLE_FMT             \
    @"CREATE TABLE IF NOT EXISTS %@ ("      \
        LC_FIELD_KEY   @" TEXT, "           \
        LC_FIELD_VALUE @" BLOB, "           \
        @"PRIMARY KEY(" LC_FIELD_KEY @")"   \
    @")"

#define LC_SQL_SELECT_FMT   \
    @"SELECT * FROM %@ WHERE " LC_FIELD_KEY @" = ?"

#define LC_SQL_UPDATE_FMT                           \
    @"INSERT OR REPLACE INTO %@ "                   \
    @"(" LC_FIELD_KEY @", " LC_FIELD_VALUE @") "    \
    @"VALUES(?, ?)"

#define LC_SQL_DELETE_FMT   \
    @"DELETE FROM %@ WHERE " LC_FIELD_KEY @" = ?"

#ifdef DEBUG
    #define LC_SHOULD_LOG_ERRORS YES
#else
    #define LC_SHOULD_LOG_ERRORS NO
#endif

#define LC_OPEN_DATABASE(database, routine) do {                \
    [self.databaseQueue inDatabase:^(FMDatabase *database) {    \
        database.logsErrors = LC_SHOULD_LOG_ERRORS;             \
        routine;                                                \
    }];                                                         \
} while (0)

@interface LCKeyValueStore ()

@property (nonatomic, copy) NSString *databasePath;
@property (nonatomic, copy) NSString *tableName;
@property (nonatomic, readonly, strong) FMDatabaseQueue *databaseQueue;

@end

@implementation LCKeyValueStore

@synthesize databaseQueue = _databaseQueue;

- (instancetype)init {
    return [self initWithDatabasePath:nil tableName:nil];
}

- (instancetype)initWithDatabasePath:(NSString *)databasePath tableName:(NSString *)tableName {
    self = [super init];

    if (self) {
        _databasePath = [databasePath copy];
        _tableName = [tableName copy];
    }

    return self;
}

- (NSString *)formatSQL:(NSString *)SQL withTableName:(NSString *)tableName {
    return [NSString stringWithFormat:SQL, tableName];
}

- (NSData *)dataForKey:(NSString *)key {
    __block NSData *data = nil;

    LC_OPEN_DATABASE(database, ({
        NSArray *args = @[key];
        NSString *SQL = [self formatSQL:LC_SQL_SELECT_FMT withTableName:self.tableName];
        FMResultSet *result = [database executeQuery:SQL withArgumentsInArray:args];

        if ([result next]) {
            data = [result dataForColumn:LC_FIELD_VALUE];
        }

        [result close];
    }));

    return data;
}

- (void)setData:(NSData *)data forKey:(NSString *)key {
    if (!data) {
        [self removeDataForKey:key];
        return;
    }

    LC_OPEN_DATABASE(database, ({
        NSArray *args = @[key, data];
        NSString *SQL = [self formatSQL:LC_SQL_UPDATE_FMT withTableName:self.tableName];
        [database executeUpdate:SQL withArgumentsInArray:args];
    }));
}

- (void)removeDataForKey:(NSString *)key {
    LC_OPEN_DATABASE(database, ({
        NSArray *args = @[key];
        NSString *SQL = [self formatSQL:LC_SQL_DELETE_FMT withTableName:self.tableName];
        [database executeUpdate:SQL withArgumentsInArray:args];
    }));
}

- (void)createSchemeForDatabaseQueue:(FMDatabaseQueue *)dbQueue {
    [dbQueue inDatabase:^(FMDatabase *db) {
        db.logsErrors = LC_SHOULD_LOG_ERRORS;

        NSString *SQL = [self formatSQL:LC_SQL_CREATE_TABLE_FMT withTableName:self.tableName];
        [db executeUpdate:SQL];
    }];
}

- (FMDatabaseQueue *)databaseQueue {
    if (_databaseQueue)
        return _databaseQueue;

    @synchronized (self) {
        if (_databaseQueue)
            return _databaseQueue;

        _databaseQueue = [FMDatabaseQueue databaseQueueWithPath:self.databasePath];
        [self createSchemeForDatabaseQueue:_databaseQueue];

        return _databaseQueue;
    }
}

@end
