//
//  LCLeaderboard.m
//  LeanCloudObjc
//
//  Created by pzheng on 2021/08/11.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

#import "LCLeaderboard_Internal.h"
#import "LCObject.h"
#import "LCUser.h"
#import "LCUtils.h"
#import "LCErrorUtils.h"
#import "LCPaasClient.h"

@implementation LCLeaderboardStatistic

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _name = [NSString _lc_decoding:dictionary key:@"statisticName"];
        _version = [NSNumber _lc_decoding:dictionary key:@"version"].integerValue;
        _value = [NSNumber _lc_decoding:dictionary key:@"statisticValue"].doubleValue;
        _user = (LCUser *)[LCObject objectWithDictionary:[NSDictionary _lc_decoding:dictionary key:@"user"]];
        _object = [LCObject objectWithDictionary:[NSDictionary _lc_decoding:dictionary key:@"object"]];
        _entity = [NSString _lc_decoding:dictionary key:@"entity"];
    }
    return self;
}

@end

@implementation LCLeaderboardRanking

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _statisticName = [NSString _lc_decoding:dictionary key:@"statisticName"];
        _rank = [NSNumber _lc_decoding:dictionary key:@"rank"].integerValue;
        _value = [NSNumber _lc_decoding:dictionary key:@"statisticValue"].doubleValue;
        _includedStatistics = ({
            NSMutableArray<LCLeaderboardStatistic *> *statistics = [NSMutableArray array];
            NSArray *dictionaries = [NSArray _lc_decoding:dictionary key:@"statistics"];
            for (NSDictionary *item in dictionaries) {
                if ([NSDictionary _lc_isTypeOf:item]) {
                    LCLeaderboardStatistic *statistic = [[LCLeaderboardStatistic alloc] initWithDictionary:item];
                    [statistics addObject:statistic];
                }
            }
            statistics.count > 0 ? statistics : nil;
        });
        _user = (LCUser *)[LCObject objectWithDictionary:[NSDictionary _lc_decoding:dictionary key:@"user"]];
        _object = [LCObject objectWithDictionary:[NSDictionary _lc_decoding:dictionary key:@"object"]];
        _entity = [NSString _lc_decoding:dictionary key:@"entity"];
    }
    return self;
}

@end

@implementation LCLeaderboardQueryOption

@end

@implementation LCLeaderboard

- (instancetype)initWithStatisticName:(NSString *)statisticName {
    self = [super init];
    if (self) {
        _statisticName = [statisticName copy];
        _version = -1;
    }
    return self;
}

// MARK: Update & Delete Statistics

+ (void)updateCurrentUserStatistics:(NSDictionary *)statistics
                           callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
{
    if (![LCUser currentUser].sessionToken) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Please login first.", nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, error);
        });
        return;
    }
    if (!statistics || statistics.count == 0) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Parameter `statistics` invalid.", nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, error);
        });
        return;
    }
    [self updateWithIdentity:[LCUser currentUser].objectId
             leaderboardPath:LCLeaderboardPathUsers
                  statistics:statistics
                    callback:callback];
}

+ (void)updateWithIdentity:(NSString *)identity
           leaderboardPath:(LCLeaderboardPath)leaderboardPath
                statistics:(NSDictionary *)statistics
                  callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
{
    NSArray *parameters = ({
        NSMutableArray<NSDictionary *> *parameters = [NSMutableArray array];
        [statistics enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSDictionary *pair = @{
                @"statisticName" : key,
                @"statisticValue" : obj,
            };
            [parameters addObject:pair];
        }];
        parameters;
    });
    NSString *path = [NSString stringWithFormat:@"leaderboard/%@/%@/statistics", leaderboardPath, identity];
    [[LCPaasClient sharedInstance] postObject:path
                               withParameters:parameters
                                        block:^(id  _Nullable object, NSError * _Nullable error) {
        [self handleStatisticsCallback:callback error:error object:object];
    }];
}

+ (void)deleteCurrentUserStatistics:(NSArray<NSString *> *)statisticNames
                           callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    if (![LCUser currentUser].sessionToken) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Please login first.", nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(false, error);
        });
        return;
    }
    if (!statisticNames || statisticNames.count == 0) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Parameter `statisticNames` invalid.", nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(false, error);
        });
        return;
    }
    NSString *path = [NSString stringWithFormat:@"leaderboard/users/%@/statistics", [LCUser currentUser].objectId];
    NSDictionary *parameters = @{
        @"statistics" : [statisticNames componentsJoinedByString:@","],
    };
    [[LCPaasClient sharedInstance] deleteObject:path
                                 withParameters:parameters
                                          block:^(id  _Nullable object, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(!error, error);
        });
    }];
}

// MARK: Get One Statistics

