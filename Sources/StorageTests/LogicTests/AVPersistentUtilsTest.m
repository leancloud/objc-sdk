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

- (void)assertPath:(NSString *)path equalToRelativePath:(NSString *)relativePath {
    NSString *home = NSHomeDirectory();
#if AV_OSX_ONLY
    home = [home stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Application Support/LeanCloud/%@", [AVOSCloud getApplicationId]]];
#endif
    path = [path stringByReplacingOccurrencesOfString:home withString:@"~"];
    XCTAssertEqualObjects(path, relativePath);
}

- (void)testCurrentUserArchivePath {
    NSString *path = [AVPersistenceUtils currentUserArchivePath];
    [self assertPath:path equalToRelativePath:@"~/Library/Private Documents/AVPaas/currentUser"];
}

- (void)testMessageCacheDatabasePath {
    NSString *path = [AVPersistenceUtils messageCacheDatabasePathWithName:@"chat"];
    [self assertPath:path equalToRelativePath:@"~/Library/Caches/LeanCloud/MessageCache/chat"];
}

- (void)testCommandCacheDatabasePath {
    NSString *path = [AVPersistenceUtils commandCacheDatabasePath];
    [self assertPath:path equalToRelativePath:@"~/Documents/LeanCloud/CommandCache"];
}

@end
