//
//  AVApplication+Internal.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 18/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVApplication+Internal.h"

NS_INLINE
NSString *LCStringFromRegion(AVApplicationRegion region) {
    NSString *result = nil;

    switch (region) {
    case AVApplicationRegionCN:
        result = @"CN";
        break;
    case AVApplicationRegionUS:
        result = @"US";
        break;
    }

    return result;
}

@implementation AVApplication (Internal)

- (NSString *)relativePath {
    AVApplicationIdentity *identity = self.identity;

    NSString *ID = identity.ID;
    NSString *region = LCStringFromRegion(identity.region);
    NSString *environment = identity.environment;

    if (!ID)
        return nil;
    if (!region)
        return nil;
    if (!environment)
        return nil;

    NSString *path = [[[[NSURL fileURLWithPath:ID]
                        URLByAppendingPathComponent:region]
                        URLByAppendingPathComponent:environment]
                        relativePath];

    return path;
}

@end
