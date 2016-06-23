//
//  AppDelegate.m
//  AnalyticsTest
//
//  Created by lzw on 15/11/10.
//  Copyright © 2015年 LeanCloud. All rights reserved.
//

#import "AppDelegate.h"
#import <AVOSCloud/AVOSCloud.h>

// 应用名：LeanAnalyticsDemo
#define AVOSAppId @"yf60qa9irb2elj5vodn5m6ym982cwbkvnfbcxv56608ly7lg"
#define AVOSAppKey @"4vourf9e6brotirnp39bpr3959uv93u9q3oireots55u9sr2"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [AVOSCloud setAllLogsEnabled:YES];
    [AVOSCloud setApplicationId:AVOSAppId clientKey:AVOSAppKey];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self performSelector:@selector(recordEvent) withObject:nil afterDelay:0.5];
}

- (void)recordEvent {
    // 观察此事件是否丢失
    [AVAnalytics event:@"applicationDidBecomeActive"];
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

@end
