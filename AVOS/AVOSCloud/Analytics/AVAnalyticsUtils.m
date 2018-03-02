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
#import "LCNetworkReachabilityManager.h"
#import "AVUtils.h"
#import "AVUser.h"

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

+(NSString *)timezone
{
    NSTimeZone *localTime = [NSTimeZone systemTimeZone];
    return [NSString stringWithFormat:@"%ld", (long)[localTime secondsFromGMT] / 3600 ];
}

+(NSString *)sdkType
{
    NSString *type = @"Unknown";

#if TARGET_OS_TV
    type = @"tvOS";
#elif TARGET_OS_WATCH
    type = @"watchOS";
#elif defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    type = @"iOS";
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
    type = @"OSX";
#endif

    return type;
}

+ (BOOL) isJailbroken
{
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

+(NSString *)screenResolution
{
    CGSize size = CGSizeZero;
    CGFloat scale = 1;

#if TARGET_OS_WATCH
    size = [WKInterfaceDevice currentDevice].screenBounds.size;
    scale = [WKInterfaceDevice currentDevice].screenScale;
#elif defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    size = [[UIScreen mainScreen] bounds].size;
    scale = [[UIScreen mainScreen] scale];
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
    size = [[NSScreen mainScreen] frame].size;
    scale = 1;
#endif

    return [NSString stringWithFormat:@"%d x %d",  (int)(size.width * scale), (int)(size.height * scale)];
}

+(NSString *)systemVersion
{
    NSString *version = @"Unknown";

#if TARGET_OS_WATCH
    version = [WKInterfaceDevice currentDevice].systemVersion;
#elif defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    version = [[UIDevice currentDevice] systemVersion];
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
    version = [[NSProcessInfo processInfo] operatingSystemVersionString];
#endif

    return version;
}

+(NSString *)deviceModel
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *model = malloc(size);
    sysctlbyname("hw.machine", model, &size, NULL, 0);
    NSString *deviceModel = [NSString stringWithCString:model encoding:NSUTF8StringEncoding];
    free(model);
    return deviceModel;
}

+(NSString *)language
{
    NSString *currentLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
    return currentLanguage;
}

#if !TARGET_OS_WATCH

static NSString *const WiFiType = @"WiFi";
static NSString *const WWANType = @"WWAN";

+(BOOL)isWiFiConnection {
    return [[AVAnalyticsUtils connectionType] isEqualToString:WiFiType];
}

+(NSString *)connectionType
{
    NSString *type = @"";
    LCNetworkReachabilityManager *reachabilityManager = [LCNetworkReachabilityManager sharedManager];

    [reachabilityManager startMonitoring];

    switch (reachabilityManager.networkReachabilityStatus) {
    case AFNetworkReachabilityStatusUnknown:
        break;
    case AFNetworkReachabilityStatusNotReachable:
        break;
    case AFNetworkReachabilityStatusReachableViaWiFi:
        type = WiFiType;
    case AFNetworkReachabilityStatusReachableViaWWAN:
        type = WWANType;
    }

    return type;
}

+(NSString *)deviceId
{
    static NSString * uniqueIdentifier = nil;
    if (uniqueIdentifier != nil) {
        return uniqueIdentifier;
    }
    uniqueIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:identifierForVendorTag];
    if( !uniqueIdentifier ) {
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
        uniqueIdentifier = [UIDevice currentDevice].identifierForVendor.UUIDString;
#endif
        [[NSUserDefaults standardUserDefaults] setObject:uniqueIdentifier forKey:identifierForVendorTag];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    return uniqueIdentifier;
}

+(NSString *)carrier {
    NSString *carrier = nil;

#if AV_TARGET_OS_IOS
    CTTelephonyNetworkInfo *phoneInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *phoneCarrier = [phoneInfo subscriberCellularProvider];
    carrier = [phoneCarrier carrierName];
#endif

    return carrier ?: @"";
}

#endif

+(NSString *)appVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

+ (NSString *)buildVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey];
}

+ (NSString *)packageName {
    return [NSBundle mainBundle].bundleIdentifier;
}

