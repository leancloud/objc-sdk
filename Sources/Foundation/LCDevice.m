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

@end
