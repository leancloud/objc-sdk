//
//  AVPushTest.m
//  Paas
//
//  Created by Zhu Zeng on 3/28/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "AVTestBase.h"
#import "AVPush.h"
#import "AVInstallation_Internal.h"

/**
 *  需要打开 _Installation 表的Find 权限
 */

@interface AVPushTest : AVTestBase

@end


@implementation AVPushTest

- (void)setUp {
    [super setUp];
    NSError *error;
    // save current installation for test
    [[AVInstallation currentInstallation] setDeviceToken:kTestDeviceToken];
    [[AVInstallation currentInstallation] save:&error];
    XCTAssertNil(error);
}

-(void)testAVPushMessage
{
    AVPush *push = [[AVPush alloc] init];
    [push setData:@{@"alert": @"push message to ios without query", @"sound":@""}];
    [push setPushToIOS:YES];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"%@", [error localizedDescription]);
        NOTIFY;
    }];
    WAIT;
}

- (void)testAVPushTarget {
    AVPush *push = [[AVPush alloc] init];
    [push setData:@{@"alert": @"push message to ios without query", @"sound":@""}];
    [push setPushToIOS:NO];
    [push setPushToWP:YES];
    [push setPushToAndroid:YES];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"%@", [error localizedDescription]);
        NOTIFY;
    }];
    WAIT;
    [push setPushToTargetPlatforms:@[kAVPushTargetPlatformAndroid,kAVPushTargetPlatformIOS,kAVPushTargetPlatformWindowsPhone]];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"%@", [error localizedDescription]);
        NOTIFY;
    }];
    WAIT;
}

-(void)testAVPushMessageWithQuery
{
    AVQuery *pushQuery = [AVInstallation query];
    [pushQuery whereKey:@"channels" equalTo:@"Giants"]; // Set channel
    
    // Send push notification to query
    AVPush *push = [[AVPush alloc] init];
    [push setQuery:pushQuery];
    [push setMessage:@"Push from My Paas to ios device only."];
    [push setPushToIOS:YES];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"%@", [error localizedDescription]);
        NOTIFY;
    }];
    WAIT;
}

-(void)testAVPushWithQuery1 {
    // Create our Installation query
    AVQuery *pushQuery = [AVInstallation query];
    [pushQuery whereKey:@"injuryReports" equalTo:@(YES)];
    
    // Send push notification to query
    AVPush *push = [[AVPush alloc] init];
    [push setQuery:pushQuery]; // Set our Installation query
    [push setMessage:@"Willie Hayes injured by own pop fly."];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"error %@", error);
        NOTIFY;
    }];
    WAIT;
}

-(void)testAVPushWithQuery2 {
    // Create our Installation query
    AVQuery *pushQuery = [AVInstallation query];
    [pushQuery whereKey:@"channels" equalTo:@"Giants"]; // Set channel
    [pushQuery whereKey:@"scores" equalTo:@(YES)];
    
    // Send push notification to query
    AVPush *push = [[AVPush alloc] init];
    [push setQuery:pushQuery];
    [push setMessage:@"Giants scored against the A's! It's now 2-2."];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"error %@", error);
        NOTIFY;
    }];
    WAIT;
}

-(void)testAVPushDataWithQuery
{
    AVQuery *pushQuery = [AVInstallation query];
    [pushQuery whereKey:@"channels" equalTo:@"Giants"]; // Set channel
    
    // Send push notification to query
    AVPush *push = [[AVPush alloc] init];
    [push setQuery:pushQuery];
    [push setData:@{@"alert": @"test message", @"sound":@""}];
    [push setPushToIOS:YES];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"%@", [error localizedDescription]);
        NOTIFY;
    }];
    WAIT;
}

-(void)testAVPushDataToChannel
{
    [AVPush sendPushDataToChannelInBackground:@"Giants"
                                     withData:@{@"alert": @"test message", @"sound":@""}
                                        block:^(BOOL succeeded, NSError *error) {
                                            NOTIFY;
                                        }];
    WAIT;
}

-(void)testAVPushSubscribedChannels
{
    [AVPush getSubscribedChannelsInBackgroundWithBlock:^(NSSet *channels, NSError *error) {
        XCTAssertTrue(error == nil, @"%@", [error localizedDescription]);
        NOTIFY;
    }];
    WAIT;
}

