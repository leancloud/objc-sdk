//
//  AVTestBase.h
//  paas
//
//  Created by Travis on 13-11-11.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVOSCloud/AVOSCloud.h>
#import "XCTestCase+AsyncTesting.h"
#import "AVTestUtil.h"
#import "AVObjectUtils.h"
#import "AVObject_Internal.h"

#define USE_US 0
#if USE_US
//us
#define AVOSAppId @"kknqydxqd9wdq4cboy1dvvug5ha0ce3i2mrerrdrmr6pla1p"
#define AVOSAppKey @"fate582pwsfh97s9o99nw91a152i7ndm9tsy866e6wpezth4"
#define PREPARE setenv("LOG_CURL", "YES", 0); \
[AVOSCloud useAVCloudUS]; \
[AVOSCloud setApplicationId:AVOSAppId clientKey:AVOSAppKey];

#else
//cn
//App Name == [iOS SDK UnitTest]
#define AVOSAppId @"nq0awk3lh1dpmbkziz54377mryii8ny4xvp6njoygle5nlyg"
#define AVOSAppKey @"6vdnmdkdi4fva9i06lt50s4mcsfhppjpzm3zf5zjc9ty4pdz"
#define PREPARE [AVOSCloud setApplicationId:AVOSAppId clientKey:AVOSAppKey];
#endif


#define kTestDeviceToken @"60805ee7ff1705c73062abd417c0ec5e4aa0bbd0a211ee2ad4be8171c6dc9cba"
static NSString *const AVIM_TEST_ConversationID = @"559a77bee4b0c4d3e725a21f";
static NSString *const AVIM_TEST_ClinetID = @"a";
static NSString *const AVIM_TEST_ClinetID_Peer = @"b";
static NSString *const AVIM_TEST_ClinetID_Peer_1 = @"haha";
static NSString *const AVIM_TEST_ClinetID_Peer_2 = @"stevechen1010";

//
//#define PREPARE setenv("TEST_LOCAL", "YES", 0); \
//setenv("LOG_CURL", "YES", 0); \
//[AVOSCloud useAVCloud]; \
//[AVOSCloud setApplicationId:@"nq0awk3lh1dpmbkziz54377mryii8ny4xvp6njoygle5nlyg" clientKey:@"6vdnmdkdi4fva9i06lt50s4mcsfhppjpzm3zf5zjc9ty4pdz"];



#define DECLARE_CONTAINER static NSMutableArray *filesToDelete = nil; \
                          static NSMutableArray *objectsToDelete = nil;
#define INIT_CONTAINER filesToDelete = [[NSMutableArray alloc] init]; \
                       objectsToDelete = [[NSMutableArray alloc] init];
#define CLEAN_CONTAINER 


#define NOTIFY [self notify:XCTAsyncTestCaseStatusSucceeded];
#define WAIT [self waitForStatus:XCTAsyncTestCaseStatusSucceeded timeout:30];
#define WAIT_10 [self waitForStatus:XCTAsyncTestCaseStatusSucceeded timeout:10.0];
#define WAIT_FOREVER [self waitForStatus:XCTAsyncTestCaseStatusSucceeded timeout:DBL_MAX];

#define assertTrue(expression)        XCTAssertTrue((expression), @"")
#define assertFalse(expression)       XCTAssertFalse((expression), @"")
#define assertNil(a1)                 XCTAssertNil((a1), @"")
#define assertNotNil(a1)              XCTAssertNotNil((a1), @"")
#define assertEqual(a1, a2)           XCTAssertEqual((a1), (a2), @"")
#define assertEqualObjects(a1, a2)    XCTAssertEqualObjects((a1), (a2), @"")
#define assertNotEqual(a1, a2)        XCTAssertNotEqual((a1), (a2), @"")
#define assertNotEqualObjects(a1, a2) XCTAssertNotEqualObjects((a1), (a2), @"")
#define assertAccuracy(a1, a2, p1)    XCTAssertEqualWithAccuracy((a1),(a2),(p1))

const static void *AVTestNotification = &AVTestNotification;

//#define AVTestBase XCTestCase

@interface AVTestBase : XCTestCase
+ (void)addDeleteFile:(AVFile *)file;
+ (void)addDeleteObject:(AVObject *)object;
+ (void)addDeleteFiles:(NSArray *)files;
+ (void)addDeleteObjects:(NSArray *)objects;

- (NSString *)className;
- (void)addDeleteFile:(AVFile *)file;
- (void)addDeleteObject:(AVObject *)object;
- (void)addDeleteFiles:(NSArray *)files;
- (void)addDeleteObjects:(NSArray *)objects;

+ (void)addDeleteStatus:(AVStatus *)status;
- (void)addDeleteStatus:(AVStatus *)status;

- (id)jsonWithFileName:(NSString *)name;

- (void)waitNotification:(const void *)notification;
- (void)postNotification:(const void *)notification;

- (AVUser *)registerOrLoginWithUsername:(NSString *)username;
- (AVUser *)registerOrLoginWithUsername:(NSString *)username password:(NSString *)password;
- (void)deleteUserWithUsername:(NSString *)username password:(NSString *)password;
+ (void)deleteClass:(NSString *)className;

@end