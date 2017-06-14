//
//  LCApplication.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 14/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCApplication.h"

@implementation LCApplication

+ (instancetype)current {
    static LCApplication *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

- (NSString *)version {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
}

- (NSString *)shortVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (NSString *)identifier {
    return [NSBundle mainBundle].bundleIdentifier;
}

- (NSString *)name {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"];
}

@end
