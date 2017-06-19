//
//  CacheTests.m
//  CacheTests
//
//  Created by Tang Tianyong on 17/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LCPreferences.h"
#import "LCUUID.h"

@interface CacheTests : XCTestCase

@end

@implementation CacheTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testPreferences {
    NSString *pseudoApplicationId  = [LCUUID createUUID];
    NSString *pseudoApplicationKey = [LCUUID createUUID];

    AVApplication *application = [[AVApplication alloc] initWithID:pseudoApplicationId key:pseudoApplicationKey];
    LCPreferences *preferences = [[LCPreferences alloc] initWithApplication:application];

    preferences[@"foo"] = @"bar";
    XCTAssertEqualObjects(preferences[@"foo"], @"bar");
}

@end
