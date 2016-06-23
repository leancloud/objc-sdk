//
//  LCRouterTest.m
//  AVOS
//
//  Created by Tang Tianyong on 5/10/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AVTestBase.h"
#import "LCRouterCache.h"

@interface LCRouterTest : AVTestBase

@end

@implementation LCRouterTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testRouterCache {
    NSString *APIHost = @"api.leancloud.cn";
    NSTimeInterval lastModified = [[NSDate date] timeIntervalSince1970];

    LCRouterCache *routerCache = [LCRouterCache sharedInstance];

    [routerCache cacheAPIHostWithServiceRegion:AVServiceRegionCN host:APIHost lastModified:lastModified TTL:86400];
    NSString *cachedAPIHost = [routerCache APIHostForServiceRegion:AVServiceRegionCN];
    XCTAssertEqual(cachedAPIHost, cachedAPIHost);

    [routerCache cacheAPIHostWithServiceRegion:AVServiceRegionCN host:APIHost lastModified:lastModified TTL:0.005];

    void *signal = &signal;

    /* Test cache expiration. */
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertNil([routerCache APIHostForServiceRegion:AVServiceRegionCN]);
        [self postNotification:signal];
    });

    [self waitNotification:signal];
}

@end
