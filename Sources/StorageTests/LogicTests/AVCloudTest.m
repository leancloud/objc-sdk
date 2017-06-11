//
//  AVCloudTest.m
//  paas
//
//  Created by Travis on 14-1-16.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import "AVTestBase.h"

@interface AVCloudTest : AVTestBase

@end

@implementation AVCloudTest

- (void)testCallFunction {
    NSError *error;
    id response = [AVCloud callFunction:@"hello" withParameters:nil error:&error];
    XCTAssertNotNil(response);
    XCTAssertEqualObjects(@"Hello world!", response);
}

- (void)testNonExistentFunction {
    NSError *error;
    id result = [AVCloud callFunction:@"non-existent" withParameters:nil error:&error];
    XCTAssertNil(result);
    XCTAssertEqual(error.code, 1);
    XCTAssertTrue([error.localizedDescription hasPrefix:@"LeanEngine not found function named 'non-existent' for app "]);
}

- (void)testErrorCode {
    NSError *error;
    id response = [AVCloud callFunction:@"errorCode" withParameters:nil error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 211);
    XCTAssertEqualObjects(error.localizedDescription, @"Could not find user");
}

- (void)testCustomeErrorCode {
    NSError *error;
    id response = [AVCloud callFunction:@"customErrorCode" withParameters:nil error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 123);
    XCTAssertEqualObjects(error.localizedDescription, @"custom error message");
}

-(void)testFetchObject {
    AVObject *object = [AVObject objectWithClassName:NSStringFromClass([self class])];
    [object save];
    [self addDeleteObject:object];
    AVObject *obj=[AVObject objectWithoutDataWithClassName:NSStringFromClass([self class]) objectId:object.objectId];
    NSDictionary *params=@{@"obj":obj};
    
    // return: {"objectId":"55d37fb600b09b5389a7c4ef","createdAt":"2015-08-18T18:55:50.357Z",
    //         "updatedAt":"2015-08-18T18:55:50.357Z"}
    
    NSError *error;
    NSDictionary *result = [AVCloud callFunction:@"fetchObject" withParameters:params error:&error];
    XCTAssertNil(error);
    
    [obj objectFromDictionary:result];
    XCTAssertEqualObjects(obj.createdAt, object.createdAt);
}

- (void)testFullObject {
    NSError *error;
    id result = [AVCloud callFunction:@"fullObject" withParameters:nil error:&error];
    XCTAssertNil(error);
    XCTAssertEqual([result class], [AVObject class]);
    AVObject *object = (AVObject *)result;
    XCTAssertEqual(object[@"boolean"], @(YES));
    XCTAssertTrue([object[@"number"] intValue] == 1);
    XCTAssertEqualObjects(object[@"string"], @"string");
    XCTAssertEqualObjects(object[@"array"][0], @"a");
    XCTAssertTrue([object[@"date"] isKindOfClass:[NSDate class]]);
    XCTAssertEqualObjects(object[@"map"][@"a"], @(1));
    [self addDeleteObject:object];
}

- (void)testBeforeSave {
    AVObject *object = [AVObject objectWithClassName:self.className];
    object[@"string"] = @"This is too much long, too much long, too long";
    NSError *error;
    object.fetchWhenSave = YES;
    [object save:&error];
    XCTAssertEqual(((NSString *)object[@"string"]).length, 10);
    
    [self addDeleteObject:object];
}

- (void)testComplexObject {
    AVObject *object = [AVObject objectWithClassName:self.className];
    object[@"string"] = @"test";
    NSError *error;
    [object save:&error];
    assertNil(error);
    [AVCloud rpcFunctionInBackground:@"complexObject" withParameters:@{@"testObject": object} block:^(id object, NSError *error) {
        assertEqual([NSThread mainThread], [NSThread currentThread]);
        assertNil(error);
        assertEqual([object[@"avObject"][@"number"] intValue], 1);
        assertEqualObjects(object[@"foo"], @"bar");
        assertTrue([object[@"avObjects"][0][@"boolean"] boolValue]);
        // assertNil(object[@"testObject"][@"__type"]);
        assertEqualObjects(object[@"testObject"][@"string"], @"test");
        NOTIFY
    }];
    WAIT
}

@end
