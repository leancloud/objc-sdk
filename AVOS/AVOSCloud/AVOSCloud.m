//
//  paas.m
//  paas
//
//  Created by Zhu Zeng on 2/25/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "AVOSCloud.h"
#import "AVOSCloud_Internal.h"
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

#import "LCRouter.h"
#import "SDMacros.h"

static AVVerbosePolicy _verbosePolicy = kAVVerboseShow;

static BOOL LCInitialized = NO;

AVServiceRegion LCEffectiveServiceRegion = AVServiceRegionDefault;

static BOOL LCSSLPinningEnabled = false;

@implementation AVOSCloud {
    
    NSString *_applicationId;
    
    NSString *_applicationKey;
}

+ (instancetype)sharedInstance
{
    static AVOSCloud *sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        sharedInstance = [[AVOSCloud alloc] init];
    });
    
    return sharedInstance;
}

+ (void)setSSLPinningEnabled:(BOOL)enabled
{
    if (LCInitialized) {
        
        [NSException raise:NSInternalInconsistencyException
                    format:@"SSL Pinning Enabled should be set before +[AVOSCloud setApplicationId:clientKey:]."];
    }
    
    LCSSLPinningEnabled = enabled;
}

+ (BOOL)isSSLPinningEnabled
{
    return LCSSLPinningEnabled;
}

+ (void)setAllLogsEnabled:(BOOL)enabled {
    [AVLogger setAllLogsEnabled:enabled];
}

+ (void)setVerbosePolicy:(AVVerbosePolicy)verbosePolicy {
    _verbosePolicy = verbosePolicy;
}

+ (void)logApplicationInfo {
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

+ (void)updateRouterInBackground {
    LCRouter *router = [LCRouter sharedInstance];
    [router updateInBackground];
}

+ (void)initializePaasClient {
    AVPaasClient *paasClient = [AVPaasClient sharedInstance];

    paasClient.applicationId = [self getApplicationId];
    paasClient.clientKey     = [self getClientKey];

    // always handle offline requests, include analytics collection
    [paasClient handleAllArchivedRequests];
}

+ (void)setApplicationId:(NSString *)applicationId clientKey:(NSString *)clientKey
{
    [AVOSCloud sharedInstance]->_applicationId = applicationId;
    [AVOSCloud sharedInstance]->_applicationKey = clientKey;

    if (_verbosePolicy == kAVVerboseShow) {
        [self logApplicationInfo];
    }

    [self initializePaasClient];
    [self updateRouterInBackground];
    [[LCNetworkStatistics sharedInstance] start];

#if !TARGET_OS_WATCH
    [AVAnalytics startInternally];
#endif

    LCInitialized = YES;
}

+ (BOOL)isTwoArrayEqual:(NSArray *)array withAnotherArray:(NSArray *)anotherArray
{
    if (array.count != anotherArray.count) {
        return NO;
    }
    
    NSSet *set = [NSSet setWithArray:array];
    NSMutableSet *set1 = [NSMutableSet setWithSet:set];
    NSSet *set2 = [NSSet setWithArray:anotherArray];
    [set1 unionSet:set2];

    return set1.count == array.count;
}

+ (NSString *)getApplicationId
{
    return [AVOSCloud sharedInstance]->_applicationId;
}

+ (NSString *)getClientKey
{
    return [AVOSCloud sharedInstance]->_applicationKey;
}

+ (void)setLastModifyEnabled:(BOOL)enabled{
    [AVPaasClient sharedInstance].isLastModifyEnabled=enabled;
}

/**
 *  获取是否开启LastModify支持
 */
+ (BOOL)getLastModifyEnabled{
    return [AVPaasClient sharedInstance].isLastModifyEnabled;
}

+(void)clearLastModifyCache {
    [[AVPaasClient sharedInstance] clearLastModifyCache];
}

+ (void)setStorageType:(AVStorageType)storageType
{
}

+ (NSString *)pushGroupForServiceRegion:(AVServiceRegion)serviceRegion {
    NSString *pushGroup = nil;

    switch (serviceRegion) {
    case AVServiceRegionCN:
        pushGroup = @"g0";
        break;
    case AVServiceRegionUS:
        pushGroup = @"a0";
        break;
    }

    if (!pushGroup) {
        pushGroup = [self pushGroupForServiceRegion:AVServiceRegionDefault];
    }

    return pushGroup;
}

+ (void)setServiceRegion:(AVServiceRegion)serviceRegion {
    if (LCInitialized) {
        [NSException raise:NSInternalInconsistencyException format:@"Service region should be set before +[AVOSCloud setApplicationId:clientKey:]."];
    }

    LCEffectiveServiceRegion = serviceRegion;
}

+ (NSString *)stringFromServiceModule:(AVServiceModule)serviceModule {
    switch (serviceModule) {
    case AVServiceModuleAPI:
        return LCServiceModuleAPI;
    case AVServiceModuleEngine:
        return LCServiceModuleEngine;
    case AVServiceModulePush:
        return LCServiceModulePush;
    case AVServiceModuleRTM:
        return LCServiceModuleRTM;
    case AVServiceModuleStatistics:
        return LCServiceModuleStatistics;
    }

    return nil;
}

+ (void)setServerURLString:(NSString *)URLString
          forServiceModule:(AVServiceModule)serviceModule
{
    NSString *key = [self stringFromServiceModule:serviceModule];
    [[LCRouter sharedInstance] presetURLString:URLString forServiceModule:key];
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

+(void)verifySmsCode:(NSString *)code mobilePhoneNumber:(NSString *)phoneNumber callback:(AVBooleanResultBlock)callback {
    NSParameterAssert(code);
    NSParameterAssert(phoneNumber);
    
    NSString *path=[NSString stringWithFormat:@"verifySmsCode/%@",code];
    NSDictionary *params = @{ @"mobilePhoneNumber": phoneNumber };
    [[AVPaasClient sharedInstance] postObject:path withParameters:params block:^(id object, NSError *error) {
        [AVUtils callBooleanResultBlock:callback error:error];
    }];
}

+ (NSDate *)getServerDate:(NSError *__autoreleasing *)error {
    __block NSDate *date = nil;
    __block NSError *errorStrong;
    __block BOOL finished = NO;

    [[AVPaasClient sharedInstance] getObject:@"date" withParameters:nil block:^(id object, NSError *error_) {
        if (error) errorStrong = error_;
        if (!error_) date = [AVObjectUtils dateFromDictionary:object];
        finished = YES;
    }];

    AV_WAIT_TIL_TRUE(finished, 0.1);

    if (error) {
        *error = errorStrong;
    }

    return date;
}

+ (NSDate *)getServerDateAndThrowsWithError:(NSError * _Nullable __autoreleasing *)error {
    return [self getServerDate:error];
}

+ (void)getServerDateWithBlock:(void (^)(NSDate *, NSError *))block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSDate  *date  = [self getServerDate:&error];

        [AVUtils callIdResultBlock:block object:date error:error];
    });
}

