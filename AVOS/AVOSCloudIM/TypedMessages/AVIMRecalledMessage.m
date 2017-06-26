//
//  AVIMRecalledMessage.m
//  AVOS
//
//  Created by Tang Tianyong on 26/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVIMRecalledMessage.h"

@implementation AVIMRecalledMessage

+ (void)load {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        [self registerSubclass];
    });
}

+ (AVIMMessageMediaType)classMediaType {
    return kAVIMMessageMediaTypeRecalled;
}

@end
