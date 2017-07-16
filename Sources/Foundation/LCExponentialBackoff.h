//
//  LCExponentialBackoff.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 16/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LCExponentialBackoff;

FOUNDATION_EXPORT const double LCExponentialBackoffDefaultJitter;

@protocol LCExponentialBackoffDelegate <NSObject>

- (void)exponentialBackoffDidReach:(LCExponentialBackoff *)exponentialBackoff;

@end

@interface LCExponentialBackoff : NSObject

@property (nonatomic, weak) id<LCExponentialBackoffDelegate> delegate;

- (instancetype)initWithInitialTime:(NSTimeInterval)initialTime
                        maximumTime:(NSTimeInterval)maximumTime
                             jitter:(double)jitter;

- (void)resume;
- (void)reset;

@end
