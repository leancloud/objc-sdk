//
//  LCRouter.m
//  AVOS
//
//  Created by Tang Tianyong on 5/9/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import "LCRouter_Internal.h"
#import "AVUtils.h"
#import "AVErrorUtils.h"
#import "AVPaasClient.h"
#import "AVPersistenceUtils.h"

RouterCacheKey RouterCacheKeyApp = @"RouterCacheDataApp";
RouterCacheKey RouterCacheKeyRTM = @"RouterCacheDataRTM";
static RouterCacheKey RouterCacheKeyData = @"data";
static RouterCacheKey RouterCacheKeyTimestamp = @"timestamp";

static NSString *serverURLString;
/// { 'module key' : 'URL' }
static NSMutableDictionary<NSString *, NSString *> *customAppServerTable;

@implementation LCRouter {
    /// { 'app ID' : 'app router data tuple' }
    NSMutableDictionary<NSString *, NSDictionary *> *_appRouterMap;
    /// { 'app ID' : 'RTM router data tuple' }
    NSMutableDictionary<NSString *, NSDictionary *> *_RTMRouterMap;
    
    NSLock *_lock;
    NSDictionary<NSString *, NSString *> *_keyToModule;
    /// { 'app ID' : 'callback array' }
    NSMutableDictionary<NSString *, NSMutableArray<void (^)(NSDictionary *, NSError *)> *> *_RTMRouterCallbacksMap;
}

+ (NSString *)serverURLString {
    return serverURLString;
}

+ (void)setServerURLString:(NSString *)URLString {
    serverURLString = URLString;
}

+ (instancetype)sharedInstance
{
    static LCRouter *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LCRouter alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self->_lock = [NSLock new];
        
        NSMutableDictionary *(^ loadCacheToMemoryBlock)(NSString *) = ^NSMutableDictionary *(NSString *key) {
            NSString *filePath = [[LCRouter routerCacheDirectoryPath] stringByAppendingPathComponent:key];
            BOOL isDirectory;
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory] && !isDirectory) {
                NSData *data = [NSData dataWithContentsOfFile:filePath];
                if ([data length]) {
                    NSError *error = nil;
                    NSMutableDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                    if (error || ![NSMutableDictionary _lc_is_type_of:dictionary]) {
                        if (!error) { error = LCErrorInternal([NSString stringWithFormat:@"file: %@ is invalid.", filePath]); }
                        AVLoggerError(AVLoggerDomainDefault, @"%@", error);
                    } else {
                        return dictionary;
                    }
                }
            }
            return [NSMutableDictionary dictionary];
        };
        self->_appRouterMap = loadCacheToMemoryBlock(RouterCacheKeyApp);
        self->_RTMRouterMap = loadCacheToMemoryBlock(RouterCacheKeyRTM);
        
        self->_isUpdatingAppRouter = false;
        self->_RTMRouterCallbacksMap = [NSMutableDictionary dictionary];
        
        self->_keyToModule = ({
            @{ RouterKeyAppAPIServer : AppModuleAPI,
               RouterKeyAppEngineServer : AppModuleEngine,
               RouterKeyAppPushServer : AppModulePush,
               RouterKeyAppRTMRouterServer : AppModuleRTMRouter,
               RouterKeyAppStatsServer : AppModuleStats };
        });
    }
    return self;
}

// MARK: - API Version

+ (NSString *)APIVersion
{
    return @"1.1";
}

static NSString * pathWithVersion(NSString *path)
{
    NSString *version = [LCRouter APIVersion];
    if ([path hasPrefix:[@"/" stringByAppendingPathComponent:version]]) {
        return path;
    } else if ([path hasPrefix:version]) {
        return [@"/" stringByAppendingPathComponent:path];
    } else {
        return [[@"/" stringByAppendingPathComponent:version] stringByAppendingPathComponent:path];
    }
}

// MARK: - RTM Router Path

+ (NSString *)RTMRouterPath
{
    return @"/v1/route";
}

// MARK: - Disk Cache

+ (NSString *)routerCacheDirectoryPath
{
    return [AVPersistenceUtils homeDirectoryLibraryCachesLeanCloudCachesRouter];
}

