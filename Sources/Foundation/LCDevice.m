//
//  LCDevice.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 13/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCDevice.h"

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

@end
