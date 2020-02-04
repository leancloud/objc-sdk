//
//  paas.m
//  paas
//
//  Created by Zhu Zeng on 2/25/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "AVOSCloud.h"
#import "AVPaasClient.h"
#import "AVScheduler.h"
#import "AVPersistenceUtils.h"

#if !TARGET_OS_WATCH
#import "AVAnalytics_Internal.h"
#endif

#import "AVUtils.h"
#include "AVOSCloud_Art.inc"
#import "AVAnalyticsUtils.h"
#import "LCNetworkStatistics.h"
#import "AVObjectUtils.h"

#import "LCRouter_Internal.h"

@implementation AVOSCloud {
    NSString *_applicationId;
    NSString *_applicationKey;
    AVVerbosePolicy _verbosePolicy;
}

+ (instancetype)sharedInstance
{
    static AVOSCloud *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AVOSCloud alloc] init];
        instance->_verbosePolicy = kAVVerboseAuto;
    });
    return instance;
}

+ (void)setAllLogsEnabled:(BOOL)enabled {
    [AVLogger setAllLogsEnabled:enabled];
}

+ (void)setVerbosePolicy:(AVVerbosePolicy)verbosePolicy {
    [AVOSCloud sharedInstance]->_verbosePolicy = verbosePolicy;
}

+ (void)logApplicationInfo
{
    const char *s = (const char *)AVOSCloud_Art_inc;
    printf("%s\n", s);
    printf("appid: %s\n", [[self getApplicationId] UTF8String]);
    NSDictionary *dict = [AVAnalyticsUtils deviceInfo];
    for (NSString *key in dict) {
        id value = [dict objectForKey:key];
        printf("%s: %s\n", [key UTF8String], [[NSString stringWithFormat:@"%@", value] UTF8String]);
    }
    printf("----------------------------------------------------------\n");
}

+ (void)initializePaasClient
{
    AVPaasClient *paasClient = [AVPaasClient sharedInstance];
    
    paasClient.applicationId = [self getApplicationId];
    paasClient.clientKey     = [self getClientKey];
    
    // always handle offline requests, include analytics collection
    [paasClient handleAllArchivedRequests];
}

+ (void)setApplicationId:(NSString *)applicationId
               clientKey:(NSString *)clientKey
         serverURLString:(NSString *)serverURLString
{
    [LCRouter setServerURLString:serverURLString];
    [AVOSCloud setApplicationId:applicationId clientKey:clientKey];
}

+ (void)setApplicationId:(NSString *)applicationId
               clientKey:(NSString *)clientKey
{
    AppDomain appDomain = [LCRouter appDomainForAppID:applicationId];
    if ([appDomain isEqualToString:AppDomainCN] ||
        [appDomain isEqualToString:AppDomainCE]) {
        if (![LCRouter serverURLString]) {
            [NSException raise:NSInternalInconsistencyException
                        format:@"Server URL not set."] ;
        }
    }
    
    [AVOSCloud sharedInstance]->_applicationId = applicationId;
    [AVOSCloud sharedInstance]->_applicationKey = clientKey;
    
    [self initializePaasClient];
    
    if ([AVOSCloud sharedInstance]->_verbosePolicy == kAVVerboseShow) {
        [self logApplicationInfo];
    }
}

+ (NSString *)getApplicationId {
    return [AVOSCloud sharedInstance]->_applicationId;
}

+ (NSString *)getClientKey {
    return [AVOSCloud sharedInstance]->_applicationKey;
}

+ (void)setLastModifyEnabled:(BOOL)enabled {
    [AVPaasClient sharedInstance].isLastModifyEnabled=enabled;
}

/**
 *  获取是否开启LastModify支持
 */
+ (BOOL)getLastModifyEnabled {
    return [AVPaasClient sharedInstance].isLastModifyEnabled;
}

+ (void)clearLastModifyCache {
    [[AVPaasClient sharedInstance] clearLastModifyCache];
}

+ (void)setServerURLString:(NSString *)URLString
          forServiceModule:(AVServiceModule)serviceModule
{
    NSString *key = nil;
    switch (serviceModule) {
        case AVServiceModuleAPI:
            key = RouterKeyAppAPIServer;
            break;
        case AVServiceModuleRTM:
            key = RouterKeyAppRTMRouterServer;
            break;
        case AVServiceModulePush:
            key = RouterKeyAppPushServer;
            break;
        case AVServiceModuleEngine:
            key = RouterKeyAppEngineServer;
            break;
        case AVServiceModuleStatistics:
            key = RouterKeyAppStatsServer;
            break;
        default:
            return;
    }
    [LCRouter customAppServerURL:URLString key:key];
}

#pragma mark - Network

+ (NSTimeInterval)networkTimeoutInterval
{
    return [[AVPaasClient sharedInstance] timeoutInterval];
}

+ (void)setNetworkTimeoutInterval:(NSTimeInterval)time
{
    [[AVPaasClient sharedInstance] setTimeoutInterval:time];
}

#pragma mark - Log

static AVLogLevel avlogLevel = AVLogLevelDefault;

+ (void)setLogLevel:(AVLogLevel)level {
    // if log level is too high and is not secret mode
    if ((int)level >= (1 << 4) && !getenv("SHOWMETHEMONEY")) {
        NSLog(@"unsupport log level");
        level = AVLogLevelDefault;
    }
    avlogLevel = level;
}

+ (AVLogLevel)logLevel {
    return avlogLevel;
}

#pragma mark Schedule work

+ (NSInteger)queryCacheExpiredDays {
    return [AVScheduler sharedInstance].queryCacheExpiredDays;
}

