//
//  AVIMOnlineStatusPolicy.h
//  AVOS
//
//  Created by Tang Tianyong on 8/23/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 The online status.
 */
typedef NS_ENUM(NSInteger, AVIMOnlineStatus) {
    /// Client is online.
    AVIMOnlineStatusOn  = 1,
    /// Client is offline.
    AVIMOnlineStatusOff = 2
};

/**
 The policy for publishing and subscribing online status notification.
 */
@interface AVIMOnlineStatusPolicy : NSObject

/**
 Wether to allow current client publish online status to others.
 */
@property (nonatomic, assign) BOOL publishable;

/**
 Wether to allow current client subscribe online status from others.
 */
@property (nonatomic, assign) BOOL subscribable;

/**
 The TTL for keeping previous policy when client become offline, in seconds.

 If value <= 0, server will not keep the policy, when client offline, previous policy you specified will lost.
 In other words, the policy will only take effect during current connection.
 */
@property (nonatomic, assign) int32_t TTL;

- (instancetype)initWithPublishable:(BOOL)publishable
                       subscribable:(BOOL)subscribable
                                TTL:(int32_t)TTL;

@end
