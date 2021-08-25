//
//  LCCacheManager.h
//  LeanCloud
//
//  Created by Summer on 13-3-19.
//  Copyright (c) 2013年 LeanCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LCUtils.h"

@interface LCCacheManager : NSObject

+ (LCCacheManager *)sharedInstance;

// cache
- (void)getWithKey:(NSString *)key maxCacheAge:(NSTimeInterval)maxCacheAge block:(LCIdResultBlock)block;
- (void)saveJSON:(id)JSON forKey:(NSString *)key;

- (BOOL)hasCacheForKey:(NSString *)key;
- (BOOL)hasCacheForMD5Key:(NSString *)key;

// clear
+ (BOOL)clearAllCache;
+ (BOOL)clearCacheMoreThanOneDay;
+ (BOOL)clearCacheMoreThanDays:(NSInteger)numberOfDays;
- (void)clearCacheForKey:(NSString *)key;
- (void)clearCacheForMD5Key:(NSString *)key;
@end
