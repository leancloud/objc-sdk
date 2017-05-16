//
//  AVSubscriber.m
//  AVOS
//
//  Created by Tang Tianyong on 16/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVSubscriber.h"
#import "AVUtils.h"

@implementation AVSubscriber

+ (instancetype)sharedInstance {
    static AVSubscriber *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[AVSubscriber alloc] init];
    });

    return instance;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        _identifier = [AVUtils deviceUUID];
    }

    return self;
}

@end
