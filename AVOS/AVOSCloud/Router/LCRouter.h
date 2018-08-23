//
//  LCRouter.h
//  AVOS
//
//  Created by Tang Tianyong on 5/9/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * const RouterCacheKey NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT RouterCacheKey RouterCacheKeyApp;
FOUNDATION_EXPORT RouterCacheKey RouterCacheKeyRTM;

@interface LCRouter : NSObject

+ (instancetype)sharedInstance;

/**
 Custom API version.

 @param APIVersion Format eg. '1.1'.
 */
+ (void)setAPIVersion:(NSString *)APIVersion;

/**
 Custom RTM router API path.

 @param RTMRouterPath Format eg. '/v1/route'.
 */
+ (void)setRTMRouterPath:(NSString *)RTMRouterPath;

/**
 Custom router cache directory path.

 @param directoryPath Path.
 */
+ (void)setRouterCacheDirectoryPath:(NSString *)directoryPath;

/**
 Clean disk cache.

 @param key Cache type.
 @param error Error.
 */
- (void)cleanCacheWithKey:(RouterCacheKey)key error:(NSError * __autoreleasing *)error;

// MARK: - Deprecated

/// for compatibility
- (NSString *)URLStringForPath:(NSString *)path __deprecated;

@end

NS_ASSUME_NONNULL_END

