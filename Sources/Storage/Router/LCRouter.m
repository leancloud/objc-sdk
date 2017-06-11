//
//  LCRouter.m
//  AVOS
//
//  Created by Tang Tianyong on 5/9/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import "LCRouter.h"
#import "AVOSCloud.h"
#import "AVPaasClient.h"
#import "LCKeyValueStore.h"

#define APIVersion @"1.1"

static NSString *const routerURLString = @"https://app-router.leancloud.cn/2/route";

NSString *const LCServiceModuleAPI           = @"api_server";
NSString *const LCServiceModuleEngine        = @"engine_server";
NSString *const LCServiceModulePush          = @"push_server";
NSString *const LCServiceModuleRTM           = @"rtm_router_server";
NSString *const LCServiceModuleStatistics    = @"stats_server";

static NSString *const ttlKey                = @"ttl";
static NSString *const lastModifiedKey       = @"last_modified";
static NSString *const serverTableKey        = @"server_table";

static NSString *const LCAppRouterCacheKey   = @"LCAppRouterCacheKey";
static NSString *const LCRTMRouterCacheKey   = @"LCRTMRouterCacheKey";

NSString *const LCRouterDidUpdateNotification = @"LCRouterDidUpdateNotification";

extern AVServiceRegion LCEffectiveServiceRegion;

typedef NS_ENUM(NSInteger, LCServerLocation) {
    LCServerLocationUnknown,
    LCServerLocationUCloud,
    LCServerLocationQCloud,
    LCServerLocationUS
};

@interface LCRouter ()

@property (nonatomic, assign) LCServerLocation serverLocation;

@property (nonatomic, strong) NSDictionary *candidateAPIURLStringTable;
@property (nonatomic, strong) NSDictionary *candidateRTMRouterURLStringTable;
@property (nonatomic, strong) NSDictionary *module2dn;

/// A dictionary holds the preset URLString of each service module.
@property (nonatomic, strong) NSMutableDictionary *presetURLStringTable;

@property (nonatomic,   copy) NSString *lifesavingAPIURLString;
@property (nonatomic,   copy) NSString *lifesavingRTMRouterURLString;

@property (nonatomic, strong) LCKeyValueStore *userDefaults;

@end

@implementation LCRouter

+ (instancetype)sharedInstance {
    static LCRouter *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[LCRouter alloc] init];
    });

    return instance;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        [self doInitialize];
    }

    return self;
}

- (void)doInitialize {
    _serverLocation = [self currentServerLocation];

    _candidateAPIURLStringTable = @{
        @(LCServerLocationUCloud) : @"api.leancloud.cn",
        @(LCServerLocationQCloud) : @"e1-api.leancloud.cn",
        @(LCServerLocationUS)     : @"us-api.leancloud.cn",
    };

    _candidateRTMRouterURLStringTable = @{
        @(LCServerLocationUCloud) : @"router-g0-push.leancloud.cn",
        @(LCServerLocationQCloud) : @"router-q0-push.leancloud.cn",
        @(LCServerLocationUS)     : @"router-a0-push.leancloud.cn"
    };

    _lifesavingAPIURLString       = @"api.leancloud.cn";
    _lifesavingRTMRouterURLString = @"router-g0-push.leancloud.cn";

    _module2dn = @{
        LCServiceModuleAPI        : @"api",
        LCServiceModuleEngine     : @"engine",
        LCServiceModulePush       : @"push",
        LCServiceModuleRTM        : @"rtm",
        LCServiceModuleStatistics : @"stats"
    };

    _presetURLStringTable = [NSMutableDictionary dictionary];

    _userDefaults = [LCKeyValueStore userDefaultsKeyValueStore];
}

- (LCServerLocation)currentServerLocation {
    if (LCEffectiveServiceRegion == AVServiceRegionUS)
        return LCServerLocationUS;

    NSString *appId = [AVOSCloud getApplicationId];

    /* Application is an UCloud if the application id has no suffix. */
    if ([appId rangeOfString:@"-"].location == NSNotFound)
        return LCServerLocationUCloud;

    if ([appId hasSuffix:@"-gzGzoHsz"])
        return LCServerLocationUCloud;
    else if ([appId hasSuffix:@"-9Nh9j0Va"])
        return LCServerLocationQCloud;
    else if ([appId hasSuffix:@"-MdYXbMMI"])
        return LCServerLocationUS;
    else
        return LCServerLocationUnknown;
}

