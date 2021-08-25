//
//  LCScheduler.m
//  paas
//
//  Created by Summer on 13-8-22.
//  Copyright (c) 2013年 LeanCloud. All rights reserved.
//

#import "LCScheduler.h"
#import "LCCacheManager.h"
#import "LCPaasClient.h"

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

@implementation LCScheduler

+ (LCScheduler *)sharedInstance {
    static dispatch_once_t once;
    static LCScheduler *instance;
    dispatch_once(&once, ^{
        instance = [[LCScheduler alloc] init];
        [instance setup];
    });
    return instance;
}

- (void)setup {
    self.queryCacheExpiredDays = 30;
    self.fileCacheExpiredDays = 30;
    
#if TARGET_OS_IOS || TARGET_OS_TV
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didFinishLaunching:)
                                                 name:UIApplicationDidFinishLaunchingNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveMemoryWarning:)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
#elif TARGET_OS_OSX
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didEnterBackground:)
                                                 name:NSApplicationDidFinishLaunchingNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willEnterForeground:)
                                                 name:NSApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didFinishLaunching:)
                                                 name:NSApplicationDidFinishLaunchingNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willTerminate:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:nil];
#endif
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#if !TARGET_OS_WATCH
- (void)didEnterBackground:(NSNotification *)notification {
    [self clearCache];
}

- (void)willEnterForeground:(NSNotification *)notification {
    [self handleArchivedRequests];
}

- (void)didFinishLaunching:(NSNotification *)notification {
    [self handleArchivedRequests];
}

- (void)didReceiveMemoryWarning:(NSNotification *)notification {
    // Stub method
}

- (void)willTerminate:(NSNotification *)notification {
    // Stub method
}
#endif

- (void)handleArchivedRequests {
    [[LCPaasClient sharedInstance] handleAllArchivedRequests];
}

- (void)clearCache {
    [LCCacheManager clearCacheMoreThanDays:self.queryCacheExpiredDays];
}

@end