#pragma mark - Push Notification

+ (void)registerForRemoteNotification {
#if AV_TARGET_OS_IOS
    [self registerForRemoteNotificationTypes:
     UIRemoteNotificationTypeBadge |
     UIRemoteNotificationTypeAlert |
     UIRemoteNotificationTypeSound categories:nil];
#elif AV_TARGET_OS_OSX
    [self registerForRemoteNotificationTypes:
     NSRemoteNotificationTypeAlert |
     NSRemoteNotificationTypeBadge |
     NSRemoteNotificationTypeSound categories:nil];
#endif
}

+ (void)registerForRemoteNotificationTypes:(NSUInteger)types categories:(NSSet *)categories {
#if AV_TARGET_OS_IOS
    UIApplication *application = [UIApplication sharedApplication];

    if ([[UIDevice currentDevice].systemVersion floatValue] < 8.0) {
        [application registerForRemoteNotificationTypes:types];
    } else {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:categories];

        [application registerUserNotificationSettings:settings];
        [application registerForRemoteNotifications];
    }
#elif AV_TARGET_OS_OSX
    NSApplication *application = [NSApplication sharedApplication];
    [application registerForRemoteNotificationTypes:types];
#endif
}

+ (void)handleRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [self handleRemoteNotificationsWithDeviceToken:deviceToken
                                            teamId:nil
                 constructingInstallationWithBlock:nil];
}

+ (void)handleRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
                                          teamId:(NSString *)teamId
{
    [self handleRemoteNotificationsWithDeviceToken:deviceToken
                                            teamId:teamId
                 constructingInstallationWithBlock:nil];
}

+ (void)handleRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
               constructingInstallationWithBlock:(void (^)(AVInstallation *))block
{
    [self handleRemoteNotificationsWithDeviceToken:deviceToken
                                            teamId:nil
                 constructingInstallationWithBlock:block];
}

+ (void)handleRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
                                          teamId:(NSString *)teamId
               constructingInstallationWithBlock:(void (^)(AVInstallation *))block
{
    AVInstallation *installation = [AVInstallation defaultInstallation];

    @weakify(installation, weakInstallation);

    [installation setDeviceTokenFromData:deviceToken
                                  teamId:teamId];

    if (block) {
        block(installation);
    }

    [installation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (error) {
            AVLoggerError(AVLoggerDomainIM, @"Installation saved failed, reason: %@.", error.localizedDescription);
        } else {
            AVLoggerInfo(AVLoggerDomainIM, @"Installation saved OK, object id: %@.", weakInstallation.objectId);
        }
    }];
}

@end
