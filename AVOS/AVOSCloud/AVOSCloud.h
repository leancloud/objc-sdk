//
//  paas.h
//  paas
//
//  Created by Zhu Zeng on 2/25/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>

// Public headers

#import "AVAvailability.h"
#import "AVConstants.h"
#import "AVLogger.h"

// Object
#import "AVObject.h"
#import "AVObject+Subclass.h"
#import "AVSubclassing.h"
#import "AVRelation.h"

// Option
#import "AVSaveOption.h"

// Query
#import "AVQuery.h"

// File
#import "AVFile.h"
#import "AVFileQuery.h"

// Geo
#import "AVGeoPoint.h"

// Status
#import "AVStatus.h"

// Push
#import "AVInstallation.h"
#import "AVPush.h"

// User
#import "AVUser.h"
#import "AVAnonymousUtils.h"

// CloudCode
#import "AVCloud.h"
#import "AVCloudQueryResult.h"

// Search
#import "AVSearchQuery.h"
#import "AVSearchSortBuilder.h"

// ACL
#import "AVACL.h"
#import "AVRole.h"

#import "AVCaptcha.h"
#import "AVSMS.h"

// Router
#import "LCRouter.h"

#if !TARGET_OS_WATCH
// Analytics
#import "AVAnalytics.h"
#endif

typedef enum : NSUInteger {
    kAVVerboseShow,
    kAVVerboseNone,
#if DEBUG
    kAVVerboseAuto = kAVVerboseShow
#else
    kAVVerboseAuto = kAVVerboseNone
#endif
} AVVerbosePolicy;

typedef enum AVLogLevel : NSUInteger {
    AVLogLevelNone      = 0,
    AVLogLevelError     = 1 << 0,
    AVLogLevelWarning   = 1 << 1,
    AVLogLevelInfo      = 1 << 2,
    AVLogLevelVerbose   = 1 << 3,
    AVLogLevelDefault   = AVLogLevelError | AVLogLevelWarning
} AVLogLevel;

typedef NS_ENUM(NSInteger, AVServiceModule) {
    AVServiceModuleAPI = 1,
    AVServiceModuleEngine,
    AVServiceModulePush,
    AVServiceModuleRTM,
    AVServiceModuleStatistics
};

NS_ASSUME_NONNULL_BEGIN

/**
 *  AVOSCloud is the main Class for AVOSCloud SDK
 */
@interface AVOSCloud : NSObject

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
          forServiceModule:(AVServiceModule)serviceModule;

// MARK: Last Modify

/**
 *  开启LastModify支持, 减少流量消耗。默认关闭。
 *  @param enabled 开启
 *  @attention 该方法并不会修改任何AVQuery的缓存策略，缓存策略以当前AVQuery的设置为准。该方法仅在进行网络请求时生效。如果想发挥该函数的最大作用，建议在查询时，将缓存策略选择为kAVCachePolicyNetworkOnly
 */
+ (void)setLastModifyEnabled:(BOOL)enabled;

/**
 *  获取是否开启LastModify支持
 */
+ (BOOL)getLastModifyEnabled;

/**
 *  清空LastModify缓存
 */
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
 * Enable logs of all levels and domains. When define DEBUG macro, it's enabled, otherwise, it's not enabled. This is recommended. But you can set it NO, and call AVLogger's methods to control which domains' log should be output.
 */
+ (void)setAllLogsEnabled:(BOOL)enabled;

/**
 *  设置SDK信息显示
 *  @param verbosePolicy SDK信息显示策略，kAVVerboseShow为显示，
 *         kAVVerboseNone为不显示，kAVVerboseAuto在DEBUG时显示
 */
+ (void)setVerbosePolicy:(AVVerbosePolicy)verbosePolicy;

/// Set log level.
/// @param level The level of log.
+ (void)setLogLevel:(AVLogLevel)level;

/// Get log level.
+ (AVLogLevel)logLevel;

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

/*!
 *  验证短信验证码，需要开启手机短信验证 API 选项。
 *  发送验证码给服务器进行验证。
 *  @param code 6位手机验证码
 *  @param phoneNumber 11位电话号码
 *  @param callback 回调结果
 */
+ (void)verifySmsCode:(NSString *)code
    mobilePhoneNumber:(NSString *)phoneNumber
             callback:(AVBooleanResultBlock)callback;

// MARK: Date

/// Get current server date synchronously.
/// @param error Pointer to `NSError *`.
+ (nullable NSDate *)getServerDate:(NSError **)error;

/// Get current server date synchronously.
/// @param error Pointer to `NSError *`.
+ (nullable NSDate *)getServerDateAndThrowsWithError:(NSError **)error;

