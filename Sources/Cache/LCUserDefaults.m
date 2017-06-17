//
//  LCUserDefaults.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 17/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCUserDefaults.h"

@implementation LCUserDefaults

+ (instancetype)sharedInstance {
    static LCUserDefaults *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

@end
