//
//  LCRouter.h
//  AVOS
//
//  Created by Tang Tianyong on 5/9/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LCRouter : NSObject

+ (instancetype)sharedInstance;

/**
 Get URL string for RTM router.
 */
- (NSString *)RTMRouterURLString;

/**
 Get URL string for storage server.

 @param path The API endpoint.
 */
- (NSString *)URLStringForPath:(NSString *)path;

/**
 Get batch path for the given path.

 @brief Add a version prefix to the path.
        For example, if the path given by you is "book", this method will return "/1.1/book".

 @param path The API endpoint.
 */
- (NSString *)batchPathForPath:(NSString *)path;

/**
 Cache push router host for service region.

 @param host The push router host to be cached.
 @param TTL  The time-to-live timestamp in seconds.
 */
- (void)cacheRTMRouter:(NSString *)host TTL:(NSTimeInterval)TTL;

/**
 Update router asynchronously.
 */
- (void)updateInBackground;

@end
