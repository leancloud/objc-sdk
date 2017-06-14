//
//  LCIMCacheStore.h
//  AVOS
//
//  Created by Tang Tianyong on 8/29/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LCDB.h"

#ifdef DEBUG
#define LCIM_SHOULD_LOG_ERRORS YES
#else
#define LCIM_SHOULD_LOG_ERRORS NO
#endif

#define LCIM_OPEN_DATABASE(db, routine) do {    \
    FMDatabaseQueue *dbQueue = [self databaseQueue]; \
                                                \
    [dbQueue inDatabase:^(FMDatabase *db) {     \
        db.logsErrors = LCIM_SHOULD_LOG_ERRORS; \
        routine;                                \
    }];                                         \
} while (0)

@interface LCIMCacheStore : NSObject

@property (nonatomic, readonly, copy) NSString *clientId;

+ (NSString *)databasePathWithName:(NSString *)name;

- (instancetype)initWithClientId:(NSString *)clientId;

- (FMDatabaseQueue *)databaseQueue;

@end
