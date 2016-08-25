//
//  AVIMOnlineStatusPolicy.m
//  AVOS
//
//  Created by Tang Tianyong on 8/23/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import "AVIMOnlineStatusPolicy.h"

@implementation AVIMOnlineStatusPolicy

- (instancetype)initWithPublishable:(BOOL)publishable subscribable:(BOOL)subscribable TTL:(int32_t)TTL {
    self = [super init];

    if (self) {
        self.publishable  = publishable;
        self.subscribable = subscribable;
        self.TTL = TTL;
    }

    return self;
}

@end
