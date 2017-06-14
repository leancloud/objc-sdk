//
//  AVSDK.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 13/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVSDK.h"

#define LC_SDK_VERSION "v6.0.0"

@implementation AVSDK

+ (instancetype)current {
    static AVSDK *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

- (NSString *)version {
    return @(LC_SDK_VERSION);
}

@end
