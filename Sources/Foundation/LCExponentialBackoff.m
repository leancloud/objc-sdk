//
//  LCExponentialBackoff.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 16/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCExponentialBackoff.h"

const double LCExponentialBackoffDefaultJitter = 0.11304999836;

@implementation LCExponentialBackoff

- (instancetype)initWithInitialTime:(NSTimeInterval)initialTime
                        maximumTime:(NSTimeInterval)maximumTime
                             jitter:(double)jitter
{
    self = [super init];

    if (self) {
        _initialTime = initialTime;
        _maximumTime = maximumTime;
        _jitter = jitter;
    }

    return self;
}

- (void)resume {
    /* TODO */
}

- (void)reset {
    /* TODO */
}

@end
