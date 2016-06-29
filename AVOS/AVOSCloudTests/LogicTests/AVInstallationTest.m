//
//  AVInstallationTest.m
//  paas
//
//  Created by yang chaozhong on 5/7/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "AVTestBase.h"
#import "AVInstallation.h"

@interface AVInstallationTest : AVTestBase

@end

@implementation AVInstallationTest

- (void)setUp
{
    [super setUp];
    NSError *error;
    // save current installation for test
    [[AVInstallation currentInstallation] setDeviceToken:kTestDeviceToken];
    [[AVInstallation currentInstallation] save:&error];
    XCTAssertNil(error);
}

-(void)testNullInstalation{
    AVInstallation *it=[[AVInstallation alloc] init];
    [it setDeviceToken:nil];
    NSError *err=nil;
    [it save:&err];
    [self addDeleteObject:it];
    XCTAssert(err.code==kAVErrorInvalidDeviceToken, @"AVInstallation保存检查出错");
}

- (void)testInstallationUpdate {
    NSString *name = NSStringFromSelector(_cmd);
    [[AVInstallation currentInstallation] setObject:name forKey:@"name"];
    NSError *error;
    [[AVInstallation currentInstallation] save:&error];
    XCTAssertNil(error);
    NSString *objectId = [AVInstallation currentInstallation].objectId;
    
    AVInstallation *installation = [AVInstallation objectWithoutDataWithObjectId:objectId];
    [installation fetch:&error];
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(installation.deviceType, @"ios");
    XCTAssertEqualObjects(installation.deviceToken, kTestDeviceToken);
    XCTAssertEqualObjects([installation objectForKey:@"name"], name);
}

- (void)testNotAlwaysSaveInstallation {
    NSDictionary *dict = [self jsonWithFileName:@"TestRelation"];
    XCTAssertNotNil(dict);
    AVObject *object = [AVObjectUtils avObjectForClass:@"AddRequest"];
    [object setObject:@NO forKey:@"isRead"];
    [AVObjectUtils copyDictionary:dict toObject:object];
    NSMutableArray *requests = [object buildSaveRequests];
    XCTAssertEqual(requests.count, 1);
    NSString *path = requests[0][@"path"];
    XCTAssertTrue([path containsString:@"AddRequest"]);
}

/** 需要 delete 权限 */
- (void)testDeleteInstallation {
    NSError *error;
    [[AVInstallation currentInstallation] delete:&error];
    XCTAssertNil(error);
}

// https://ticket.leancloud.cn/tickets/8487
- (void)testInstallationMutated {
    NSDictionary *dict = [self jsonWithFileName:@"TestInstallationSave"];
    AVInstallation *installation = [AVInstallation currentInstallation];
    [installation objectFromDictionary:dict];
    [installation setObject:@(YES) forKey:@"enableNoDisturb"];
    [installation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        NOTIFY;
    }];
    WAIT;
}

- (void)testAlwaysPost {
    AVInstallation *installation = [AVInstallation objectWithObjectId:@"abcdef"];

    installation[@"child"] = ({
        AVObject *child = [AVObject objectWithObjectId:@"abcdef"];
        child[@"foo"] = @"bar";
        child;
    });

    NSArray *requests = [installation buildSaveRequests];

    XCTAssertEqual(requests[0][@"method"], @"PUT");
}

@end
