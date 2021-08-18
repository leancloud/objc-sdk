//
//  LCLeaderboard.h
//  LeanCloudObjc
//
//  Created by pzheng on 2021/08/11.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LCObject;
@class LCUser;

NS_ASSUME_NONNULL_BEGIN

@interface LCLeaderboardStatistic : NSObject

@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly) NSInteger version;
@property (nonatomic, readonly) double value;
@property (nonatomic, readonly, nullable) LCUser *user;
@property (nonatomic, readonly, nullable) LCObject *object;
@property (nonatomic, readonly, nullable) NSString *entity;

@end

@interface LCLeaderboardRanking : NSObject

@property (nonatomic, readonly, nullable) NSString *statisticName;
@property (nonatomic, readonly) NSInteger rank;
@property (nonatomic, readonly) double value;
@property (nonatomic, readonly, nullable) NSArray<LCLeaderboardStatistic *> *includedStatistics;
@property (nonatomic, readonly, nullable) LCUser *user;
@property (nonatomic, readonly, nullable) LCObject *object;
@property (nonatomic, readonly, nullable) NSString *entity;

@end

@interface LCLeaderboardQueryOption : NSObject

@property (nonatomic, nullable) NSArray<NSString *> *selectKeys;
@property (nonatomic, nullable) NSArray<NSString *> *includeKeys;

@end

@interface LCLeaderboard : NSObject

@property (nonatomic, readonly) NSString *statisticName;
@property (nonatomic) NSInteger skip;
@property (nonatomic) NSInteger limit;
@property (nonatomic, nullable) NSArray<NSString *> *includeStatistics;
@property (nonatomic) NSInteger version;
@property (nonatomic) BOOL returnCount;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithStatisticName:(NSString *)statisticName;

// MARK: Update & Delete Statistics

+ (void)updateCurrentUserStatistics:(NSDictionary *)statistics
                           callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

+ (void)deleteCurrentUserStatistics:(NSArray<NSString *> *)statisticNames
                           callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

// MARK: Get One Statistics

+ (void)getStatisticsWithUserId:(NSString *)userId
                 statisticNames:(NSArray<NSString *> * _Nullable)statisticNames
                         option:(LCLeaderboardQueryOption * _Nullable)option
                       callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

+ (void)getStatisticsWithObjectId:(NSString *)objectId
                   statisticNames:(NSArray<NSString *> * _Nullable)statisticNames
                           option:(LCLeaderboardQueryOption * _Nullable)option
                         callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

+ (void)getStatisticsWithEntity:(NSString *)entity
                 statisticNames:(NSArray<NSString *> * _Nullable)statisticNames
                       callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

// MARK: Get Group Statistics

- (void)getStatisticsWithUserIds:(NSArray<NSString *> *)userIds
                          option:(LCLeaderboardQueryOption * _Nullable)option
                        callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

- (void)getStatisticsWithObjectIds:(NSArray<NSString *> *)objectIds
                            option:(LCLeaderboardQueryOption * _Nullable)option
                          callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

- (void)getStatisticsWithEntities:(NSArray<NSString *> *)entities
                         callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

// MARK: Get Rankings

- (void)getUserResultsWithOption:(LCLeaderboardQueryOption * _Nullable)option
                        callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

- (void)getUserResultsAroundUser:(NSString * _Nullable)userId
                          option:(LCLeaderboardQueryOption * _Nullable)option
                        callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

- (void)getObjectResultsWithOption:(LCLeaderboardQueryOption * _Nullable)option
                          callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

- (void)getObjectResultsAroundObject:(NSString * _Nullable)objectId
                              option:(LCLeaderboardQueryOption * _Nullable)option
                            callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

- (void)getEntityResultsWithCallback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

- (void)getEntityResultsAroundEntity:(NSString * _Nullable)entity
                            callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

@end

NS_ASSUME_NONNULL_END
