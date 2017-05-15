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

NS_ASSUME_NONNULL_BEGIN

@interface AVSubscriptionOptions : AVDynamicObject

@end

@interface AVSubscription : NSObject

@property (nonatomic, strong, readonly) AVQuery *query;
@property (nonatomic, strong, readonly, nullable) AVSubscriptionOptions *options;

- (instancetype)initWithQuery:(AVQuery *)query
                      options:(nullable AVSubscriptionOptions *)options;

@end

NS_ASSUME_NONNULL_END
