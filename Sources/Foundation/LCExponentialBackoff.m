//
//  LCExponentialBackoff.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 16/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCExponentialBackoff.h"
#import "LCExponentialTimer.h"

const double LCExponentialBackoffDefaultJitter = 0.11304999836;

@interface LCExponentialBackoff ()

@property (nonatomic, strong) dispatch_source_t dispatchTimer;
@property (nonatomic, strong) dispatch_queue_t dispatchQueue;
@property (nonatomic, strong) LCExponentialTimer *exponentialTimer;

@end

@implementation LCExponentialBackoff

- (instancetype)initWithInitialTime:(NSTimeInterval)initialTime
                        maximumTime:(NSTimeInterval)maximumTime
                             jitter:(double)jitter
{
    self = [super init];

    if (self) {
        _dispatchQueue = dispatch_queue_create("cn.leancloud.exponential-backoff", DISPATCH_QUEUE_SERIAL);
        _exponentialTimer = [LCExponentialTimer exponentialTimerWithInitialTime:initialTime
                                                                        maxTime:maximumTime
                                                                         jitter:jitter];
    }

    return self;
}

- (void)setNextTimer {
    dispatch_source_t dispatchTimer = _dispatchTimer;

    if (!dispatchTimer)
        return;

    NSTimeInterval next = [self.exponentialTimer timeIntervalAndCalculateNext];
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, next * NSEC_PER_SEC);
    uint64_t leeway = (uint64_t)(0.01 * NSEC_PER_SEC);

    dispatch_source_set_timer(dispatchTimer, start, 0, leeway);
}

- (void)timerDidReach {
    @synchronized (self) {
        if (!_dispatchTimer)
            return;

        if ([self.delegate respondsToSelector:@selector(exponentialBackoffDidReach:)])
            [self.delegate exponentialBackoffDidReach:self];

        [self setNextTimer];
    }
}

- (void)resume {
    @synchronized (self) {
        if (_dispatchTimer)
            return;

        dispatch_source_t dispatchTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _dispatchQueue);
        dispatch_source_set_event_handler(dispatchTimer, ^{
            [self timerDidReach];
        });
        dispatch_resume(dispatchTimer);

        _dispatchTimer = dispatchTimer;
        [self setNextTimer];
    }
}

- (void)reset {
    @synchronized (self) {
        if (_dispatchTimer) {
            dispatch_source_cancel(_dispatchTimer);
            _dispatchTimer = nil;
        }

        [_exponentialTimer reset];
    }
}

@end