static void cachingRouterData(NSDictionary *routerDataMap, RouterCacheKey key)
{
#if DEBUG
    assert(routerDataMap);
    assert(key);
#endif
    NSData *data = ({
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:routerDataMap options:0 error:&error];
        if (error || ![data length]) {
            if (!error) { error = LCErrorInternal(@"data invalid."); }
            AVLoggerError(AVLoggerDomainDefault, @"%@", error);
            return;
        }
        data;
    });
    NSString *filePath = ({
        NSString *routerCacheDirectoryPath = [LCRouter routerCacheDirectoryPath];
        BOOL isDirectory;
        BOOL isExists = [[NSFileManager defaultManager] fileExistsAtPath:routerCacheDirectoryPath isDirectory:&isDirectory];
        if (!isExists) {
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:routerCacheDirectoryPath withIntermediateDirectories:true attributes:nil error:&error];
            if (error) {
                AVLoggerError(AVLoggerDomainDefault, @"%@", error);
                return;
            }
        } else if (isExists && !isDirectory) {
            AVLoggerError(AVLoggerDomainDefault, @"%@", LCErrorInternal(@"can't create directory for router."));
            return;
        }
        [routerCacheDirectoryPath stringByAppendingPathComponent:key];
    });
    [data writeToFile:filePath atomically:true];
}

- (void)cleanCacheWithKey:(RouterCacheKey)key error:(NSError * __autoreleasing *)error
{
    NSParameterAssert(key);
    NSString *filePath = [[LCRouter routerCacheDirectoryPath] stringByAppendingPathComponent:key];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:error];
    }
}

// MARK: - App Router

- (void)getAppRouterDataWithAppID:(NSString *)appID callback:(void (^)(NSDictionary *dataDictionary, NSError *error))callback
{
    NSParameterAssert(appID);
    [[AVPaasClient sharedInstance] getObject:AppRouterURLString withParameters:@{@"appId":appID} block:^(id _Nullable object, NSError * _Nullable error) {
        if (error) {
            callback(nil, error);
        } else {
            NSDictionary *dictionary = (NSDictionary *)object;
            if ([NSDictionary _lc_is_type_of:dictionary]) {
                callback(dictionary, nil);
            } else {
                callback(nil, LCErrorInternal(@"response data invalid."));
            }
        }
    }];
}

- (void)tryUpdateAppRouterWithAppID:(NSString *)appID callback:(void (^)(NSError *error))callback
{
    NSParameterAssert(appID);
    if (self.isUpdatingAppRouter) {
        return;
    }
    self.isUpdatingAppRouter = true;
    [self getAppRouterDataWithAppID:appID callback:^(NSDictionary *dataDictionary, NSError *error) {
        if (error) { AVLoggerError(AVLoggerDomainDefault, @"%@", error); }
        if (dataDictionary) {
            NSDictionary *routerDataTuple = ({
                @{ RouterCacheKeyData : dataDictionary,
                   RouterCacheKeyTimestamp : @(NSDate.date.timeIntervalSince1970) };
            });
            NSDictionary *appRouterMapCopy = nil;
            [self->_lock lock];
            self->_appRouterMap[appID] = routerDataTuple;
            appRouterMapCopy = [self->_appRouterMap copy];
            [self->_lock unlock];
            cachingRouterData(appRouterMapCopy, RouterCacheKeyApp);
        }
        self.isUpdatingAppRouter = false;
        if (callback) { callback(error); }
    }];
}

- (NSString *)appURLForPath:(NSString *)path appID:(NSString *)appID
{
    NSParameterAssert(path);
    NSParameterAssert(appID);
    
    RouterKey serverKey = serverKeyForPath(path);
    
    NSString *(^constructedURL)(NSString *) = ^NSString *(NSString *host) {
        if ([serverKey isEqualToString:RouterKeyAppRTMRouterServer]) {
            return absoluteURLStringWithHostAndPath(host, path);
        } else {
            return absoluteURLStringWithHostAndPath(host, pathWithVersion(path));
        }
    };
    
    ({  /// get server URL from custom server table.
        NSString *customServerURL = [NSString _lc_decoding:customAppServerTable key:serverKey];
        if ([customServerURL length]) {
            return constructedURL(customServerURL);
        }
    });
    
    if ([LCRouter serverURLString].length) {
        return constructedURL([LCRouter serverURLString]);
    }
    
    if ([appID hasSuffix:AppIDSuffixUS]) {
        NSDictionary *appRouterDataTuple = nil;
        [self->_lock lock];
        appRouterDataTuple = [NSDictionary _lc_decoding:self->_appRouterMap key:appID];
        [self->_lock unlock];
        if (shouldUpdateRouterData(appRouterDataTuple)) {
            [self tryUpdateAppRouterWithAppID:appID callback:nil];
        }
        NSDictionary *dataDic = [NSDictionary _lc_decoding:appRouterDataTuple key:RouterCacheKeyData];
        NSString *serverURL = [NSString _lc_decoding:dataDic key:serverKey];
        if ([serverURL length]) {
            return constructedURL(serverURL);
        } else {
            NSString *fallbackServerURL = [self appRouterFallbackURLWithKey:serverKey appID:appID];
            return constructedURL(fallbackServerURL);
        }
    }
    
    return nil;
}