/// Get current server date asynchronously.
/// @param block Result callback.
+ (void)getServerDateWithBlock:(void (^)(NSDate *_Nullable date, NSError *_Nullable error))block;

// MARK: Push

/// Convenient method for setting the device token of APNs and the team ID of Apple Developer Account.
/// @param deviceToken The device token of APNs.
/// @param teamId The team ID of Apple Developer Account.
+ (void)handleRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
                                          teamId:(NSString *)teamId;

/// Convenient method for setting the device token of APNs and the team ID of Apple Developer Account.
/// @param deviceToken The device token of APNs.
/// @param teamId The team ID of Apple Developer Account.
/// @param block The constructing block before saving.
+ (void)handleRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
                                          teamId:(NSString *)teamId
               constructingInstallationWithBlock:(nullable void (^)(AVInstallation *))block;

@end

// MARK: Deprecated

@interface AVOSCloud (AVDeprecated)

+ (void)startNetworkStatistics __deprecated;

typedef NS_ENUM(NSInteger, AVStorageType) {
    AVStorageTypeQiniu = 0,
    AVStorageTypeParse,
    AVStorageTypeS3,
    AVStorageTypeQCloud,
    AVStorageTypeDefault = AVStorageTypeQiniu,
} __deprecated;

+ (void)setStorageType:(AVStorageType)type
__deprecated_msg("No need any more, now it is NOP.");

typedef NS_ENUM(NSInteger, AVServiceRegion) {
    AVServiceRegionCN = 1,
    AVServiceRegionUS,
    AVServiceRegionDefault = AVServiceRegionCN,
} __deprecated;

+ (void)setServiceRegion:(AVServiceRegion)region
__deprecated_msg("No need any more, now it is NOP.");

+ (void)setTimeZoneForSecondsFromGMT:(NSInteger)seconds
__deprecated_msg("No need any more, now it is NOP.");

/*!
 *  请求短信验证码，需要开启手机短信验证 API 选项。
 *  发送短信到指定的手机上，发送短信到指定的手机上，获取6位数字验证码。
 *  @param phoneNumber 11位电话号码
 *  @param callback 回调结果
 */
+(void)requestSmsCodeWithPhoneNumber:(NSString *)phoneNumber
                            callback:(AVBooleanResultBlock)callback
__deprecated_msg("deprecated, use +[AVSMS requestShortMessageForPhoneNumber:options:callback:] instead.");

/*!
 *  请求短信验证码，需要开启手机短信验证 API 选项。
 *  发送短信到指定的手机上，获取6位数字验证码。
 *  @param phoneNumber 11位电话号码
 *  @param appName 应用名称，传nil为默认值您的应用名称
 *  @param operation 操作名称，传nil为默认值"短信认证"
 *  @param ttl 短信过期时间，单位分钟，传0为默认值10分钟
 *  @param callback 回调结果
 */
+(void)requestSmsCodeWithPhoneNumber:(NSString *)phoneNumber
                             appName:(nullable NSString *)appName
                           operation:(nullable NSString *)operation
                          timeToLive:(NSUInteger)ttl
                            callback:(AVBooleanResultBlock)callback
__deprecated_msg("deprecated, use +[AVSMS requestShortMessageForPhoneNumber:options:callback:] instead.");

/*!
 *  请求短信验证码，需要开启手机短信验证 API 选项。
 *  发送短信到指定的手机上，获取6位数字验证码。
 *  @param phoneNumber 11位电话号码
 *  @param templateName 模板名称，传nil为默认模板
 *  @param variables 模板中使用的变量
 *  @param callback 回调结果
 */
+(void)requestSmsCodeWithPhoneNumber:(NSString *)phoneNumber
                        templateName:(nullable NSString *)templateName
                           variables:(nullable NSDictionary *)variables
                            callback:(AVBooleanResultBlock)callback
__deprecated_msg("deprecated, use +[AVSMS requestShortMessageForPhoneNumber:options:callback:] instead.");

/*!
 * 请求语音短信验证码，需要开启手机短信验证 API 选项
 * 发送语音短信到指定手机上
 * @param phoneNumber 11 位电话号码
 * @param IDD 号码的所在地国家代码，如果传 nil，默认为 "+86"
 * @param callback 回调结果
 */
+(void)requestVoiceCodeWithPhoneNumber:(NSString *)phoneNumber
                                   IDD:(nullable NSString *)IDD
                              callback:(AVBooleanResultBlock)callback
__deprecated_msg("deprecated, use +[AVSMS requestShortMessageForPhoneNumber:options:callback:] instead.");

@end

NS_ASSUME_NONNULL_END
