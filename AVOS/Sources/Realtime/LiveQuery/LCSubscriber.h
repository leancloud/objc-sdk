//
//  LCSubscriber.h
//  LeanCloud
//
//  Created by Tang Tianyong on 16/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LCLiveQuery;

FOUNDATION_EXPORT NSString * const LCLiveQueryEventKey;
FOUNDATION_EXPORT NSNotificationName const LCLiveQueryEventNotification;

@interface LCSubscriber : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) NSString *identifier;

- (void)loginWithCallback:(void (^)(BOOL succeeded, NSError *error))callback;
- (void)addLiveQueryObjectToWeakTable:(LCLiveQuery *)liveQueryObject;
- (void)removeLiveQueryObjectFromWeakTable:(LCLiveQuery *)liveQueryObject;

@end
