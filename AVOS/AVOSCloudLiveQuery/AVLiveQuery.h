//
//  AVLiveQuery.h
//  AVOS
//
//  Created by Tang Tianyong on 15/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVQuery.h"
#import "AVDynamicObject.h"

@class AVLiveQuery;

NS_ASSUME_NONNULL_BEGIN

@protocol AVLiveQueryDelegate <NSObject>

- (void)liveQuery:(AVLiveQuery *)liveQuery objectDidEnter:(id)object;
- (void)liveQuery:(AVLiveQuery *)liveQuery objectDidLeave:(id)object;

- (void)liveQuery:(AVLiveQuery *)liveQuery objectDidCreate:(id)object;
- (void)liveQuery:(AVLiveQuery *)liveQuery objectDidUpdate:(id)object;
- (void)liveQuery:(AVLiveQuery *)liveQuery objectDidDelete:(id)object;

- (void)liveQuery:(AVLiveQuery *)liveQuery userDidLogin:(AVUser *)user;

@end

@interface AVLiveQueryOptions : AVDynamicObject

@end

@interface AVLiveQuery : NSObject

@property (nonatomic, weak, nullable) id<AVLiveQueryDelegate> delegate;

@property (nonatomic, strong, readonly) AVQuery *query;
@property (nonatomic, strong, readonly, nullable) AVLiveQueryOptions *options;

- (instancetype)initWithQuery:(AVQuery *)query
                      options:(nullable AVLiveQueryOptions *)options;

- (void)subscribeWithCallback:(AVBooleanResultBlock)callback;

- (void)unsubscribeWithCallback:(AVBooleanResultBlock)callback;

@end

NS_ASSUME_NONNULL_END
