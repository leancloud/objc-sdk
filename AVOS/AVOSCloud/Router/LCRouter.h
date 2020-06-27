//
//  LCRouter.h
//  AVOS
//
//  Created by Tang Tianyong on 5/9/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * RouterCacheKey NS_STRING_ENUM;
FOUNDATION_EXPORT RouterCacheKey const RouterCacheKeyApp;
FOUNDATION_EXPORT RouterCacheKey const RouterCacheKeyRTM;

@interface LCRouter : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)sharedInstance;

/// Clean disk cache.
/// @param key See `RouterCacheKey`.
/// @param error The pointer to `NSErrorPointer`.
- (void)cleanCacheWithKey:(RouterCacheKey)key
                    error:(NSError **)error;

@end

@interface LCRouter (Deprecated)

- (NSString *)URLStringForPath:(NSString *)path
__deprecated_msg("Deprecated, keep it for compatibility.");

@end

NS_ASSUME_NONNULL_END

