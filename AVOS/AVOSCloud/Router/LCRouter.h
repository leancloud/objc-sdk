//
//  LCRouter.h
//  AVOS
//
//  Created by Tang Tianyong on 5/9/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const LCServiceModuleAPI;
FOUNDATION_EXPORT NSString *const LCServiceModuleEngine;
FOUNDATION_EXPORT NSString *const LCServiceModulePush;
FOUNDATION_EXPORT NSString *const LCServiceModuleRTM;
FOUNDATION_EXPORT NSString *const LCServiceModuleStatistics;

FOUNDATION_EXPORT NSString *const LCRouterDidUpdateNotification;

@interface LCRouter : NSObject

+ (instancetype)sharedInstance;

/**
 Get cached App-Router server table
 */
- (NSDictionary * _Nullable)cachedAppRouterServerTable;

/**
 Get cached RTM server table.
 */
- (NSDictionary * _Nullable)cachedRTMServerTable;

/**
 Fetch RTM server table asynchronously.

 If fetching did succeed, it will cache the RTM server table for later use.

 @param block The callback of fetching result.
 */
- (void)fetchRTMServerTableInBackground:(void(^_Nullable)(NSDictionary *RTMServerTable, NSError *error))block;

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
 Preset URL string for a service module.

 The preset URL has the highest priority, it will override app router's result.

 @param URLString     The URL string of service module.
 @param serviceModule The service module which you want to preset.
 */
- (void)presetURLString:(NSString *)URLString forServiceModule:(NSString *)serviceModule;

/**
 Update router asynchronously.
 */
- (void)updateInBackground;

/**
 Clean router cache.

 @param key Key for cache.
 */
- (void)cleanRouterCacheForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

