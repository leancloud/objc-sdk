//
//  LCApplication.h
//  LeanCloud
//
//  Created by pzheng on 2020/05/20.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LCUtils.h"

typedef NS_OPTIONS(NSUInteger, LCLogLevel) {
    LCLogLevelNone      = 0,
    LCLogLevelError     = 1 << 0,
    LCLogLevelWarning   = 1 << 1,
    LCLogLevelInfo      = 1 << 2,
    LCLogLevelVerbose   = 1 << 3,
    LCLogLevelDefault   = LCLogLevelError | LCLogLevelWarning
};

typedef NS_ENUM(NSInteger, LCServiceModule) {
    LCServiceModuleAPI = 1,
    LCServiceModuleEngine,
    LCServiceModulePush,
    LCServiceModuleRTM,
    LCServiceModuleStatistics
};

NS_ASSUME_NONNULL_BEGIN

@interface LCApplication : NSObject

// MARK: ID, Key and Server URL

/// Setup ID, Key and Server URL of the application.
/// @param applicationId The applicaiton id for your LeanCloud application.
/// @param clientKey The client key for your LeanCloud application.
/// @param serverURLString The server url for your LeanCloud application.
+ (void)setApplicationId:(nonnull NSString *)applicationId
               clientKey:(nonnull NSString *)clientKey
         serverURLString:(nonnull NSString *)serverURLString;

/*!
 Sets the applicationId and clientKey of your application.
 @param applicationId The applicaiton id for your LeanCloud application.
 @param clientKey The client key for your LeanCloud application.
 */
+ (void)setApplicationId:(nonnull NSString *)applicationId
               clientKey:(nonnull NSString *)clientKey;

/**
 *  get Application Id
 *
 *  @return Application Id
 */
+ (NSString *)getApplicationId;

/**
 *  get Client Key
 *
 *  @return Client Key
 */
+ (NSString *)getClientKey;

/**
 Custom server URL for specific service module.
 
 @param URLString     The URL string of service module.
 @param serviceModule The service module which you want to customize.
 */
+ (void)setServerURLString:(nullable NSString *)URLString
          forServiceModule:(LCServiceModule)serviceModule;

// MARK: Last Modify

+ (void)setLastModifyEnabled:(BOOL)enabled;
+ (BOOL)getLastModifyEnabled;
+ (void)clearLastModifyCache;

// MARK: HTTP Request Timeout Interval

/**
 *  Get the timeout interval for network requests. Default is 60 seconds.
 *
 *  @return timeout interval
 */
+ (NSTimeInterval)networkTimeoutInterval;

/**
 *  Set the timeout interval for network request.
 *
 *  @param time  timeout interval(seconds)
 */
+ (void)setNetworkTimeoutInterval:(NSTimeInterval)time;

// MARK: Log

/*!
 * Enable logs of all levels and domains. When define DEBUG macro, it's enabled, otherwise, it's not enabled. This is recommended. But you can set it NO, and call LCLogger's methods to control which domains' log should be output.
 */
+ (void)setAllLogsEnabled:(BOOL)enabled;

/// Set log level.
/// @param level The level of log.
+ (void)setLogLevel:(LCLogLevel)level;

/// Get log level.
+ (LCLogLevel)logLevel;

// MARK: Schedule work

/**
 *  get the query cache expired days
 *
 *  @return the query cache expired days
 */
+ (NSInteger)queryCacheExpiredDays;

/**
 *  set Query Cache Expired Days, default is 30 days
 *
 *  @param days the days you want to set
 */
+ (void)setQueryCacheExpiredDays:(NSInteger)days;

/**
 *  get the file cache expired days
 *
 *  @return the file cache expired days
 */
+ (NSInteger)fileCacheExpiredDays;

/**
 *  set File Cache Expired Days, default is 30 days
 *
 *  @param days the days you want to set
 */
+ (void)setFileCacheExpiredDays:(NSInteger)days;

// MARK: SMS

+ (void)verifySmsCode:(NSString *)code
    mobilePhoneNumber:(NSString *)phoneNumber
             callback:(LCBooleanResultBlock)callback;

// MARK: Date

/// Get current server date synchronously.
/// @param error Pointer to `NSError *`.
+ (nullable NSDate *)getServerDate:(NSError **)error;

/// Get current server date synchronously.
/// @param error Pointer to `NSError *`.
+ (nullable NSDate *)getServerDateAndThrowsWithError:(NSError **)error;

/// Get current server date asynchronously.
/// @param block Result callback.
+ (void)getServerDateWithBlock:(void (^)(NSDate * _Nullable date, NSError * _Nullable error))block;

// MARK: Misc

+ (instancetype)defaultApplication;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readonly, nullable) NSString *serverURLString;
@property (nonatomic, copy, nullable) NSString *RTMServer;

- (void)setWithIdentifier:(NSString *)identifier key:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