+ (NSString *)appDomainForAppID:(NSString *)appID
{
    NSString *appDomain;
    if ([appID hasSuffix:AppIDSuffixCN]) {
        appDomain = AppDomainCN;
    } else if ([appID hasSuffix:AppIDSuffixCE]) {
        appDomain = AppDomainCE;
    } else if ([appID hasSuffix:AppIDSuffixUS]) {
        appDomain = AppDomainUS;
    } else {
        appDomain = AppDomainCN;
    }
    return appDomain;
}

- (NSString *)appRouterFallbackURLWithKey:(NSString *)key appID:(NSString *)appID
{
    NSParameterAssert(key);
    NSParameterAssert(appID);
    return [NSString stringWithFormat:@"%@.%@.%@",
            [[appID substringToIndex:8] lowercaseString],
            self->_keyToModule[key],
            [LCRouter appDomainForAppID:appID]];
}

/// for compatibility, keep it.
- (NSString *)URLStringForPath:(NSString *)path
{
    return [self appURLForPath:path appID:[AVOSCloud getApplicationId]];
}

// MARK: - RTM Router

- (NSString *)RTMRouterURLForAppID:(NSString *)appID
{
    NSParameterAssert(appID);
    return [self appURLForPath:[LCRouter RTMRouterPath] appID:appID];
}

- (void)getRTMRouterDataWithAppID:(NSString *)appID RTMRouterURL:(NSString *)RTMRouterURL callback:(void (^)(NSDictionary *dataDictionary, NSError *error))callback
{
    NSParameterAssert(appID);
    NSParameterAssert(RTMRouterURL);
    NSMutableDictionary *parameters = ({
        NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
        parameters[@"appId"] = appID;
        parameters[@"secure"] = @"1";
        /* Back door for user to connect to puppet environment. */
        if (getenv("LC_IM_PUPPET_ENABLED") && getenv("SIMULATOR_UDID")) {
            parameters[@"debug"] = @"true";
        }
        parameters;
    });
    [[AVPaasClient sharedInstance] getObject:RTMRouterURL withParameters:parameters block:^(id _Nullable object, NSError * _Nullable error) {
        if (error) {
            callback(nil, error);
        } else {
            if ([NSDictionary _lc_is_type_of:object]) {
                callback(object, nil);
            } else {
                callback(nil, LCErrorInternal(@"response data invalid."));
            }
        }
    }];
}

- (void)getAndCacheRTMRouterDataWithAppID:(NSString *)appID RTMRouterURL:(NSString *)RTMRouterURL callback:(void (^)(NSDictionary *dataDictionary, NSError *error))callback
{
    NSParameterAssert(appID);
    NSParameterAssert(RTMRouterURL);
    [self getRTMRouterDataWithAppID:appID RTMRouterURL:RTMRouterURL callback:^(NSDictionary *dataDictionary, NSError *error) {
        if (error) {
            callback(nil, error);
            return;
        }
        NSDictionary *routerDataTuple = ({
            @{ RouterCacheKeyData : dataDictionary,
               RouterCacheKeyTimestamp : @(NSDate.date.timeIntervalSince1970) };
        });
        NSDictionary *RTMRouterMapCopy = nil;
        [self->_lock lock];
        self->_RTMRouterMap[appID] = routerDataTuple;
        RTMRouterMapCopy = [self->_RTMRouterMap copy];
        [self->_lock unlock];
        cachingRouterData(RTMRouterMapCopy, RouterCacheKeyRTM);
        callback(dataDictionary, nil);
    }];
}

