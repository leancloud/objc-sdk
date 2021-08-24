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

/// The name of the leaderboard.
@property (nonatomic, readonly, nullable) NSString *name;
/// The version of the leaderboard.
@property (nonatomic, readonly) NSInteger version;
/// The value of this statistic.
@property (nonatomic, readonly) double value;
/// If this statistic belongs to one user, this property is nonnull.
@property (nonatomic, readonly, nullable) LCUser *user;
/// If this statistic belongs to one object, this property is nonnull.
@property (nonatomic, readonly, nullable) LCObject *object;
/// If this statistic belongs to one entity, this property is nonnull.
@property (nonatomic, readonly, nullable) NSString *entity;

@end

@interface LCLeaderboardRanking : NSObject

/// The name of the leaderboard.
@property (nonatomic, readonly, nullable) NSString *statisticName;
/// The ranking on the leaderboard.
@property (nonatomic, readonly) NSInteger rank;
/// The value of the statistic.
@property (nonatomic, readonly) double value;
/// The statistics on the other leaderboards.
@property (nonatomic, readonly, nullable) NSArray<LCLeaderboardStatistic *> *includedStatistics;
/// If this ranking belongs to one user, this property is nonnull.
@property (nonatomic, readonly, nullable) LCUser *user;
/// If this ranking belongs to one object, this property is nonnull.
@property (nonatomic, readonly, nullable) LCObject *object;
/// If this ranking belongs to one entity, this property is nonnull.
@property (nonatomic, readonly, nullable) NSString *entity;

@end

@interface LCLeaderboardQueryOption : NSObject

/// Select which key-value will be returned.
@property (nonatomic, nullable) NSArray<NSString *> *selectKeys;
/// Select which pointer's all value will be returned.
@property (nonatomic, nullable) NSArray<NSString *> *includeKeys;

@end

@interface LCLeaderboard : NSObject

/// The name of this leaderboard.
@property (nonatomic, readonly) NSString *statisticName;
/// The start positon of the query, default is `0`.
@property (nonatomic) NSInteger skip;
/// The max results count of the query, default is `20`.
@property (nonatomic) NSInteger limit;
/// The statistics of the other leaderboards will be returned, default is `nil`.
@property (nonatomic, nullable) NSArray<NSString *> *includeStatistics;
/// The version of the leaderboard, default is `0`.
@property (nonatomic) NSInteger version;
/// Whether to return the count of this leaderboard, default is `false`.
@property (nonatomic) BOOL returnCount;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/// Initializing with a name.
/// @param statisticName The name of the leaderboard.
- (instancetype)initWithStatisticName:(NSString *)statisticName;

// MARK: Update & Delete Statistics

/// Update the statistics of the current user.
/// @param statistics The statistics of the current user.
/// @param callback Result callback.
+ (void)updateCurrentUserStatistics:(NSDictionary *)statistics
                           callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

/// Delete the statistics of the current user on the leaderboards.
/// @param statisticNames The name of the leaderboards.
/// @param callback Result callback.
+ (void)deleteCurrentUserStatistics:(NSArray<NSString *> *)statisticNames
                           callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

// MARK: Get One Statistics

/// Get the statistics of the user on the leaderboards.
/// @param userId The object id of the user.
/// @param statisticNames The name of the leaderboards.
/// @param callback Result callback.
+ (void)getStatisticsWithUserId:(NSString *)userId
                 statisticNames:(NSArray<NSString *> * _Nullable)statisticNames
                       callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

/// Get the statistics of the object on the leaderboards.
/// @param objectId The object id of the object.
/// @param statisticNames The name of the leaderboards.
/// @param option The query option.
/// @param callback Result callback.
+ (void)getStatisticsWithObjectId:(NSString *)objectId
                   statisticNames:(NSArray<NSString *> * _Nullable)statisticNames
                           option:(LCLeaderboardQueryOption * _Nullable)option
                         callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

/// Get the statistics of the entity on the leaderboards.
/// @param entity The string of the entity.
/// @param statisticNames The name of the leaderboards.
/// @param callback Result callback.
+ (void)getStatisticsWithEntity:(NSString *)entity
                 statisticNames:(NSArray<NSString *> * _Nullable)statisticNames
                       callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

// MARK: Get Group Statistics

/// Get the statistics of one group users on this leaderboard.
/// @param userIds The object id array of the users.
/// @param callback Result callback.
- (void)getStatisticsWithUserIds:(NSArray<NSString *> *)userIds
                        callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

/// Get the statistics of one group objects on this leaderboard.
/// @param objectIds The object id array of the objects.
/// @param option The query option.
/// @param callback Result callback.
- (void)getStatisticsWithObjectIds:(NSArray<NSString *> *)objectIds
                            option:(LCLeaderboardQueryOption * _Nullable)option
                          callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

/// Get the statistics of one group entities on this leaderboard.
/// @param entities The string array of the entities.
/// @param callback Result callback.
- (void)getStatisticsWithEntities:(NSArray<NSString *> *)entities
                         callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

// MARK: Get Rankings

/// Get rankings of the user on this leaderboard from top.
/// @param option The query option.
/// @param callback Result callback.
- (void)getUserResultsWithOption:(LCLeaderboardQueryOption * _Nullable)option
                        callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

/// Get rankings around one user on this leaderboard.
/// @param userId The object id of the user.
/// @param option The query option.
/// @param callback Result callback.
- (void)getUserResultsAroundUser:(NSString * _Nullable)userId
                          option:(LCLeaderboardQueryOption * _Nullable)option
                        callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

/// Get rankings of the object on this leaderboard from top.
/// @param option The query option.
/// @param callback Result callback.
- (void)getObjectResultsWithOption:(LCLeaderboardQueryOption * _Nullable)option
                          callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

/// Get rankings around one object on this leaderboard.
/// @param objectId The object id of the object.
/// @param option The query option.
/// @param callback Result callback.
- (void)getObjectResultsAroundObject:(NSString * _Nullable)objectId
                              option:(LCLeaderboardQueryOption * _Nullable)option
                            callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

/// Get rankings of the entity on this leaderboard from top.
/// @param callback Result callback.
- (void)getEntityResultsWithCallback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

/// Get rankings around one entity on this leaderboard.
/// @param entity The string of the entity.
/// @param callback Result callback.
- (void)getEntityResultsAroundEntity:(NSString * _Nullable)entity
                            callback:(void (^)(NSArray<LCLeaderboardRanking *> * _Nullable rankings, NSInteger count, NSError * _Nullable error))callback;

@end

NS_ASSUME_NONNULL_END
