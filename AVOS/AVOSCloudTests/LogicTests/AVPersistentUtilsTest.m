//
//  AVPersistentUtilsTest.m
//  AVOS
//
//  Created by lzw on 15/10/27.
//  Copyright © 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVTestBase.h"
#import "AVPersistenceUtils.h"

@interface AVPersistentUtilsTest : AVTestBase

@end

@implementation AVPersistentUtilsTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)assertPath:(NSString *)path hasSuffix:(NSString *)suffix {
    XCTAssertTrue([path hasSuffix:suffix]);
}

- (void)testCurrentUserArchivePath {
    NSString *path = [AVPersistenceUtils currentUserArchivePath];
    [self assertPath:path hasSuffix:@"Private Documents/AVPaas/currentUser"];
}

- (void)testMessageCacheDatabasePath {
    NSString *path = [AVPersistenceUtils messageCacheDatabasePathWithName:@"Chat"];
    [self assertPath:path hasSuffix:@"Caches/MessageCache/Chat"];
}

- (void)testCommandCacheDatabasePath {
    NSString *path = [AVPersistenceUtils commandCacheDatabasePath];
    [self assertPath:path hasSuffix:@"Caches/CommandCache"];
}

@end
