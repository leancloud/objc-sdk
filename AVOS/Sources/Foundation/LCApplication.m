//
//  LCApplication.m
//  LeanCloud
//
//  Created by pzheng on 2020/05/20.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

#import "LCApplication_Internal.h"
#import "LCPaasClient.h"
#import "LCRouter_Internal.h"
#import "LCScheduler.h"
#import "LCUtils_Internal.h"
#import "LCObjectUtils.h"
#import "LCLogger.h"

@implementation LCApplication

+ (void)setApplicationId:(NSString *)applicationId
               clientKey:(NSString *)clientKey
         serverURLString:(NSString *)serverURLString
{
    [LCRouter setServerURLString:serverURLString];
    [LCApplication setApplicationId:applicationId clientKey:clientKey];
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
    LCPaasClient *paasClient = [LCPaasClient sharedInstance];
    paasClient.application = [LCApplication defaultApplication];
    [paasClient handleAllArchivedRequests];
}

+ (NSString *)getApplicationId {
    return [[LCApplication defaultApplication] identifierThrowException];
}

+ (NSString *)getClientKey {
    return [[LCApplication defaultApplication] keyThrowException];
}

+ (void)setServerURLString:(NSString *)URLString
          forServiceModule:(LCServiceModule)serviceModule
{
    NSString *key = nil;
    switch (serviceModule) {
        case LCServiceModuleAPI:
            key = RouterKeyAppAPIServer;
            break;
        case LCServiceModuleRTM:
            key = RouterKeyAppRTMRouterServer;
            break;
        case LCServiceModulePush:
            key = RouterKeyAppPushServer;
            break;
        case LCServiceModuleEngine:
            key = RouterKeyAppEngineServer;
            break;
        case LCServiceModuleStatistics:
            key = RouterKeyAppStatsServer;
            break;
        default:
            return;
    }
    [LCRouter customAppServerURL:URLString key:key];
}

+ (void)setLastModifyEnabled:(BOOL)enabled {
    [LCPaasClient sharedInstance].isLastModifyEnabled = enabled;
}

+ (BOOL)getLastModifyEnabled {
    return [LCPaasClient sharedInstance].isLastModifyEnabled;
}

+ (void)clearLastModifyCache {
    [[LCPaasClient sharedInstance] clearLastModifyCache];
}

+ (NSTimeInterval)networkTimeoutInterval {
    return [[LCPaasClient sharedInstance] timeoutInterval];
}

+ (void)setNetworkTimeoutInterval:(NSTimeInterval)time {
    [[LCPaasClient sharedInstance] setTimeoutInterval:time];
}

+ (void)setAllLogsEnabled:(BOOL)enabled {
    [LCLogger setAllLogsEnabled:enabled];
}

static LCLogLevel globalLogLevel = LCLogLevelDefault;

+ (void)setLogLevel:(LCLogLevel)level {
    globalLogLevel = level;
}

+ (LCLogLevel)logLevel {
    return globalLogLevel;
}

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
            date = [LCDate dateFromDictionary:object];
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

+ (instancetype)defaultApplication {
    static LCApplication *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LCApplication alloc] init];
    });
    return instance;
}

- (NSString *)serverURLString {
    return [LCRouter serverURLString];
}

- (void)setWithIdentifier:(NSString *)identifier key:(NSString *)key {
    _identifier = [identifier copy];
    _key = [key copy];
}

- (NSString *)identifierThrowException {
    if (!self.identifier) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Application identifier not found."];
    }
    return self.identifier;
}

- (NSString *)keyThrowException {
    if (!self.key) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Application key not found."];
    }
    return self.key;
}

@end