+ (NSString *)displayName {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"];
}

/*
 {"timezone":"8",
 "sdk_type":"iOS",
 "resolution":"960 x 640",
 "package_name":"com.avos.iconview",
 "sv":"1.0",
 "is_jailbroken":"NO",
 "carrier":"",
 "access":"WiFi",
 "channel":"App Store",
 "os":"iOS",
 "display_name":"iconview",
 "os_version":"6.1",
 "device_model":"x86_64",
 "app_version":"1.0",
 "country":"US",
 "language":"en",
 "sdk_version":"2.2.0.OpenUDID",
 "appkey":"5151742a56240b91ab001217",
 "mc":"54:26:96:CF:D8:7D",
 "device_id":"e50a768b2d55e7c9bdc07AV5c95f2eb23ce57a76",
 "is_pirated":"NO"}
 */
+(NSMutableDictionary *)deviceInfo
{
    static NSMutableDictionary *staticDic;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        staticDic = [NSMutableDictionary dictionaryWithCapacity:16];
        
        staticDic[@"sdk_version"] = SDK_VERSION;

#if !TARGET_OS_WATCH
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
        NSString *deviceId = [AVAnalyticsUtils deviceId];
        if (deviceId) { staticDic[@"device_id"] = deviceId; }
#endif
#endif
        
        staticDic[@"is_jailbroken"] = @([AVAnalyticsUtils isJailbroken]);
        
        NSString *deviceModel = [AVAnalyticsUtils deviceModel];
        if (deviceModel) { staticDic[@"device_model"] = deviceModel; }
        
        NSString *resolution = [AVAnalyticsUtils screenResolution];
        if (resolution) { staticDic[@"resolution"] = resolution; }
        
        NSString *osVersion = [AVAnalyticsUtils systemVersion];
        if (osVersion) { staticDic[@"os_version"] = osVersion; }
        
        NSString *language = [AVAnalyticsUtils language];
        if (language) { staticDic[@"language"] = language; }
        
        NSString *timezone = [AVAnalyticsUtils timezone];
        if (timezone) { staticDic[@"timezone"] = timezone; }
        
        NSString *buildVersion = [AVAnalyticsUtils buildVersion];
        if (buildVersion) { staticDic[@"sv"] = buildVersion; }

        NSString *appVersion = [AVAnalyticsUtils appVersion];
        if (appVersion) { staticDic[@"app_version"] = appVersion; }
        
        NSString *packageName = [AVAnalyticsUtils packageName];
        if (packageName) { staticDic[@"package_name"] = packageName; }
        
        NSString *displayName = [AVAnalyticsUtils displayName];
        if (displayName) { staticDic[@"display_name"] = displayName; }
    });
    
    NSMutableDictionary *dynamicDic = [NSMutableDictionary dictionaryWithCapacity:4];
    
    NSString *sdkType = [self sdkType];
    if (sdkType) { dynamicDic[@"os"] = sdkType; }

#if !TARGET_OS_WATCH
    NSString *connectionType = [AVAnalyticsUtils connectionType];
    if (connectionType) { dynamicDic[@"access"] = connectionType; }
    
    NSString *carrier = [AVAnalyticsUtils carrier];
    if (carrier) { dynamicDic[@"carrier"] = carrier; }
#endif
    
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithDictionary:staticDic];
    
    [dic addEntriesFromDictionary:dynamicDic];
    
    AVUser *currentUser = [AVUser currentUser];
    
    if (currentUser && currentUser.objectId) {
        
        NSDictionary *currentUserDic = @{ @"uid" : currentUser.objectId };
        
        [dic addEntriesFromDictionary:currentUserDic];
    }
    
    AVInstallation *currentInstallation = [AVInstallation defaultInstallation];
    
    if (currentInstallation && currentInstallation.objectId) {
        
        NSDictionary *currentInstallationDic = @{ @"iid": currentInstallation.objectId };
        
        [dic addEntriesFromDictionary:currentInstallationDic];
    }
    
    return dic;
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
    if (string && string.length > 0) {
        return string;
    }
    return @"";
}

@end
