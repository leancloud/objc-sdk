//
//  paas.m
//  paas
//
//  Created by Zhu Zeng on 2/25/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "AVOSCloud.h"
#import "LCPaasClient.h"
#import "LCScheduler.h"
#import "LCPersistenceUtils.h"

#import "LCUtils.h"
#import "LCObjectUtils.h"

#import "LCRouter_Internal.h"
#import "LCApplication_Internal.h"

@implementation AVOSCloud

static AVVerbosePolicy gVerbosePolicy = kAVVerboseAuto;

+ (void)setAllLogsEnabled:(BOOL)enabled {
    [LCLogger setAllLogsEnabled:enabled];
}

+ (void)setVerbosePolicy:(AVVerbosePolicy)verbosePolicy {
    gVerbosePolicy = verbosePolicy;
}

+ (void)initializePaasClient
{
    LCPaasClient *paasClient = [LCPaasClient sharedInstance];
    
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
                        format:@"Server URL not found."] ;
        }
    }
    
    [[LCApplication defaultApplication] setWithIdentifier:applicationId
                                                      key:clientKey];
    
    [self initializePaasClient];
}

+ (NSString *)getApplicationId {
    return [[LCApplication defaultApplication] identifierThrowException];
}

+ (NSString *)getClientKey {
    return [[LCApplication defaultApplication] keyThrowException];
}

+ (void)setLastModifyEnabled:(BOOL)enabled {
    [LCPaasClient sharedInstance].isLastModifyEnabled=enabled;
}

/**
 *  获取是否开启LastModify支持
 */
+ (BOOL)getLastModifyEnabled {
    return [LCPaasClient sharedInstance].isLastModifyEnabled;
}

+ (void)clearLastModifyCache {
    [[LCPaasClient sharedInstance] clearLastModifyCache];
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
    return [[LCPaasClient sharedInstance] timeoutInterval];
}

+ (void)setNetworkTimeoutInterval:(NSTimeInterval)time
{
    [[LCPaasClient sharedInstance] setTimeoutInterval:time];
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
    return [LCScheduler sharedInstance].queryCacheExpiredDays;
}

+ (void)setQueryCacheExpiredDays:(NSInteger)days {
    [LCScheduler sharedInstance].queryCacheExpiredDays = days;
}

+ (NSInteger)fileCacheExpiredDays {
    return [LCScheduler sharedInstance].fileCacheExpiredDays;
}

+ (void)setFileCacheExpiredDays:(NSInteger)days {
    [LCScheduler sharedInstance].fileCacheExpiredDays = days;
}

+ (void)verifySmsCode:(NSString *)code
    mobilePhoneNumber:(NSString *)phoneNumber
             callback:(LCBooleanResultBlock)callback
{
    NSParameterAssert(code);
    NSParameterAssert(phoneNumber);
    
    NSString *path=[NSString stringWithFormat:@"verifySmsCode/%@",code];
    NSDictionary *params = @{ @"mobilePhoneNumber": phoneNumber };
    [[LCPaasClient sharedInstance] postObject:path withParameters:params block:^(id object, NSError *error) {
        [LCUtils callBooleanResultBlock:callback error:error];
    }];
}

// MARK: Date

+ (NSDate *)getServerDate:(NSError *__autoreleasing  _Nullable *)errorPtr {
    __block NSDate *date;
    __block NSError *err;
    __block BOOL finished = false;
    [[LCPaasClient sharedInstance] getObject:@"date"
                              withParameters:nil
                                       block:^(id object, NSError *error) {
        if (error) {
            err = error;
        } else {
            date = [AVDate dateFromDictionary:object];
        }
        finished = true;
    }];
    LC_WAIT_TIL_TRUE(finished, 0.1);
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

// MARK: Deprecated

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
+ (void)handleRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
                                          teamId:(NSString *)teamId
{
    [AVOSCloud handleRemoteNotificationsWithDeviceToken:deviceToken
                                                 teamId:teamId
                      constructingInstallationWithBlock:nil];
}

+ (void)handleRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
                                          teamId:(NSString *)teamId
               constructingInstallationWithBlock:(void (^)(LCInstallation *))block
{
    LCInstallation *installation = [LCInstallation defaultInstallation];
    [installation setDeviceTokenFromData:deviceToken
                                  teamId:teamId];
    if (block) {
        block(installation);
    }
    [installation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (error) {
            LCLoggerError(LCLoggerDomainDefault, @"default installation save failed: %@", error);
        } else {
            LCLoggerInfo(LCLoggerDomainDefault, @"default installation save success");
        }
    }];
}

+ (void)setStorageType:(AVStorageType)storageType {}
+ (void)setServiceRegion:(AVServiceRegion)serviceRegion {}
+ (void)setTimeZoneForSecondsFromGMT:(NSInteger)seconds {}

+(void)requestSmsCodeWithPhoneNumber:(NSString *)phoneNumber
                            callback:(LCBooleanResultBlock)callback {
    [self requestSmsCodeWithPhoneNumber:phoneNumber appName:nil operation:nil timeToLive:0 callback:callback];
}

+(void)requestSmsCodeWithPhoneNumber:(NSString *)phoneNumber
                             appName:(NSString *)appName
                           operation:(NSString *)operation
                          timeToLive:(NSUInteger)ttl
                            callback:(LCBooleanResultBlock)callback {
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
                            callback:(LCBooleanResultBlock)callback {
    NSParameterAssert(phoneNumber);
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:phoneNumber forKey:@"mobilePhoneNumber"];
    if (templateName) {
        [dict setObject:templateName forKey:@"template"];
    }
    [dict addEntriesFromDictionary:variables];
    [[LCPaasClient sharedInstance] postObject:@"requestSmsCode" withParameters:dict block:^(id object, NSError *error) {
        [LCUtils callBooleanResultBlock:callback error:error];
    }];
}

+ (void)requestVoiceCodeWithPhoneNumber:(NSString *)phoneNumber
                                    IDD:(NSString *)IDD
                               callback:(LCBooleanResultBlock)callback {
    NSParameterAssert(phoneNumber);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    params[@"smsType"] = @"voice";
    params[@"mobilePhoneNumber"] = phoneNumber;
    
    if (IDD) {
        params[@"IDD"] = IDD;
    }
    
    [[LCPaasClient sharedInstance] postObject:@"requestSmsCode" withParameters:params block:^(id object, NSError *error) {
        [LCUtils callBooleanResultBlock:callback error:error];
    }];
}
#pragma clang diagnostic pop

@end