-(void)testAVPushChannelsAdd
{
    NSString * channelName = @"public";

    NSError * error = nil;
    XCTAssertTrue([AVPush subscribeToChannel:channelName error:&error], @"subscribe error");
    
    [AVPush getSubscribedChannelsInBackgroundWithBlock:^(NSSet *channels, NSError *error) {
        XCTAssertNil(error);
        XCTAssertTrue([channels containsObject:channelName], @"subscribe failed");
        NOTIFY;
    }];
    WAIT;
    
    XCTAssertTrue([AVPush unsubscribeFromChannel:channelName error:&error], @"unsubscribe error");
    [AVPush getSubscribedChannelsInBackgroundWithBlock:^(NSSet *channels, NSError *error) {
        XCTAssertNil(error);
        XCTAssertFalse([channels containsObject:channelName], @"unsubscribe failed");
        NOTIFY;
    }];
    WAIT;
}

-(void)testAVPushToChannel {
    AVPush *push = [[AVPush alloc] init];
    [push setChannel:@"Giants"];
    [push setMessage:@"The Giants just scored!"];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"error %@", error);
        NOTIFY;
    }];
    WAIT;
}

-(void)testAVPushToChannels {
    NSArray *channels = [NSArray arrayWithObjects:@"Giants", @"Mets", nil];
    AVPush *push = [[AVPush alloc] init];
    
    // Be sure to use the plural 'setChannels'.
    [push setChannels:channels];
    [push setMessage:@"The Giants won against the Mets 2-3."];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"erorr %@", error);
        NOTIFY;
    }];
    WAIT;
}

-(void)testAVPushWithComplexDataA {
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"The Mets scored! The game is now tied 1-1!", @"alert",
                          @"Increment", @"badge",
                          @"cheering.caf", @"sound",
                          nil];
    AVPush *push = [[AVPush alloc] init];
    [push setChannels:[NSArray arrayWithObjects:@"Mets", nil]];
    [push setData:data];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"error %@", error);
        NOTIFY;
    }];
    WAIT;
}

-(void)testAVPushWithComplexDataB {
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"Ricky Vaughn was injured in last night's game!", @"alert",
                          @"Vaughn", @"name",
                          @"Man bites dog", @"newsItem",
                          nil];
    AVQuery *pushQuery = [AVInstallation query];
    [pushQuery whereKey:@"channels" equalTo:@"Giants"]; // Set channel

    
    AVPush *push = [[AVPush alloc] init];
    [push setQuery:pushQuery];
    [push setChannel:@"Indians"];
    [push setData:data];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"error %@", error);
        NOTIFY;
    }];
    WAIT;
}

-(void)testAVPushWithExpirationDate {
    // Create time interval
    NSTimeInterval interval = 60*60*24*7; // 1 week
    
    // Send push notification with expiration interval
    AVPush *push = [[AVPush alloc] init];
    [push expireAfterTimeInterval:interval];
    AVQuery *pushQuery = [AVInstallation query];
    
    [push setQuery:pushQuery];
    [push setMessage:@"Season tickets on sale until October 18th"];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"error %@", error);
        NOTIFY;
    }];
    WAIT;

}

-(void)testAVPushWithPlatform {
    AVQuery *query = [AVInstallation query];
    [query whereKey:@"channels" equalTo:@"suitcaseOwners"];
    
    // Notification for Android users
    [query whereKey:@"deviceType" equalTo:@"android"];
    AVPush *androidPush = [[AVPush alloc] init];
    [androidPush setMessage:@"Your suitcase has been filled with tiny robots!"];
    [androidPush setQuery:query];
    [androidPush sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"error %@", error);
        NOTIFY;
    }];
    WAIT;
    
    // Notification for iOS users
    [query whereKey:@"deviceType" equalTo:@"ios"];
    AVPush *iOSPush = [[AVPush alloc] init];
    [iOSPush setMessage:@"Your suitcase has been filled with tiny apples!"];
    [iOSPush setChannel:@"suitcaseOwners"];
    [iOSPush setQuery:query];
    [iOSPush sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"error %@", error);
        NOTIFY;
    }];
    WAIT;
}

@end
