//
//  LCRouter_Internal.h
//  AVOS
//
//  Created by zapcannon87 on 2018/8/9.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "LCRouter.h"

static NSString *const AppRouterURLString = @"https://app-router.leancloud.cn/2/route";

typedef NSString * const AppIDSuffix NS_TYPED_EXTENSIBLE_ENUM;
static AppIDSuffix AppIDSuffixCN = @"-gzGzoHsz";
static AppIDSuffix AppIDSuffixCE = @"-9Nh9j0Va";
static AppIDSuffix AppIDSuffixUS = @"-MdYXbMMI";

typedef NSString * const AppDomain NS_TYPED_EXTENSIBLE_ENUM;
static AppDomain AppDomainCN = @"lncld.net";
static AppDomain AppDomainCE = @"lncldapi.com";
static AppDomain AppDomainUS = @"lncldglobal.com";

typedef NSString * const AppModule NS_TYPED_EXTENSIBLE_ENUM;
static AppModule AppModuleAPI = @"api";
static AppModule AppModuleEngine = @"engine";
static AppModule AppModulePush = @"push";
static AppModule AppModuleRTMRouter = @"rtm";
static AppModule AppModuleStats = @"stats";

typedef NSString * const RouterKey NS_TYPED_EXTENSIBLE_ENUM;
static RouterKey RouterKeyAppAPIServer = @"api_server";
static RouterKey RouterKeyAppEngineServer = @"engine_server";
static RouterKey RouterKeyAppPushServer = @"push_server";
static RouterKey RouterKeyAppRTMRouterServer = @"rtm_router_server";
static RouterKey RouterKeyAppStatsServer = @"stats_server";
static RouterKey RouterKeyTTL = @"ttl";
static RouterKey RouterKeyRTMGroupID = @"groupId";
static RouterKey RouterKeyRTMGroupUrl = @"groupUrl";
static RouterKey RouterKeyRTMSecondary = @"secondary";
static RouterKey RouterKeyRTMServer = @"server";

@interface LCRouter ()

@property (atomic, assign) BOOL isUpdatingAppRouter;

/// internal

- (NSString *)appURLForPath:(NSString *)path appID:(NSString *)appID;

- (void)getRTMURLWithAppID:(NSString *)appID callback:(void (^)(NSDictionary *dictionary, NSError *error))callback;

- (NSString *)batchPathForPath:(NSString *)path;

- (void)customAppServerURL:(NSString *)URLString key:(RouterKey)key;

/// unit test

- (void)getAppRouterDataWithAppID:(NSString *)appID callback:(void (^)(NSDictionary *dataDictionary, NSError *error))callback;

- (void)getRTMRouterDataWithAppID:(NSString *)appID RTMRouterURL:(NSString *)RTMRouterURL callback:(void (^)(NSDictionary *dataDictionary, NSError *error))callback;

- (NSString *)RTMRouterURLForAppID:(NSString *)appID;

- (void)tryUpdateAppRouterWithAppID:(NSString *)appID callback:(void (^)(NSError *error))callback;

+ (NSString *)routerCacheDirectoryPath;

- (void)getAndCacheRTMRouterDataWithAppID:(NSString *)appID RTMRouterURL:(NSString *)RTMRouterURL callback:(void (^)(NSDictionary *dataDictionary, NSError *error))callback;

- (NSString *)appRouterFallbackURLWithKey:(NSString *)key appID:(NSString *)appID;

@end