+ (void)getStatisticsWithUserId:(NSString *)userId
                 statisticNames:(NSArray<NSString *> *)statisticNames
                       callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
{
    [self getStatisticsWithIdentity:userId
                    leaderboardPath:LCLeaderboardPathUsers
                     statisticNames:statisticNames
                             option:nil
                           callback:callback];
}

+ (void)getStatisticsWithObjectId:(NSString *)objectId
                   statisticNames:(NSArray<NSString *> *)statisticNames
                           option:(LCLeaderboardQueryOption *)option
                         callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
{
    [self getStatisticsWithIdentity:objectId
                    leaderboardPath:LCLeaderboardPathObjects
                     statisticNames:statisticNames
                             option:option
                           callback:callback];
}

+ (void)getStatisticsWithEntity:(NSString *)entity
                 statisticNames:(NSArray<NSString *> *)statisticNames
                       callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
{
    [self getStatisticsWithIdentity:entity
                    leaderboardPath:LCLeaderboardPathEntities
                     statisticNames:statisticNames
                             option:nil
                           callback:callback];
}

+ (void)getStatisticsWithIdentity:(NSString *)identity
                  leaderboardPath:(LCLeaderboardPath)leaderboardPath
                   statisticNames:(NSArray<NSString *> *)statisticNames
                           option:(LCLeaderboardQueryOption *)option
                         callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
{
    if (!identity || identity.length == 0) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"First parameter invalid.", nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, error);
        });
        return;
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (statisticNames && statisticNames.count > 0) {
        parameters[@"statistics"] = [statisticNames componentsJoinedByString:@","];
    }
    [self trySetOption:option parameters:parameters];
    NSString *path = [NSString stringWithFormat:@"leaderboard/%@/%@/statistics", leaderboardPath, identity];
    [[LCPaasClient sharedInstance] getObject:path
                              withParameters:(parameters.count > 0 ? parameters : nil)
                                       block:^(id  _Nullable object, NSError * _Nullable error) {
        [self handleStatisticsCallback:callback error:error object:object];
    }];
}

// MARK: Get Group Statistics

- (void)getStatisticsWithUserIds:(NSArray<NSString *> *)userIds
                        callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
{
    [self getStatisticsWithIdentities:userIds
                      leaderboardPath:LCLeaderboardPathUsers
                               option:nil
                             callback:callback];
}

- (void)getStatisticsWithObjectIds:(NSArray<NSString *> *)objectIds
                            option:(LCLeaderboardQueryOption *)option
                          callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
{
    [self getStatisticsWithIdentities:objectIds
                      leaderboardPath:LCLeaderboardPathObjects
                               option:option
                             callback:callback];
}

- (void)getStatisticsWithEntities:(NSArray<NSString *> *)entities
                         callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
{
    [self getStatisticsWithIdentities:entities
                      leaderboardPath:LCLeaderboardPathEntities
                               option:nil
                             callback:callback];
}

- (void)getStatisticsWithIdentities:(NSArray<NSString *> *)identities
                    leaderboardPath:(LCLeaderboardPath)leaderboardPath
                             option:(LCLeaderboardQueryOption *)option
                           callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
{
    if (!identities || identities.count == 0) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"First parameter invalid.", nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, error);
        });
        return;
    }
    NSString *path = [NSString stringWithFormat:@"leaderboard/%@/statistics/%@", leaderboardPath, self.statisticName];
    if (option) {
        NSMutableArray<NSString *> *queryStrings = [NSMutableArray array];
        if (option.selectKeys && option.selectKeys.count > 0) {
            NSString *selectKeysString = [option.selectKeys componentsJoinedByString:@","];
            NSString *queryString = [NSString stringWithFormat:@"selectKeys=%@", selectKeysString];
            [queryStrings addObject:queryString];
        }
        if (option.includeKeys && option.includeKeys.count > 0) {
            NSString *includeKeysString = [option.includeKeys componentsJoinedByString:@","];
            NSString *queryString = [NSString stringWithFormat:@"includeKeys=%@", includeKeysString];
            [queryStrings addObject:queryString];
        }
        if (queryStrings.count > 0) {
            path = [path stringByAppendingFormat:@"?%@", [queryStrings componentsJoinedByString:@"&"]];
        }
    }
    [[LCPaasClient sharedInstance] postObject:path
                               withParameters:identities
                                        block:^(id  _Nullable object, NSError * _Nullable error) {
        [[self class] handleStatisticsCallback:callback error:error object:object];
    }];
}

// MARK: Get Rankings

- (void)getUserResultsWithOption:(LCLeaderboardQueryOption *)option
                        callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable, NSInteger, NSError * _Nullable))callback
{
    [self getUserResultsAroundUser:nil
                            option:option
                          callback:callback];
}

