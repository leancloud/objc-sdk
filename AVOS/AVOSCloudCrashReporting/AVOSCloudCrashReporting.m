//
//  AVOSCloudCrashReporting.m
//  AVOSCloudCrashReporting
//
//  Created by Qihe Bian on 3/3/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVOSCloudCrashReporting.h"
#import "BreakpadController.h"
#import "AVOSCloud_Internal.h"
#import "UserAgent.h"
#import "AVAnalyticsUtils.h"
#import "AVPaasClient.h"
#import "LCRouter.h"

static BOOL crashReportingEnabled = NO;

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
    NSString *URLString = [[LCRouter sharedInstance] URLStringForPath:@"stats/breakpad/minidump"];
    return URLString;
}

+ (void)AVOSCloudDidInitializeWithApplicationId:(NSString *)applicationId clientKey:(NSString *)clientKey {
    [[self sharedInstance] enableCrashReportingWithApplicationId:applicationId clientKey:clientKey];
}

- (instancetype)init {
    self = [super init];

    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(routerDidUpdate:)
                                                     name:LCRouterDidUpdateNotification
                                                   object:nil];
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)routerDidUpdate:(NSNotification *)notification {
    @synchronized (self) {
        [self configureAndStart];
    }
}

- (void)enableCrashReportingWithApplicationId:(NSString *)applicationId clientKey:(NSString *)clientKey {
    @synchronized (self) {
        [self configureAndStart];
    }
}

- (void)configureAndStart {
    BreakpadController *crashReporter = [BreakpadController sharedInstance];

    /* Stop before configration. */
    [crashReporter stop];

    [crashReporter setUploadInterval:30];
    [crashReporter setUploadingURL:[[self class] uploadingURL]];

    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    NSString *applicationId = [AVOSCloud getApplicationId];
    NSString *signature = [[AVPaasClient sharedInstance] signatureHeaderFieldValue];

    [dict setValue:applicationId forKey:[@BREAKPAD_SERVER_HEADER_PREFIX stringByAppendingString:LCHeaderFieldNameId]];
    [dict setValue:signature     forKey:[@BREAKPAD_SERVER_HEADER_PREFIX stringByAppendingString:LCHeaderFieldNameSign]];
    [dict setValue:USER_AGENT    forKey:[@BREAKPAD_SERVER_HEADER_PREFIX stringByAppendingString:@"User-Agent"]];

    [dict addEntriesFromDictionary:[AVAnalyticsUtils deviceInfo]];

    [crashReporter setParametersToAddAtUploadTime:dict];

    [crashReporter start:NO];

    [crashReporter setUploadingEnabled:YES];
}

@end
