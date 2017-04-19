//
//  LCRouter.m
//  AVOS
//
//  Created by Tang Tianyong on 5/9/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import "LCRouter.h"
#import "LCRouter_internal.h"
#import "AVPaasClient.h"

static NSString *const APIVersion = @"1.1";

/// Table of router indexed by service region.
static NSDictionary *routerURLTable = nil;

/// Table of default API host indexed by service region.
static NSDictionary *defaultAPIHostTable = nil;

/// Table of default push router host indexed by service region.
static NSDictionary *defaultPushRouterHostTable = nil;

/// Fallback API host for service region if host not found.
static NSString *const fallbackAPIHost = @"api.leancloud.cn";

/// Fallback push router path for service region if host not found.
static NSString *const fallbackPushRouterHost = @"router-g0-push.leancloud.cn";

/// Keys of router response.
NSString *LCAPIHostEntryKey        = @"api_server";
NSString *LCPushRouterHostEntryKey = @"push_router_server";
NSString *LCTTLKey                 = @"ttl";

extern AVServiceRegion LCEffectiveServiceRegion;

@interface LCRouter ()

@property (nonatomic, copy) NSString *APIHost;
@property (nonatomic, copy) NSString *pushRouterHost;

@end

@implementation LCRouter

+ (void)load {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        [self doInitialize];
    });
}

+ (void)doInitialize {
    defaultAPIHostTable = @{
        @(AVServiceRegionCN): @"api.leancloud.cn",
        @(AVServiceRegionUS): @"us-api.leancloud.cn",
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        @(AVServiceRegionUrulu): @"cn-stg1.leancloud.cn"
#pragma clang diagnostic pop
    };

    defaultPushRouterHostTable = @{
        @(AVServiceRegionCN): @"router-g0-push.leancloud.cn",
        @(AVServiceRegionUS): @"router-a0-push.leancloud.cn"
    };

    routerURLTable = @{
        @(AVServiceRegionCN): @"https://app-router.leancloud.cn/1/route"
    };
}

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static LCRouter *sharedInstance;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[LCRouter alloc] init];
    });

    return sharedInstance;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        _serviceRegion = LCEffectiveServiceRegion;
    }

    return self;
}

- (void)updateInBackground {
    [[self class] doInitialize];
    NSString *router = routerURLTable[@(_serviceRegion)];

    if (router) {
        NSDictionary *parameters = @{@"appId": [AVOSCloud getApplicationId]};

        [[AVPaasClient sharedInstance] getObject:router withParameters:parameters block:^(NSDictionary *result, NSError *error) {
            if (!error && result)
                [self handleResult:result];
        }];
    }
}

- (void)handleResult:(NSDictionary *)result {
    /* TODO */
}

@end