- (NSString *)serviceModuleForPath:(NSString *)path {
    if ([path hasPrefix:@"call"] || [path hasPrefix:@"functions"])
        return LCServiceModuleEngine;
    else if ([path hasPrefix:@"push"] || [path hasPrefix:@"installations"])
        return LCServiceModulePush;
    else if ([path hasPrefix:@"stats"] || [path hasPrefix:@"statistics"] || [path hasPrefix:@"always_collect"])
        return LCServiceModuleStatistics;
    else
        return LCServiceModuleAPI;
}

- (NSString *)fallbackAPIURLString {
    return _candidateAPIURLStringTable[@(_serverLocation)] ?: _lifesavingAPIURLString;
}

- (NSString *)fallbackRTMRouterURLString {
    return _candidateRTMRouterURLStringTable[@(_serverLocation)] ?: _lifesavingRTMRouterURLString;
}

- (void)postUpdateNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:LCRouterDidUpdateNotification object:nil];
}

- (void)cacheServerTable:(NSDictionary *)APIServerTable forKey:(NSString *)key {
    NSDictionary *cacheObject = @{
        serverTableKey: APIServerTable,

        /* Insert last modified timestamp into router table.
         It will be used to check the expiration of itself. */
        lastModifiedKey: @([[NSDate date] timeIntervalSince1970])
    };

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cacheObject];

    [self.userDefaults setData:data forKey:key];

    [self postUpdateNotification];
}

- (NSDictionary *)cachedServerTableForKey:(NSString *)key {
    NSData *data = [self.userDefaults dataForKey:key];

    if (!data)
        return nil;

    NSDictionary *cacheObject = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    if (!cacheObject)
        return nil;

    NSDictionary *serverTable = cacheObject[serverTableKey];

    NSTimeInterval ttl          = [serverTable[ttlKey] doubleValue];
    NSTimeInterval lastModified = [cacheObject[lastModifiedKey] doubleValue];
    NSTimeInterval now          = [[NSDate date] timeIntervalSince1970];

    if (!serverTable || ttl <= 0 || (now < lastModified || now >= (lastModified + ttl))) {
        [self cleanRouterCacheForKey:key];
        [self updateInBackground];
        return nil;
    }

    return serverTable;
}

- (void)cleanRouterCacheForKey:(NSString *)key {
    [self.userDefaults deleteKey:key];

    [self postUpdateNotification];
}

- (void)updateInBackground {
    /* App router 2 is unavailable in US node. */
    if (LCEffectiveServiceRegion == AVServiceRegionUS)
        return;

    NSString *applicationId = [AVOSCloud getApplicationId];

    if (!applicationId) {
        AVLoggerError(AVLoggerDomainStorage, @"LeanCloud SDK not initialized.");
        return;
    }

    NSDictionary *parameters = @{@"appId": applicationId};

    [[AVPaasClient sharedInstance] getObject:routerURLString withParameters:parameters block:^(NSDictionary *result, NSError *error) {
        if (!error && result)
            [self cacheServerTable:result forKey:LCAppRouterCacheKey];
    }];
}

- (NSString *)prefixVersionForPath:(NSString *)path {
    if ([path hasPrefix:@"/" APIVersion])
        return path;
    else if ([path hasPrefix:APIVersion])
        return [@"/" stringByAppendingPathComponent:path];

    NSString *result = [[@"/" stringByAppendingPathComponent:APIVersion] stringByAppendingPathComponent:path];

    return result;
}

- (NSString *)schemePrefixedURLString:(NSString *)URLString {
    NSURL *URL = [NSURL URLWithString:URLString];

    if (URL.scheme
        /* For "example.com:8080", the scheme is "example.com".
           Here, we need a farther check. */
        && [URLString hasPrefix:[URL.scheme stringByAppendingString:@"://"]])
    {
        return URLString;
    }

    URLString = [NSString stringWithFormat:@"https://%@", URLString];

    return URLString;
}

