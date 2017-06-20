//
//  LCRouter.h
//  AVOS
//
//  Created by Tang Tianyong on 5/9/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVApplication.h"

@class AVRESTClient;

FOUNDATION_EXPORT NSString *const LCServiceModuleAPI;
FOUNDATION_EXPORT NSString *const LCServiceModuleEngine;
FOUNDATION_EXPORT NSString *const LCServiceModulePush;
FOUNDATION_EXPORT NSString *const LCServiceModuleRTM;
FOUNDATION_EXPORT NSString *const LCServiceModuleStatistics;

FOUNDATION_EXPORT NSString *const LCRouterDidUpdateNotification;

@interface LCRouter : NSObject

@property (nonatomic, weak) AVRESTClient *RESTClient;
@property (nonatomic, readonly, copy) AVApplication *application;

- (instancetype)initWithApplication:(AVApplication *)application;

/**
 Get cached RTM server table.
 */
- (NSDictionary *)cachedRTMServerTable;

/**
 Fetch RTM server table asynchronously.

 If fetching did succeed, it will cache the RTM server table for later use.

 @param block The callback of fetching result.
 */
- (void)fetchRTMServerTableInBackground:(void(^)(NSDictionary *RTMServerTable, NSError *error))block;

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
 Update router asynchronously.
 */
- (void)updateInBackground;

@end
