//
//  AVSDK+Internal.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 15/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVSDK+Internal.h"
#import "LCDevice.h"
#import "LCBundle.h"
#import "AVTargetConditionals.h"

#define LC_SDK_TYPE @"Objective-C"

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

@implementation AVSDK (Internal)

- (NSDictionary *)statisticsData {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    LCDevice *device = [LCDevice current];
    LCBundle *bundle = [LCBundle current];

    /* SDK basic data. */
    data[@"sdk_type"]       = LC_SDK_TYPE;
    data[@"sdk_version"]    = self.version;

    /* Device related data. */
    data[@"device_model"]   = device.model;
    data[@"os"]             = device.systemName;
    data[@"os_version"]     = device.systemVersion;
    data[@"resolution"]     = LCStringFromCGSize(device.screenSize);
    data[@"language"]       = device.language;
    data[@"timezone"]       = device.timezone;
    data[@"access"]         = LCStringFromReachabilityStatus(device.networkReachabilityStatus);
    data[@"is_jailbroken"]  = @(device.jailbroken);
    data[@"device_id"]      = device.UDID;

    /* Application related data. */
    data[@"display_name"]   = bundle.name;
    data[@"app_version"]    = bundle.shortVersion;
    data[@"package_name"]   = bundle.identifier;

    return data;
}

@end
