//
//  AVAnalyticsUtils.m
//  paas
//
//  Created by Zhu Zeng on 8/15/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "AVAvailability.h"

#if TARGET_OS_WATCH
    #import <WatchKit/WatchKit.h>
#endif

#if AV_TARGET_OS_IOS
    #import <CoreTelephony/CTTelephonyNetworkInfo.h>
    #import <CoreTelephony/CTCarrier.h>
#endif

#import <sys/sysctl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/sockio.h>
#include <net/if.h>
#include <errno.h>
#include <net/if_dl.h>

#import "AVAnalyticsUtils.h"
#import "UserAgent.h"
#import "AVUtils.h"
#import "AVUser.h"

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

NS_INLINE
NSString *LCStringFromCGSize(CGSize size) {
    NSString *result = [NSString stringWithFormat:@"%ld x %ld", (long)size.width, (long)size.height];

    return result;
}

NS_INLINE
NSString *LCStringFromReachabilityStatus(LCNetworkReachabilityStatus status) {
    NSString *result = nil;

    switch (status) {
    case LCNetworkReachabilityStatusUnknown:
        break;
    case LCNetworkReachabilityStatusNotReachable:
        break;
    case LCNetworkReachabilityStatusReachableViaWWAN:
        result = @"WWAN";
        break;
    case LCNetworkReachabilityStatusReachableViaWiFi:
        result = @"WiFi";
        break;
    }

    return result;
}

+ (NSDictionary *)deviceInfo {
    AVSDK *SDK = [AVSDK current];
    LCDevice *device = [LCDevice current];
    LCApplication *application = [LCApplication current];

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    dictionary[@"sdk_type"]             = @"Objective-C";
    dictionary[@"sdk_version"]          = SDK.version;

    dictionary[@"device_model"]         = device.model;
    dictionary[@"language"]             = device.language;
    dictionary[@"timezone"]             = device.timezone;
    dictionary[@"os"]                   = device.systemName;
    dictionary[@"os_version"]           = device.systemVersion;
    dictionary[@"is_jailbroken"]        = @(device.jailbroken);
    dictionary[@"resolution"]           = LCStringFromCGSize(device.screenSize);
    dictionary[@"access"]               = LCStringFromReachabilityStatus(device.networkReachabilityStatus);
#if LC_TARGET_OS_IOS
    dictionary[@"device_id"]            = device.UDID;
#endif

    dictionary[@"display_name"]         = application.name;
    dictionary[@"app_version"]          = application.shortVersion;
    dictionary[@"package_name"]         = application.identifier;

    dictionary[@"uid"]                  = [AVUser currentUser].objectId;
    dictionary[@"iid"]                  = [AVInstallation currentInstallation].objectId;

    return dictionary;
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
