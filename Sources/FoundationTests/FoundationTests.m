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
/* Test capitalized property. */
@property (nonatomic, assign) NSInteger AnotherNumber;
@property (nonatomic,   copy) NSString *string;
@property (nonatomic, strong) id<NSCopying, NSSecureCoding> object;

- (instancetype)initWithNumber:(NSInteger)number
                 AnotherNumber:(NSInteger)AnotherNumber
                        string:(NSString *)string
                        object:(id<NSCopying, NSSecureCoding>)object;

@end

@implementation AVNamedTableSubclass

- (instancetype)initWithNumber:(NSInteger)number
                 AnotherNumber:(NSInteger)AnotherNumber
                        string:(NSString *)string
                        object:(id<NSCopying,NSSecureCoding>)object
{
    self = [super init];

    if (self) {
        _number = number;
        _AnotherNumber = AnotherNumber;
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
    NSInteger AnotherNumber = 1024;
    /* Use mutable string to make sure that it can be copied. */
    NSString *string = [[NSMutableString alloc] initWithFormat:@"foo and bar"];
    id<NSCopying, NSSecureCoding> object = [NSArray array];

#define TEST_NAMED_TABLE_PROPERTY_EQUALITY(namedTable) do {     \
    XCTAssertEqual(namedTable.number, number);                  \
    XCTAssertEqual(namedTable.AnotherNumber, AnotherNumber);    \
    XCTAssertEqualObjects(namedTable.string, string);           \
    XCTAssertEqualObjects(namedTable.object, object);           \
    /* Make sure that the copy property works as expected. */   \
    XCTAssertNotEqual(namedTable.string, string);               \
} while (0)

    NSData *archivedData = nil;

    AVNamedTableSubclass *namedTable = [[AVNamedTableSubclass alloc] init];

    namedTable.number = number;
    namedTable.AnotherNumber = AnotherNumber;
    namedTable.string = string;
    namedTable.object = object;

    TEST_NAMED_TABLE_PROPERTY_EQUALITY(namedTable);

    AVNamedTableSubclass *namedTableCopy = [namedTable copy];
    TEST_NAMED_TABLE_PROPERTY_EQUALITY(namedTableCopy);

    /* Test encode and decode. */
    archivedData = [NSKeyedArchiver archivedDataWithRootObject:namedTable];
    AVNamedTableSubclass *decodedNamedTable = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    TEST_NAMED_TABLE_PROPERTY_EQUALITY(decodedNamedTable);

    /* Test instance variables work as expected. */
    AVNamedTableSubclass *yaNamedTable = [[AVNamedTableSubclass alloc] initWithNumber:number
                                                                        AnotherNumber:AnotherNumber
                                                                               string:string
                                                                               object:object];
    TEST_NAMED_TABLE_PROPERTY_EQUALITY(yaNamedTable);

    AVNamedTableSubclass *yaNamedTableCopy = [yaNamedTable copy];
    TEST_NAMED_TABLE_PROPERTY_EQUALITY(yaNamedTableCopy);

    archivedData = [NSKeyedArchiver archivedDataWithRootObject:yaNamedTable];
    AVNamedTableSubclass *encodedYaNamedTable = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    TEST_NAMED_TABLE_PROPERTY_EQUALITY(encodedYaNamedTable);
}

@end
