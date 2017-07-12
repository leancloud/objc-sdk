//
//  FoundationTests.m
//  FoundationTests
//
//  Created by Tang Tianyong on 12/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AVNamedTable.h"

@interface FoundationTests : XCTestCase

@end

@interface AVNamedTableSubclass : AVNamedTable

@property (nonatomic, assign) NSInteger number;
@property (nonatomic,   copy) NSString *string;
@property (nonatomic, strong) id<NSCopying, NSSecureCoding> object;

- (instancetype)initWithNumber:(NSInteger)number
                        string:(NSString *)string
                        object:(id<NSCopying, NSSecureCoding>)object;

@end

@implementation AVNamedTableSubclass

- (instancetype)initWithNumber:(NSInteger)number
                        string:(NSString *)string
                        object:(id<NSCopying,NSSecureCoding>)object
{
    self = [super init];

    if (self) {
        _number = number;
        _string = [string copy];
        _object = object;
    }

    return self;
}

@end

@implementation FoundationTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNamedTable {
    NSInteger number = 42;
    /* Use mutable string to make sure that it can be copied. */
    NSString *string = [[NSMutableString alloc] initWithFormat:@"foo and bar"];
    id        object = [NSArray array];

    AVNamedTableSubclass *namedTable = [[AVNamedTableSubclass alloc] init];

    namedTable.number = number;
    namedTable.string = string;
    namedTable.object = object;

    XCTAssertEqual(namedTable.number, number);
    XCTAssertEqualObjects(namedTable.string, string);
    XCTAssertEqualObjects(namedTable.object, object);

    /* Make sure that the copy property works as expected. */
    XCTAssertNotEqual(namedTable.string, string);

    AVNamedTableSubclass *namedTableCopy = [namedTable copy];

    XCTAssertEqual(namedTableCopy.number, number);
    XCTAssertEqualObjects(namedTableCopy.string, string);
    XCTAssertEqualObjects(namedTableCopy.object, object);

    /* Test encode and decode. */
    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:namedTable];
    AVNamedTableSubclass *decodedNamedTable = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];

    XCTAssertEqual(decodedNamedTable.number, number);
    XCTAssertEqualObjects(decodedNamedTable.string, string);
    XCTAssertEqualObjects(decodedNamedTable.object, object);

    /* Test instance variables work as expected. */
    AVNamedTableSubclass *yaNamedTable = [[AVNamedTableSubclass alloc] initWithNumber:number
                                                                               string:string
                                                                               object:object];

    XCTAssertEqual(yaNamedTable.number, number);
    XCTAssertEqualObjects(yaNamedTable.string, string);
    XCTAssertEqualObjects(yaNamedTable.object, object);
}

@end
