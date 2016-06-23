//
//  AVOSCloudCrashReporting.m
//  AVOSCloudCrashReporting
//
//  Created by Qihe Bian on 3/3/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVOSCloudCrashReporting.h"
#import "AVOSCloudCrashReporting_Internal.h"
#import "AVOSCloud_Internal.h"
#import <CommonCrypto/CommonCrypto.h>
#import "UserAgent.h"
#import "AVAnalyticsUtils.h"
#import "AVPaasClient.h"

static BOOL crashReportingEnabled = NO;

@interface NSString (MD5)
- (NSString *)AVCRMD5String;
@end
@implementation NSString (MD5)
- (NSString *)AVCRMD5String {
    const char *cstr = [self UTF8String];
    unsigned char result[16];
    CC_MD5(cstr, (CC_LONG)strlen(cstr), result);
    
    //???: 为什么要返回大写MD5 一般都是小写
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}
@end
@implementation AVOSCloudCrashReporting

+ (instancetype)sharedInstance {
    static AVOSCloudCrashReporting *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

+ (BOOL)isCrashReportingEnabled {
    return crashReportingEnabled;
}

+ (void)enable {
    if (crashReportingEnabled) {
        return;
    }
    [AVOSCloud enableAVOSCloudModule:self];
    crashReportingEnabled = YES;
}

+ (NSString *)uploadingURL {
    return [[[AVOSCloud RESTBaseURL] URLByAppendingPathComponent:@"stats/breakpad/minidump"] absoluteString];
}

+ (void)AVOSCloudDidInitializeWithApplicationId:(NSString *)applicationId clientKey:(NSString *)clientKey {
    [[self sharedInstance] enableCrashReportingWithApplicationId:applicationId clientKey:clientKey];
}

- (void)enableCrashReportingWithApplicationId:(NSString *)applicationId clientKey:(NSString *)clientKey {
    if (!_crashReporter) {
        _crashReporter = [BreakpadController sharedInstance];
    }

    [_crashReporter setUploadingURL:[[self class] uploadingURL]];
    [_crashReporter setUploadInterval:30];

    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    NSString *signature = [[AVPaasClient sharedInstance] signatureHeaderFieldValue];

    [dict setValue:applicationId forKey:[@BREAKPAD_SERVER_HEADER_PREFIX stringByAppendingString:LCHeaderFieldNameId]];
    [dict setValue:signature     forKey:[@BREAKPAD_SERVER_HEADER_PREFIX stringByAppendingString:LCHeaderFieldNameSign]];
    [dict setValue:USER_AGENT    forKey:[@BREAKPAD_SERVER_HEADER_PREFIX stringByAppendingString:@"User-Agent"]];

    [dict addEntriesFromDictionary:[AVAnalyticsUtils deviceInfo]];
    
    [_crashReporter setParametersToAddAtUploadTime:dict];
    
    [_crashReporter start:NO];
    
    [_crashReporter setUploadingEnabled:YES];
    
}

@end
