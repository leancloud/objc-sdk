//
//  LCIMRecalledMessage.m
//  LeanCloud
//
//  Created by Tang Tianyong on 26/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCIMRecalledMessage.h"

@implementation LCIMRecalledMessage

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self registerSubclass];
    });
}

+ (LCIMMessageMediaType)classMediaType
{
    return LCIMMessageMediaTypeRecalled;
}

@end
