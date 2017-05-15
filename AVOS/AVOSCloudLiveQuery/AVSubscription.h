//
//  AVSubscription.h
//  AVOS
//
//  Created by Tang Tianyong on 15/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVQuery.h"
#import "AVDynamicObject.h"

@class AVSubscription;

NS_ASSUME_NONNULL_BEGIN

@protocol AVSubscriptionDelegate <NSObject>

- (void)subscription:(AVSubscription *)subscription objectDidEnter:(id)object;
- (void)subscription:(AVSubscription *)subscription objectDidLeave:(id)object;

- (void)subscription:(AVSubscription *)subscription objectDidCreate:(id)object;
- (void)subscription:(AVSubscription *)subscription objectDidUpdate:(id)object;
- (void)subscription:(AVSubscription *)subscription objectDidDelete:(id)object;

- (void)subscription:(AVSubscription *)subscription userDidLogin:(AVUser *)user;

@end

@interface AVSubscriptionOptions : AVDynamicObject

@end

@interface AVSubscription : NSObject

@property (nonatomic, weak, nullable) id<AVSubscriptionDelegate> delegate;

@property (nonatomic, strong, readonly) AVQuery *query;
@property (nonatomic, strong, readonly, nullable) AVSubscriptionOptions *options;

- (instancetype)initWithQuery:(AVQuery *)query
                      options:(nullable AVSubscriptionOptions *)options;

@end

NS_ASSUME_NONNULL_END