- (void)getRTMURLWithAppID:(NSString *)appID callback:(void (^)(NSDictionary *dictionary, NSError *error))callback
{
    NSParameterAssert(appID);
    
    /// get RTM router URL & try update app router
    NSString *RTMRouterURL = [self RTMRouterURLForAppID:appID];
    if (!RTMRouterURL) {
        callback(nil, LCError(9973, @"RTM Router URL not found.", nil));
        return;
    }
    
    ({  /// add callback to map
        BOOL addCallbacksToArray = false;
        [self->_lock lock];
        NSMutableArray<void (^)(NSDictionary *, NSError *)> *callbacks = self->_RTMRouterCallbacksMap[appID];
        if (callbacks) {
            [callbacks addObject:callback];
            addCallbacksToArray = true;
        } else {
            callbacks = [NSMutableArray arrayWithObject:callback];
            self->_RTMRouterCallbacksMap[appID] = callbacks;
        }
        [self->_lock unlock];
        if (addCallbacksToArray) {
            return;
        }
    });
    
    void(^invokeCallbacks)(NSDictionary *, NSError *) = ^(NSDictionary *data, NSError *error) {
        NSMutableArray<void (^)(NSDictionary *, NSError *)> *callbacks = nil;
        [self->_lock lock];
        callbacks = self->_RTMRouterCallbacksMap[appID];
        [self->_RTMRouterCallbacksMap removeObjectForKey:appID];
        [self->_lock unlock];
        for (void (^block)(NSDictionary *, NSError *) in callbacks) {
            block(data, error);
        }
    };
    
    ({  /// get RTM URL data from memory
        NSDictionary *RTMRouterDataTuple = nil;
        [self->_lock lock];
        RTMRouterDataTuple = [NSDictionary _lc_decoding:self->_RTMRouterMap key:appID];
        [self->_lock unlock];
        if (!shouldUpdateRouterData(RTMRouterDataTuple)) {
            NSDictionary *dataDic = [NSDictionary _lc_decoding:RTMRouterDataTuple key:RouterCacheKeyData];
            invokeCallbacks(dataDic, nil);
            return;
        }
    });
    
    [self getAndCacheRTMRouterDataWithAppID:appID RTMRouterURL:RTMRouterURL callback:^(NSDictionary *dataDictionary, NSError *error) {
        invokeCallbacks(dataDictionary, error);
    }];
}

// MARK: - Batch Path

- (NSString *)batchPathForPath:(NSString *)path
{
    NSParameterAssert(path);
    return pathWithVersion(path);
}

// MARK: - Custom App URL

+ (void)customAppServerURL:(NSString *)URLString key:(RouterKey)key
{
    if (!customAppServerTable) {
        customAppServerTable = [NSMutableDictionary dictionary];
    }
    if (!key) { return; }
    if (URLString) {
        customAppServerTable[key] = URLString;
    } else {
        [customAppServerTable removeObjectForKey:key];
    }
}

// MARK: - Misc

static BOOL shouldUpdateRouterData(NSDictionary *routerDataTuple)
{
    if (!routerDataTuple) {
        return true;
    }
    NSDictionary *dataDic = [NSDictionary _lc_decoding:routerDataTuple key:RouterCacheKeyData];
    NSTimeInterval lastTimestamp = [[NSNumber _lc_decoding:routerDataTuple key:RouterCacheKeyTimestamp] doubleValue];
    if (!dataDic) {
        return true;
    }
    NSTimeInterval ttl = [[NSNumber _lc_decoding:dataDic key:RouterKeyTTL] doubleValue];
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    if (currentTimestamp >= lastTimestamp && currentTimestamp <= (lastTimestamp + ttl)) {
        return false;
    } else {
        return true;
    }
}

static RouterKey serverKeyForPath(NSString *path)
{
#if DEBUG
    assert(path);
#endif
    if ([path hasPrefix:@"call"] || [path hasPrefix:@"functions"]) {
        return RouterKeyAppEngineServer;
    } else if ([path hasPrefix:@"push"] || [path hasPrefix:@"installations"]) {
        return RouterKeyAppPushServer;
    } else if ([path hasPrefix:@"stats"] || [path hasPrefix:@"statistics"] || [path hasPrefix:@"always_collect"]) {
        return RouterKeyAppStatsServer;
    } else if ([path isEqualToString:[LCRouter RTMRouterPath]]) {
        return RouterKeyAppRTMRouterServer;
    } else {
        return RouterKeyAppAPIServer;
    }
}

static NSString * absoluteURLStringWithHostAndPath(NSString *host, NSString *path)
{
#if DEBUG
    assert(host);
    assert(path);
#endif
    NSString *unifiedHost = ({
        NSString *unifiedHost = nil;
        /// For "example.com:8080", the scheme is "example.com". Here, we need a farther check.
        NSURL *URL = [NSURL URLWithString:host];
        if (URL.scheme && [host hasPrefix:[URL.scheme stringByAppendingString:@"://"]]) {
            unifiedHost = host;
        } else {
            unifiedHost = [@"https://" stringByAppendingString:host];
        }
        unifiedHost;
    });
    
    NSURLComponents *URLComponents = ({
        NSURLComponents *URLComponents = [[NSURLComponents alloc] initWithString:unifiedHost];
        if ([path length]) {
            NSString *pathString = nil;
            if ([URLComponents.path length]) {
                pathString = [URLComponents.path stringByAppendingPathComponent:path];
            } else {
                pathString = path;
            }
            NSURL *pathURL = [NSURL URLWithString:pathString];
            URLComponents.path = pathURL.path;
            URLComponents.query = pathURL.query;
            URLComponents.fragment = pathURL.fragment;
        }
        URLComponents;
    });
    
    return [[URLComponents URL] absoluteString];
}

@end