+ (void)setQueryCacheExpiredDays:(NSInteger)days {
    [AVScheduler sharedInstance].queryCacheExpiredDays = days;
}

+ (NSInteger)fileCacheExpiredDays {
    return [AVScheduler sharedInstance].fileCacheExpiredDays;
}

+ (void)setFileCacheExpiredDays:(NSInteger)days {
    [AVScheduler sharedInstance].fileCacheExpiredDays = days;
}

+ (void)verifySmsCode:(NSString *)code
    mobilePhoneNumber:(NSString *)phoneNumber
             callback:(AVBooleanResultBlock)callback
{
    NSParameterAssert(code);
    NSParameterAssert(phoneNumber);
    
    NSString *path=[NSString stringWithFormat:@"verifySmsCode/%@",code];
    NSDictionary *params = @{ @"mobilePhoneNumber": phoneNumber };
    [[AVPaasClient sharedInstance] postObject:path withParameters:params block:^(id object, NSError *error) {
        [AVUtils callBooleanResultBlock:callback error:error];
    }];
}

// MARK: Date

+ (NSDate *)getServerDate:(NSError *__autoreleasing  _Nullable *)errorPtr {
    __block NSDate *date;
    __block NSError *err;
    __block BOOL finished = false;
    [[AVPaasClient sharedInstance] getObject:@"date"
                              withParameters:nil
                                       block:^(id object, NSError *error) {
        if (error) {
            err = error;
        } else {
            date = [AVDate dateFromDictionary:object];
        }
        finished = true;
    }];
    AV_WAIT_TIL_TRUE(finished, 0.1);
    if (errorPtr) {
        *errorPtr = err;
    }
    return date;
}

+ (NSDate *)getServerDateAndThrowsWithError:(NSError *__autoreleasing  _Nullable *)error {
    return [self getServerDate:error];
}

+ (void)getServerDateWithBlock:(void (^)(NSDate * _Nullable, NSError * _Nullable))block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSDate *date = [self getServerDate:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(date, error);
        });
    });
}

#pragma mark - Push Notification

+ (void)handleRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
                                          teamId:(NSString *)teamId
{
    [AVOSCloud handleRemoteNotificationsWithDeviceToken:deviceToken
                                                 teamId:teamId
                      constructingInstallationWithBlock:nil];
}

+ (void)handleRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
                                          teamId:(NSString *)teamId
               constructingInstallationWithBlock:(void (^)(AVInstallation *))block
{
    AVInstallation *installation = [AVInstallation defaultInstallation];
    [installation setDeviceTokenFromData:deviceToken
                                  teamId:teamId];
    if (block) {
        block(installation);
    }
    [installation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (error) {
            AVLoggerError(AVLoggerDomainDefault, @"default installation save failed: %@", error);
        } else {
            AVLoggerInfo(AVLoggerDomainDefault, @"default installation save success");
        }
    }];
}

// MARK: Deprecated

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
+ (void)startNetworkStatistics {
    [[LCNetworkStatistics sharedInstance] start];
}

+ (void)setStorageType:(AVStorageType)storageType {}
+ (void)setServiceRegion:(AVServiceRegion)serviceRegion {}
+ (void)setTimeZoneForSecondsFromGMT:(NSInteger)seconds {}

+(void)requestSmsCodeWithPhoneNumber:(NSString *)phoneNumber
                            callback:(AVBooleanResultBlock)callback {
    [self requestSmsCodeWithPhoneNumber:phoneNumber appName:nil operation:nil timeToLive:0 callback:callback];
}

+(void)requestSmsCodeWithPhoneNumber:(NSString *)phoneNumber
                             appName:(NSString *)appName
                           operation:(NSString *)operation
                          timeToLive:(NSUInteger)ttl
                            callback:(AVBooleanResultBlock)callback {
    NSParameterAssert(phoneNumber);
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    //    [dict setObject:phoneNumber forKey:@"mobilePhoneNumber"];
    if (appName) {
        [dict setObject:appName forKey:@"name"];
    }
    if (operation) {
        [dict setObject:operation forKey:@"op"];
    }
    if (ttl > 0) {
        [dict setObject:[NSNumber numberWithUnsignedInteger:ttl] forKey:@"ttl"];
    }
    [self requestSmsCodeWithPhoneNumber:phoneNumber templateName:nil variables:dict callback:callback];
}

+(void)requestSmsCodeWithPhoneNumber:(NSString *)phoneNumber
                        templateName:(NSString *)templateName
                           variables:(NSDictionary *)variables
                            callback:(AVBooleanResultBlock)callback {
    NSParameterAssert(phoneNumber);
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:phoneNumber forKey:@"mobilePhoneNumber"];
    if (templateName) {
        [dict setObject:templateName forKey:@"template"];
    }
    [dict addEntriesFromDictionary:variables];
    [[AVPaasClient sharedInstance] postObject:@"requestSmsCode" withParameters:dict block:^(id object, NSError *error) {
        [AVUtils callBooleanResultBlock:callback error:error];
    }];
}

+ (void)requestVoiceCodeWithPhoneNumber:(NSString *)phoneNumber
                                    IDD:(NSString *)IDD
                               callback:(AVBooleanResultBlock)callback {
    NSParameterAssert(phoneNumber);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    params[@"smsType"] = @"voice";
    params[@"mobilePhoneNumber"] = phoneNumber;
    
    if (IDD) {
        params[@"IDD"] = IDD;
    }
    
    [[AVPaasClient sharedInstance] postObject:@"requestSmsCode" withParameters:params block:^(id object, NSError *error) {
        [AVUtils callBooleanResultBlock:callback error:error];
    }];
}
#pragma clang diagnostic pop

@end
