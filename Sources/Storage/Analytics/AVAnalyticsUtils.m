//
//  AVAnalyticsUtils.m
//  paas
//
//  Created by Zhu Zeng on 8/15/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "AVAnalyticsUtils.h"
#import "AVUser.h"
#import "AVInstallation.h"

#import "LCFoundation.h"

static NSString * identifierForVendorTag = @"identifierForVendor";

@implementation AVAnalyticsUtils

+ (NSString *)randomString:(int)length
{
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity: length];
    
    for (int i=0; i<length; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
    }
    return randomString;
}

+(NSTimeInterval)currentTimestamp
{
    NSTimeInterval seconds = [[NSDate date] timeIntervalSince1970];
    return seconds * 1000;
}

+ (NSDictionary *)statisticsData {
    AVSDK *SDK = [AVSDK current];

    NSMutableDictionary *statisticsData = [[SDK statisticsData] mutableCopy];

    statisticsData[@"uid"] = [AVUser currentUser].objectId;
    statisticsData[@"iid"] = [AVInstallation currentInstallation].objectId;

    return statisticsData;
}

+(BOOL)inSimulator
{
#if TARGET_OS_SIMULATOR
    return YES;
#else
    return NO;
#endif
}

+(BOOL)inDebug {
    return [AVAnalyticsUtils inSimulator];
}

+(BOOL)isStringEqual:(NSString *)source
                with:(NSString *)target {
    if (source == nil && target == nil)  {
        return YES;
    }
    return [source isEqualToString:target];
}

+(NSString *)safeString:(NSString *)string {
    if (string.length > 0) {
        return string;
    }
    return @"";
}

@end
