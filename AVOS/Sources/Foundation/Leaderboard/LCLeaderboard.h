//
//  LCLeaderboard.h
//  LeanCloudObjc
//
//  Created by pzheng on 2021/08/11.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LCUser;

NS_ASSUME_NONNULL_BEGIN

@interface LCLeaderboardStatistic : NSObject

@property (nonatomic, readonly, nullable) LCUser *user;
@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly) double value;
@property (nonatomic, readonly) NSInteger version;

@end

@interface LCLeaderboardRanking : NSObject

@property (nonatomic, readonly) NSInteger rank;
@property (nonatomic, readonly) double value;
@property (nonatomic, readonly, nullable) LCUser *user;
@property (nonatomic, readonly, nullable) NSString *statisticName;
@property (nonatomic, readonly) NSArray<LCLeaderboardStatistic *> *includedStatistics;

@end

@interface LCLeaderboardUserQueryOption : NSObject

@property (nonatomic, nullable) NSArray<NSString *> *selectKeys;
@property (nonatomic, nullable) NSArray<NSString *> *includeKeys;

@end

@interface LCLeaderboard : NSObject

@property (nonatomic, readonly) NSString *statisticName;
@property (nonatomic) NSInteger skip;
@property (nonatomic) NSInteger limit;
@property (nonatomic, nullable) NSArray<NSString *> *includeStatistics;
@property (nonatomic, nullable) NSNumber *version;
@property (nonatomic) BOOL returnCount;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithStatisticName:(NSString *)statisticName;

+ (void)updateStatistics:(NSDictionary *)statistics
                callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

+ (void)getStatisticsWithUserId:(NSString *)userId
                 statisticNames:(NSArray<NSString *> * _Nullable)statisticNames
                         option:(LCLeaderboardUserQueryOption * _Nullable)option
                       callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

+ (void)deleteStatistics:(NSArray<NSString *> *)statisticNames
                callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

- (void)getStatisticsWithUserIds:(NSArray<NSString *> *)userIds
                          option:(LCLeaderboardUserQueryOption * _Nullable)option
                        callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

- (void)getResultsWithOption:(LCLeaderboardUserQueryOption * _Nullable)option
                    callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

- (void)getResultsAroundUser:(NSString * _Nullable)userId
                      option:(LCLeaderboardUserQueryOption * _Nullable)option
                    callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

@end

NS_ASSUME_NONNULL_END
