//
//  LCLeaderboard_Internal.h
//  LeanCloudObjc
//
//  Created by pzheng on 2021/08/20.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

#import "LCLeaderboard.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString * LCLeaderboardPath NS_STRING_ENUM;
static LCLeaderboardPath const LCLeaderboardPathUsers = @"users";
static LCLeaderboardPath const LCLeaderboardPathObjects = @"objects";
static LCLeaderboardPath const LCLeaderboardPathEntities = @"entities";
static LCLeaderboardPath const LCLeaderboardPathUser = @"user";
static LCLeaderboardPath const LCLeaderboardPathObject = @"object";
static LCLeaderboardPath const LCLeaderboardPathEntity = @"entity";

@interface LCLeaderboard ()

/// For unit testing
+ (void)updateWithIdentity:(NSString *)identity
           leaderboardPath:(LCLeaderboardPath)leaderboardPath
                statistics:(NSDictionary *)statistics
                  callback:(void (^)(NSArray<LCLeaderboardStatistic *> * _Nullable statistics, NSError * _Nullable error))callback;

@end

NS_ASSUME_NONNULL_END
