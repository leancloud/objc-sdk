//
//  LCBundle.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 14/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCBundle.h"
#import "LCUUID.h"

@implementation LCBundle

+ (instancetype)current {
    static LCBundle *instance;
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
    static NSString *identifier;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        identifier = [NSBundle mainBundle].bundleIdentifier;

        /* For unit test, identifier is nil.
           So, we create a one-time use bundle identifier. */
        if (!identifier) {
            NSString *UUID = [LCUUID createUUID];
            NSString *domain = @"cn.leancloud.pseudo-bundle-identifier";
            identifier = [NSString stringWithFormat:@"%@.%@", domain, UUID];
        }
    });

    return identifier;
}

- (NSString *)name {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"];
}

@end
