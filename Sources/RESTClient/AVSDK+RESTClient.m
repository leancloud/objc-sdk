//
//  AVSDK+RESTClient.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 20/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVSDK+RESTClient.h"
#import "LCFoundation.h"

@implementation AVSDK (RESTClient)

- (NSString *)HTTPUserAgent {
    NSString *target = nil;

#if LC_TARGET_OS_IOS
    target = @"iOS";
#elif LC_TARGET_OS_MAC
    target = @"Mac";
#elif LC_TARGET_OS_TV
    target = @"TV";
#elif LC_TARGET_OS_WATCH
    target = @"Watch";
#else
    target = @"Unknown";
#endif

    NSString *userAgent = [NSString stringWithFormat:@"LeanCloud-ObjC-SDK/%@ (%@)", self.version, target];

    return userAgent;
}

@end
