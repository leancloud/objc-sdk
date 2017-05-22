//
//  AVSubscriber.h
//  AVOS
//
//  Created by Tang Tianyong on 16/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const    AVLiveQueryEventKey;
FOUNDATION_EXPORT NSNotificationName AVLiveQueryEventNotification;

@interface AVSubscriber : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;

+ (instancetype)sharedInstance;

- (void)start;

@end