- (NSString *)absoluteURLStringForHost:(NSString *)host path:(NSString *)path {
    NSString *unifiedHost = [self schemePrefixedURLString:host];

    NSURLComponents *URLComponents = [[NSURLComponents alloc] initWithString:unifiedHost];

    if (path.length) {
        NSString *head = URLComponents.path;

        if (head.length)
            path = [head stringByAppendingPathComponent:path];

        NSURL *pathURL = [NSURL URLWithString:path];

        URLComponents.path = pathURL.path;
        URLComponents.query = pathURL.query;
        URLComponents.fragment = pathURL.fragment;
    }

    NSURL *URL = [URLComponents URL];
    NSString *URLString = [URL absoluteString];

    return URLString;
}

- (NSString *)lncldServerForModule:(NSString *)module {
    NSString *dn = self.module2dn[module];

    if (!dn.length)
        return nil;

    NSString *appId = [AVOSCloud getApplicationId];
    NSString *server = [NSString stringWithFormat:@"%@.%@.lncld.net", [appId substringToIndex:8], dn];

    return server;
}

- (NSString *)URLStringForPath:(NSString *)path {
    NSString *URLString = nil;
    NSString *host = nil;
    NSString *presetHost = nil;
    NSString *cachedHost = nil;
    NSString *versionPrefixedPath = nil;
    NSString *module = [self serviceModuleForPath:path];

    presetHost = _presetURLStringTable[module];

    if (presetHost) {
        host = presetHost;
        goto found;
    }

    cachedHost = [self cachedServerTableForKey:LCAppRouterCacheKey][module];

    if (cachedHost) {
        host = cachedHost;
        goto found;
    }

    switch (self.serverLocation) {
    case LCServerLocationUCloud:
        host = [self lncldServerForModule:module] ?: [self fallbackAPIURLString]; break;
    default:
        host = [self fallbackAPIURLString]; break;
    }

found:

    versionPrefixedPath = [self prefixVersionForPath:path];
    URLString = [self absoluteURLStringForHost:host path:versionPrefixedPath];

    return URLString;
}

- (NSString *)RTMRouterURLString {
    NSString *URLString = nil;
    NSString *host = nil;
    NSString *presetHost = nil;
    NSString *cachedHost = nil;

    presetHost = _presetURLStringTable[LCServiceModuleRTM];

    if (presetHost) {
        host = presetHost;
        goto found;
    }

    cachedHost = [self cachedServerTableForKey:LCAppRouterCacheKey][LCServiceModuleRTM];

    if (cachedHost) {
        host = cachedHost;
        goto found;
    }

    switch (self.serverLocation) {
    case LCServerLocationUCloud:
        host = [self lncldServerForModule:LCServiceModuleRTM] ?: [self fallbackRTMRouterURLString]; break;
    default:
        host = [self fallbackRTMRouterURLString]; break;
    }

found:

    URLString = [self absoluteURLStringForHost:host path:@"/v1/route"];

    return URLString;
}

- (NSDictionary *)RTMRouterParameters {
    NSString *appId = [AVOSCloud getApplicationId];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];

    parameters[@"appId"] = appId;
    parameters[@"secure"] = @"1";

    /* Back door for user to connect to puppet environment. */
    if (getenv("LC_IM_PUPPET_ENABLED") && getenv("SIMULATOR_UDID")) {
        parameters[@"debug"] = @"true";
    }

    return parameters;
}

- (void)fetchRTMServerTableInBackground:(void (^)(NSDictionary *RTMServerTable, NSError *error))block {
    NSString *URLString = [self RTMRouterURLString];
    NSDictionary *parameters = [self RTMRouterParameters];

    [[AVPaasClient sharedInstance] getObject:URLString withParameters:parameters block:^(NSDictionary *result, NSError *error) {
        if (!error && result)
            [self cacheServerTable:result forKey:LCRTMRouterCacheKey];
        if (block)
            block(result, error);
    }];
}

- (NSDictionary *)cachedRTMServerTable {
    NSDictionary *RTMServerTable = [self cachedServerTableForKey:LCRTMRouterCacheKey];

    if (!RTMServerTable) {
        [self fetchRTMServerTableInBackground:nil];
    }

    return RTMServerTable;
}

- (NSString *)batchPathForPath:(NSString *)path {
    NSString *result = [self prefixVersionForPath:path];
    return result;
}

- (void)presetURLString:(NSString *)URLString
       forServiceModule:(NSString *)serviceModule
{
    if (!serviceModule)
        return;

    _presetURLStringTable[serviceModule] = URLString;
}

@end
