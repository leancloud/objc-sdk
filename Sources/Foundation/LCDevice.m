//
//  LCDevice.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 13/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCDevice.h"
#import "EXTScope.h"
#import "LCTargetConditionals.h"
#import "LCTargetUmbrella.h"
#import "AFNetworkReachabilityManager.h"

#if LC_TARGET_OS_IOS

#import "LCUUID.h"
#import "JNKeychain.h"

#endif

#import <sys/sysctl.h>

@implementation LCDevice

+ (instancetype)current {
    static LCDevice *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

- (BOOL)jailbroken {
#if TARGET_OS_SIMULATOR
    return NO;
#else
    FILE *bash = fopen("/bin/bash", "r");

    if (bash) {
        fclose(bash);
        return YES;
    }

    return NO;
#endif
}

- (NSString *)model {
    size_t size = 0;

    sysctlbyname("hw.machine", NULL, &size, NULL, 0);

    if (!size)
        return nil;

    char *modelptr = malloc(size);

    if (!modelptr)
        return nil;

    @onExit {
        free(modelptr);
    };

    int error = sysctlbyname("hw.machine", modelptr, &size, NULL, 0);

    if (error)
        return nil;

    NSString *model = [NSString stringWithCString:modelptr encoding:NSUTF8StringEncoding];

    return model;
}

- (CGSize)screenSize {
    CGSize size = CGSizeZero;
    CGFloat scale = 1;

#if LC_TARGET_OS_IOS
    UIScreen *screen = [UIScreen mainScreen];
    size = screen.bounds.size;
    scale = screen.scale;
#elif LC_TARGET_OS_MAC
    NSScreen *screen = [NSScreen mainScreen];
    size = screen.frame.size;
#elif LC_TARGET_OS_WATCH
    WKInterfaceDevice *device = [WKInterfaceDevice currentDevice];
    size = device.screenBounds.size;
    scale = device.screenScale;
#elif LC_TARGET_OS_TV
    UIScreen *screen = [UIScreen mainScreen];
    size = screen.bounds.size;
    scale = screen.scale;
#endif

    CGSize pixelSize = CGSizeMake(size.width * scale, size.height * scale);
    return pixelSize;
}

- (NSString *)systemVersion {
    NSString *version = nil;

#if LC_TARGET_OS_IOS
    version = [UIDevice currentDevice].systemVersion;
#elif LC_TARGET_OS_MAC
    version = [NSProcessInfo processInfo].operatingSystemVersionString;
#elif LC_TARGET_OS_WATCH
    version = [WKInterfaceDevice currentDevice].systemVersion;
#elif LC_TARGET_OS_TV
    version = [UIDevice currentDevice].systemVersion;
#endif

    return version;
}

- (NSString *)systemName {
    NSString *name = nil;

#if LC_TARGET_OS_IOS
    name = @"iOS";
#elif LC_TARGET_OS_MAC
    name = @"OSX";
#elif LC_TARGET_OS_WATCH
    name = @"watchOS";
#elif LC_TARGET_OS_TV
    name = @"tvOS";
#endif

    return name;
}

- (NSString *)language {
    NSString *currentLanguage = [[NSLocale preferredLanguages] firstObject];
    return currentLanguage;
}

- (NSString *)timezone {
    NSTimeZone *localTime = [NSTimeZone systemTimeZone];
    return [NSString stringWithFormat:@"%ld", (long)(localTime.secondsFromGMT / 3600)];
}

- (LCNetworkReachabilityStatus)networkReachabilityStatus {
    LCNetworkReachabilityStatus status = LCNetworkReachabilityStatusUnknown;
#if LC_TARGET_OS_WATCH
    return status;
#else
    AFNetworkReachabilityManager *reachabilityManager = [AFNetworkReachabilityManager sharedManager];

    [reachabilityManager startMonitoring];

    switch (reachabilityManager.networkReachabilityStatus) {
    case AFNetworkReachabilityStatusUnknown:
        status = LCNetworkReachabilityStatusUnknown;
        break;
    case AFNetworkReachabilityStatusNotReachable:
        status = LCNetworkReachabilityStatusNotReachable;
        break;
    case AFNetworkReachabilityStatusReachableViaWWAN:
        status = LCNetworkReachabilityStatusReachableViaWWAN;
        break;
    case AFNetworkReachabilityStatusReachableViaWiFi:
        status = LCNetworkReachabilityStatusReachableViaWiFi;
        break;
    }

    return status;
#endif
}

- (BOOL)inWiFi {
    return self.networkReachabilityStatus == LCNetworkReachabilityStatusReachableViaWiFi;
}

- (NSString *)networkCarrierName {
#if LC_TARGET_OS_IOS
    CTTelephonyNetworkInfo *phoneInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *phoneCarrier = phoneInfo.subscriberCellularProvider;
    NSString *carrierName = phoneCarrier.carrierName;

    return carrierName;
#else
    return nil;
#endif
}

#if LC_TARGET_OS_IOS

- (NSString *)UDIDKey {
    NSString *key = nil;
    static NSString *const suffix = @"@leancloud";

    NSString *bundleIdentifier = self.bundleIdentifier;

    /* Bundle identifier may be nil for unit test. */
    if (bundleIdentifier) {
        key = [bundleIdentifier stringByAppendingString:suffix];
    } else {
        key = [@"~" stringByAppendingString:suffix];
    }

    return key;
}

- (NSString *)UDID {
    static NSString *UDID = nil;

    if (UDID)
        return UDID;

    @synchronized([LCDevice class]) {
        if (UDID)
            return UDID;

        NSString *key = [self UDIDKey];
        UDID = [JNKeychain loadValueForKey:key];

        if (UDID)
            return UDID;

        UDID = [LCUUID createUUID];
        [JNKeychain saveValue:UDID forKey:key];

        return UDID;
    }
}

#endif

@end
