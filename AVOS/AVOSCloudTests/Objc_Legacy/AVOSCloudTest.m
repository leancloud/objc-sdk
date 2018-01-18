//
//  AVOSCloudTest.m
//  AVOS
//
//  Created by lzw on 15/8/18.
//  Copyright (c) 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVTestBase.h"

/*!
 *  Test for AVOSCloud.h
 */
@interface AVOSCloudTest : AVTestBase

@end

@implementation AVOSCloudTest

- (void)testServerDate {
    NSError *error;
    NSDate *date = [AVOSCloud getServerDate:&error];
    XCTAssertNotNil(date);
    
    [AVOSCloud getServerDateWithBlock:^(NSDate *date, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(date);
        [self postNotification:AVTestNotification];
    }];
    [self waitNotification:AVTestNotification];
}

- (void)testNetworkTimeoutConfig {
    NSTimeInterval timerInterval = [AVOSCloud networkTimeoutInterval];
    [AVOSCloud setNetworkTimeoutInterval:0.01];
    NSError *error;
    NSDate *date = [AVOSCloud getServerDate:&error];
    XCTAssertNil(date);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, NSURLErrorTimedOut);
    [AVOSCloud setNetworkTimeoutInterval:timerInterval];
}

@end
