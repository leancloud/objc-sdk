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

static NSString *const moduleAPIServer       = @"api_server";
static NSString *const moduleEngineServer    = @"engine_server";
static NSString *const modulePushServer      = @"push_server";
static NSString *const moduleRTMRouterServer = @"rtm_router_server";
static NSString *const moduleStatsServer     = @"stats_server";

static NSString *const ttlKey                = @"ttl";
static NSString *const lastModifiedKey       = @"last_modified";
static NSString *const serverTableKey        = @"server_table";

static NSString *const LCAppRouterCacheKey   = @"LCAppRouterCacheKey";
static NSString *const LCRTMRouterCacheKey   = @"LCRTMRouterCacheKey";

NSString *LCRouterDidUpdateNotification      = @"LCRouterDidUpdateNotification";

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
        moduleAPIServer       : @"api",
        moduleEngineServer    : @"engine",
        modulePushServer      : @"push",
        moduleRTMRouterServer : @"rtm",
        moduleStatsServer     : @"stats"
    };

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

- (NSString *)moduleForPath:(NSString *)path {
    if ([path hasPrefix:@"call"] || [path hasPrefix:@"functions"])
        return moduleEngineServer;
    else if ([path hasPrefix:@"push"] || [path hasPrefix:@"installations"])
        return modulePushServer;
    else if ([path hasPrefix:@"stats"] || [path hasPrefix:@"statistics"] || [path hasPrefix:@"always_collect"])
        return moduleStatsServer;
    else
        return moduleAPIServer;
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

    NSDictionary *parameters = @{@"appId": [AVOSCloud getApplicationId]};

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

- (NSString *)absoluteURLStringForServer:(NSString *)server path:(NSString *)path {
    NSURLComponents *URLComponents = [[NSURLComponents alloc] init];

    URLComponents.scheme = @"https";
    URLComponents.host   = server;

    if (path.length) {
        NSURL *url = [NSURL URLWithString:path];

        URLComponents.path = url.path;
        URLComponents.query = url.query;
        URLComponents.fragment = url.fragment;
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
    NSString *server = nil;
    NSString *module = [self moduleForPath:path];
    NSDictionary *APIServerTable = [self cachedServerTableForKey:LCAppRouterCacheKey];

    if (module && APIServerTable) {
        server = APIServerTable[module];
    }

    if (!server.length) {
        switch (self.serverLocation) {
        case LCServerLocationUCloud:
            server = [self lncldServerForModule:module] ?: [self fallbackAPIURLString]; break;
        default:
            server = [self fallbackAPIURLString]; break;
        }
    }

    NSString *versionPrefixedPath = [self prefixVersionForPath:path];
    NSString *URLString = [self absoluteURLStringForServer:server path:versionPrefixedPath];

    return URLString;
}

- (NSString *)RTMRouterURLString {
    NSString *server = nil;
    NSDictionary *APIServerTable = [self cachedServerTableForKey:LCAppRouterCacheKey];

    if (APIServerTable) {
        server = APIServerTable[moduleRTMRouterServer];
    }

    if (!server.length) {
        switch (self.serverLocation) {
        case LCServerLocationUCloud:
            server = [self lncldServerForModule:moduleRTMRouterServer] ?: [self fallbackRTMRouterURLString]; break;
        default:
            server = [self fallbackRTMRouterURLString]; break;
        }
    }

    NSString *URLString = [self absoluteURLStringForServer:server path:@"/v1/route"];

    return URLString;
}

- (NSDictionary *)RTMRouterParameters {
    NSString *appId = [AVOSCloud getApplicationId];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];

    parameters[@"appId"] = appId;
    parameters[@"secure"] = @"1";

    /*
     * iOS SDK *must* use IP address to access IM server to prevent DNS hijacking.
     * And IM server *must* issue the pinned certificate.
     */
    parameters[@"ip"] = @"true";

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

@end
