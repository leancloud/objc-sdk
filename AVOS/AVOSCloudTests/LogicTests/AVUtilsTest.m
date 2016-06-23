//
//  AVUtilsTest.m
//  AVOS
//
//  Created by lzw on 15/11/12.
//  Copyright © 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVTestBase.h"
#import "AVUtils.h"
#import "AVLogger.h"

@interface AVUtilsTest : AVTestBase

@end

@implementation AVUtilsTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testLog {
    // [INFO] -[AVUtilsTest testLog] [Line 29] Now running testLog
    AVLoggerI(@"Now running testLog");
    AVLoggerE(@"Network error");
    AVLoggerI(@"Test format %@ %s %d", @"string", "c string", 10);
}

- (void)testLogEnabled {
    // 观察日志是否输出
    [AVOSCloud setAllLogsEnabled:NO];
    AVLoggerD(@"debug");
    [[AVInstallation currentInstallation] save];
    [AVOSCloud setAllLogsEnabled:YES];
}

@end
