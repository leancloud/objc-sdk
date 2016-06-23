//
//  AVAnalyticsTest.m
//  AVOS
//
//  Created by lzw on 15/11/8.
//  Copyright © 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVTestBase.h"
#import "AVAnalytics.h"
#import "AVAnalyticsImpl.h"
#import "AVAnalyticsUtils.h"
#import "AVUtils.h"

@interface AVAnalyticsImpl (Test)

- (void)sync;
- (NSArray *)allSessionData;
- (void)clearSessionEventsAndActivities:(NSString *)sessionId;
- (void)sendSessionsThenClearAll:(BOOL)clearAll;
- (void)stopRun;

@end

@interface AVAnalyticsTest : AVTestBase

@end

@implementation AVAnalyticsTest

- (void)setUp {
    [super setUp];
    [AVAnalytics setAnalyticsEnabled:YES];
}

- (void)tearDown {
    [super tearDown];
}

typedef void(^SessionsBlock)(NSArray *sessions);
- (void)checkSessionsWithBlock:(SessionsBlock)block {
    [[AVAnalyticsImpl sharedInstance] sync];
    NSArray *allSessionData = [[AVAnalyticsImpl sharedInstance] allSessionData];
    block(allSessionData);
    for (NSDictionary *session in allSessionData) {
        NSString * sid = session[@"events"][@"terminate"][@"sessionId"];
        [[AVAnalyticsImpl sharedInstance] clearSessionEventsAndActivities:sid];
    }
}

- (void)wait:(NSTimeInterval)seconds {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

- (void)testDeviceInfo {
    NSDictionary* info = [AVAnalyticsUtils deviceInfo];
    assertEqualObjects(info[@"os"], @"iOS");
    assertEqualObjects(info[@"is_jailbroken"], @(NO));
    assertEqualObjects(info[@"timezone"], @"8");
}

- (void)testLogPageView {
    [AVAnalytics beginLogPageView:@"ViewController"];
    [self wait:2];
    [AVAnalytics endLogPageView:@"ViewController"];
    [self checkSessionsWithBlock:^(NSArray *sessions) {
        NSDictionary *activity = sessions[0][@"events"][@"terminate"][@"activities"][0];
        assertEqualObjects(activity[@"name"], @"ViewController");
        NSInteger du = [activity[@"du"] intValue];
        assertAccuracy(du, 2000, 50);
    }];
}

- (void)testMultiplePageView {
    [AVAnalytics beginLogPageView:@"MainViewController"];
    
    [self wait:3];
    [AVAnalytics beginLogPageView:@"SettingViewController"];
    
    [self wait:2];
    [AVAnalytics endLogPageView:@"SettingViewController"];
    
    [self wait:1];
    [AVAnalytics endLogPageView:@"MainViewController"];

    [self checkSessionsWithBlock:^(NSArray* sessions) {
        NSArray *activities = sessions[0][@"events"][@"terminate"][@"activities"];
        assertEqual(activities.count, 2);
        NSDictionary *activity1 = activities[0];
        NSDictionary *activity2 = activities[1];
        assertEqualObjects(activity1[@"name"], @"MainViewController");
        assertEqualObjects(activity2[@"name"], @"SettingViewController");
        assertAccuracy([activity1[@"du"] intValue], 6000, 100);
        assertAccuracy([activity2[@"du"] intValue], 2000, 100);
    }];
}

- (void)testComplexPageView {
    for (NSInteger i = 0 ;i < 10; i++) {
        [AVAnalytics beginLogPageView:[NSString stringWithFormat:@"ViewController%ld", i]];
        [self wait: ((double)(rand() % 100) / 100)];
    }
    
    for (NSInteger i = 9; i >= 0; i --) {
        [AVAnalytics endLogPageView:[NSString stringWithFormat:@"ViewController%ld", i]];
    }
    [self checkSessionsWithBlock:^(NSArray *sessions) {
        NSArray *activities = sessions[0][@"events"][@"terminate"][@"activities"];
        assertEqual(activities.count, 10);
        NSInteger last = 10 * 1000;
        for (NSDictionary *activity in activities) {
            NSInteger du = [activity[@"du"] intValue];
            assertTrue(du <= last);
            last = du;
        }
    }];
}

- (void)testBeginEvent {
    NSString *name = NSStringFromSelector(_cmd);
    [AVAnalytics beginEvent:name];
    [self wait:3];
    [AVAnalytics endEvent:name];
    [self checkSessionsWithBlock:^(NSArray *sessions) {
        NSLog(@"sessions: %@", sessions);
        NSDictionary *event = sessions[0][@"events"][@"event"][0];
        assertEqualObjects(event[@"name"], name);
        assertEqualObjects(event[@"tag"], name);
        NSInteger du = [event[@"du"] intValue];
        assertTrue(du >= 3000 && du < 3100);
    }];
}

- (void)testSendEvent {
    // 观察输出，看看有没有事件有没被重复发送
    NSString *name = NSStringFromSelector(_cmd);
    [AVAnalytics beginEvent:name];
    [self wait:3];
    [AVAnalytics endEvent:name];
    NSInteger __block totalCount = 0;
    for (NSInteger i = 0; i < 2; i ++) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[AVAnalyticsImpl sharedInstance] sendSessionsThenClearAll:NO];
            totalCount ++;
            if (totalCount == 2) {
                NOTIFY
            }
        });
    }
    WAIT
}

- (void)testStopAnalytics {
    // just test call, because it have no way to recover AVAnalytics to run again.
    // [[AVAnalyticsImpl sharedInstance] stopRun];
}

- (void)testGetConfigParams {
    [AVAnalytics updateOnlineConfigWithBlock:^(NSDictionary *dict, NSError *error) {
        assertEqual([[AVAnalytics getConfigParams:@"param1"] intValue], 1);
        assertEqualObjects([AVAnalytics getConfigParams:@"param2"], @"string");
        assertAccuracy([[AVAnalytics getConfigParams:@"param3"] floatValue], 3.14, 0.0001);
        NOTIFY
    }];
    WAIT
}

@end
