//
//  LCLeaderboard.m
//  LeanCloudObjc
//
//  Created by pzheng on 2021/08/11.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

#import "LCLeaderboard.h"
#import "LCUser.h"
#import "LCUtils.h"
#import "LCErrorUtils.h"
#import "LCPaasClient.h"

@implementation LCLeaderboardStatistic

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _user = (LCUser *)[LCObject objectWithDictionary:[NSDictionary _lc_decoding:dictionary key:@"user"]];
        _name = [NSString _lc_decoding:dictionary key:@"statisticName"];
        _value = [NSNumber _lc_decoding:dictionary key:@"statisticValue"].doubleValue;
        _version = [NSNumber _lc_decoding:dictionary key:@"version"].integerValue;
    }
    return self;
}

@end

@implementation LCLeaderboardRanking

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _rank = [NSNumber _lc_decoding:dictionary key:@"rank"].integerValue;
        _value = [NSNumber _lc_decoding:dictionary key:@"statisticValue"].doubleValue;
        _user = (LCUser *)[LCObject objectWithDictionary:[NSDictionary _lc_decoding:dictionary key:@"user"]];
        _statisticName = [NSString _lc_decoding:dictionary key:@"statisticName"];
        _includedStatistics = ({
            NSMutableArray<LCLeaderboardStatistic *> *statistics = [NSMutableArray array];
            NSArray *dictionaries = [NSArray _lc_decoding:dictionary key:@"statistics"];
            for (NSDictionary *item in dictionaries) {
                if ([NSDictionary _lc_isTypeOf:item]) {
                    LCLeaderboardStatistic *statistic = [[LCLeaderboardStatistic alloc] initWithDictionary:item];
                    [statistics addObject:statistic];
                }
            }
            statistics;
        });
    }
    return self;
}

@end

@implementation LCLeaderboardUserQueryOption

@end

@implementation LCLeaderboard

- (instancetype)initWithStatisticName:(NSString *)statisticName {
    self = [super init];
    if (self) {
        _statisticName = [statisticName copy];
    }
    return self;
}

+ (void)updateStatistics:(NSDictionary *)statistics
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
    NSString *path = [NSString stringWithFormat:@"leaderboard/users/%@/statistics", [LCUser currentUser].objectId];
    [[LCPaasClient sharedInstance] postObject:path withParameters:parameters block:^(id  _Nullable object, NSError * _Nullable error) {
        [self handleStatisticsCallback:callback error:error object:object];
    }];
}

+ (void)getStatisticsWithUserId:(NSString *)userId
                 statisticNames:(NSArray<NSString *> *)statisticNames
                         option:(LCLeaderboardUserQueryOption *)option
                       callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
{
    if (!userId || userId.length == 0) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Parameter `userId` invalid.", nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, error);
        });
        return;
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (statisticNames && statisticNames.count > 0) {
        parameters[@"statistics"] = [statisticNames componentsJoinedByString:@","];
    }
    NSError *error = [self trySetOption:option parameters:parameters];
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, error);
        });
        return;
    }
    NSString *path = [NSString stringWithFormat:@"leaderboard/users/%@/statistics", userId];
    [[LCPaasClient sharedInstance] getObject:path
                              withParameters:(parameters.count > 0 ? parameters : nil)
                                       block:^(id  _Nullable object, NSError * _Nullable error) {
        [self handleStatisticsCallback:callback error:error object:object];
    }];
}

+ (void)deleteStatistics:(NSArray<NSString *> *)statisticNames
                callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    if (![LCUser currentUser].sessionToken) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Please login first.", nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, error);
        });
        return;
    }
    if (!statisticNames || statisticNames.count == 0) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Parameter `statisticNames` invalid.", nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, error);
        });
        return;
    }
    NSString *path = [NSString stringWithFormat:@"leaderboard/users/%@/statistics", [LCUser currentUser].objectId];
    NSDictionary *parameters = @{
        @"statistics" : [statisticNames componentsJoinedByString:@","],
    };
    [[LCPaasClient sharedInstance] deleteObject:path withParameters:parameters block:^(id  _Nullable object, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(!error, error);
        });
    }];
}