- (void)getUserResultsAroundUser:(NSString *)userId
                          option:(LCLeaderboardQueryOption *)option
                        callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable, NSInteger, NSError * _Nullable))callback
{
    [self getResultsAroundIdentity:userId
                   leaderboardPath:LCLeaderboardPathUser
                            option:option
                          callback:callback];
}

- (void)getObjectResultsWithOption:(LCLeaderboardQueryOption *)option
                          callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable, NSInteger, NSError * _Nullable))callback
{
    [self getObjectResultsAroundObject:nil
                                option:option
                              callback:callback];
}

- (void)getObjectResultsAroundObject:(NSString *)objectId
                              option:(LCLeaderboardQueryOption *)option
                            callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable, NSInteger, NSError * _Nullable))callback
{
    [self getResultsAroundIdentity:objectId
                   leaderboardPath:LCLeaderboardPathObject
                            option:option
                          callback:callback];
}

- (void)getEntityResultsWithCallback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable, NSInteger, NSError * _Nullable))callback
{
    [self getEntityResultsAroundEntity:nil
                              callback:callback];
}

- (void)getEntityResultsAroundEntity:(NSString *)entity callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable, NSInteger, NSError * _Nullable))callback
{
    [self getResultsAroundIdentity:entity
                   leaderboardPath:LCLeaderboardPathEntity
                            option:nil
                          callback:callback];
}

- (void)getResultsAroundIdentity:(NSString *)identity
                 leaderboardPath:(LCLeaderboardPath)leaderboardPath
                          option:(LCLeaderboardQueryOption *)option
                        callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable, NSInteger, NSError * _Nullable))callback
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [[self class] trySetOption:option parameters:parameters];
    if (self.skip > 0) {
        parameters[@"startPosition"] = @(self.skip);
    }
    if (self.limit > 0) {
        parameters[@"maxResultsCount"] = @(self.limit);
    }
    if (self.includeStatistics && self.includeStatistics.count > 0) {
        parameters[@"includeStatistics"] = [self.includeStatistics componentsJoinedByString:@","];
    }
    if (self.version > -1) {
        parameters[@"version"] = @(self.version);
    }
    if (self.returnCount) {
        parameters[@"count"] = @1;
    }
    NSString *path = [NSString stringWithFormat:@"leaderboard/leaderboards/%@/%@/ranks", leaderboardPath, self.statisticName];
    if (identity && identity.length > 0) {
        path = [path stringByAppendingPathComponent:identity];
    }
    [[LCPaasClient sharedInstance] getObject:path
                              withParameters:(parameters.count > 0 ? parameters : nil)
                                       block:^(id  _Nullable object, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil, -1, error);
            });
            return;
        }
        if ([NSDictionary _lc_isTypeOf:object]) {
            NSArray *results = [NSArray _lc_decoding:object key:@"results"];
            NSInteger count = [NSNumber _lc_decoding:object key:@"count"].integerValue;
            NSMutableArray<LCLeaderboardRanking *> *rankings = [NSMutableArray array];
            for (NSDictionary *item in results) {
                if ([NSDictionary _lc_isTypeOf:item]) {
                    LCLeaderboardRanking *ranking = [[LCLeaderboardRanking alloc] initWithDictionary:item];
                    [rankings addObject:ranking];
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(rankings, count, nil);
            });
        } else {
            NSError *error = LCError(LCErrorInternalErrorCodeMalformedData, @"Malformed response data.", nil);
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil, -1, error);
            });
        }
    }];
}

// MARK: Misc

+ (void)trySetOption:(LCLeaderboardQueryOption * _Nullable)option parameters:(NSMutableDictionary *)parameters {
    if (option) {
        if (option.selectKeys && option.selectKeys.count > 0) {
            parameters[@"selectKeys"] = [option.selectKeys componentsJoinedByString:@","];
        }
        if (option.includeKeys && option.includeKeys.count > 0) {
            parameters[@"includeKeys"] = [option.includeKeys componentsJoinedByString:@","];
        }
    }
}

+ (void)handleStatisticsCallback:(void (^ _Nonnull)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
                           error:(NSError * _Nullable)error
                          object:(id _Nullable)object
{
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, error);
        });
        return;
    }
    if ([NSDictionary _lc_isTypeOf:object]) {
        NSMutableArray<LCLeaderboardStatistic *> *statistics = [NSMutableArray array];
        NSArray *results = [NSArray _lc_decoding:object key:@"results"];
        for (NSDictionary *item in results) {
            if ([NSDictionary _lc_isTypeOf:item]) {
                LCLeaderboardStatistic *statistic = [[LCLeaderboardStatistic alloc] initWithDictionary:item];
                [statistics addObject:statistic];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(statistics, nil);
        });
    } else {
        NSError *error = LCError(LCErrorInternalErrorCodeMalformedData, @"Malformed response data.", nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, error);
        });
    }
}

@end
