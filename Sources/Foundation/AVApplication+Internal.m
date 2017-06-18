//
//  AVApplication+Internal.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 18/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVApplication+Internal.h"

@implementation AVApplication (Internal)

- (NSString *)relativePath {
    NSString *ID = self.ID;
    NSString *environment = self.environment;

    if (!ID)
        return nil;
    if (!environment)
        return nil;

    NSString *path = [NSString stringWithFormat:@"%@/%@", ID, environment];

    return path;
}

@end