- (void)getStatisticsWithUserIds:(NSArray<NSString *> *)userIds
                          option:(LCLeaderboardUserQueryOption *)option
                        callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable, NSError * _Nullable))callback
{
    if (!userIds || userIds.count == 0) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Parameter `userIds` invalid.", nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, error);
        });
        return;
    }
    NSString *path = [NSString stringWithFormat:@"leaderboard/users/statistics/%@", self.statisticName];
    if (option) {
        if (![LCUser currentUser].sessionToken) {
            NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Please login first.", nil);
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil, error);
            });
            return;
        }
        NSMutableArray<NSString *> *queryStrings = [NSMutableArray array];
        if (option.selectKeys && option.selectKeys.count > 0) {
            NSString *selectKeysString = [option.selectKeys componentsJoinedByString:@","];
            NSString *queryString = [NSString stringWithFormat:@"selectUserKeys=%@", selectKeysString];
            [queryStrings addObject:queryString];
        }
        if (option.includeKeys && option.includeKeys.count > 0) {
            NSString *includeKeysString = [option.includeKeys componentsJoinedByString:@","];
            NSString *queryString = [NSString stringWithFormat:@"includeUser=%@", includeKeysString];
            [queryStrings addObject:queryString];
        }
        if (queryStrings.count > 0) {
            path = [path stringByAppendingFormat:@"?%@", [queryStrings componentsJoinedByString:@"&"]];
        }
    }
    [[LCPaasClient sharedInstance] postObject:path withParameters:userIds block:^(id  _Nullable object, NSError * _Nullable error) {
        [[self class] handleStatisticsCallback:callback error:error object:object];
    }];
}

- (void)getResultsWithOption:(LCLeaderboardUserQueryOption *)option
                    callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable, NSInteger, NSError * _Nullable))callback
{
    [self getResultsAroundUser:nil option:option callback:callback];
}

- (void)getResultsAroundUser:(NSString *)userId
                      option:(LCLeaderboardUserQueryOption *)option
                    callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable, NSInteger, NSError * _Nullable))callback
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    NSError *error = [[self class] trySetOption:option parameters:parameters];
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, -1, error);
        });
        return;
    }
    if (self.skip > 0) {
        parameters[@"startPosition"] = @(self.skip);
    }
    if (self.limit > 0) {
        parameters[@"maxResultsCount"] = @(self.limit);
    }
    if (self.includeStatistics && self.includeStatistics.count > 0) {
        parameters[@"includeStatistics"] = [self.includeStatistics componentsJoinedByString:@","];
    }
    if (self.version != nil) {
        parameters[@"version"] = self.version;
    }
    if (self.returnCount) {
        parameters[@"count"] = @1;
    }
    NSString *path = [NSString stringWithFormat:@"leaderboard/leaderboards/user/%@/ranks", self.statisticName];
    if (userId && userId.length > 0) {
        path = [path stringByAppendingPathComponent:userId];
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

+ (NSError *)trySetOption:(LCLeaderboardUserQueryOption * _Nullable)option parameters:(NSMutableDictionary *)parameters {
    if (option) {
        if (![LCUser currentUser].sessionToken) {
            return LCError(LCErrorInternalErrorCodeInconsistency, @"Please login first.", nil);
        }
        if (option.selectKeys && option.selectKeys.count > 0) {
            parameters[@"selectUserKeys"] = [option.selectKeys componentsJoinedByString:@","];
        }
        if (option.includeKeys && option.includeKeys.count > 0) {
            parameters[@"includeUser"] = [option.includeKeys componentsJoinedByString:@","];
        }
    }
    return nil;
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
