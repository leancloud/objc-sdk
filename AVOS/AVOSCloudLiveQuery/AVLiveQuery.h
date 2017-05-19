//
//  AVLiveQuery.h
//  AVOS
//
//  Created by Tang Tianyong on 15/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVUser;
@class AVQuery;
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

@interface AVLiveQuery : NSObject

@property (nonatomic, weak, nullable) id<AVLiveQueryDelegate> delegate;

@property (nonatomic, strong, readonly) AVQuery *query;

- (instancetype)initWithQuery:(AVQuery *)query;

- (void)subscribeWithCallback:(void(^)(BOOL succeeded, NSError *error))callback;

- (void)unsubscribeWithCallback:(void(^)(BOOL succeeded, NSError *error))callback;

@end

NS_ASSUME_NONNULL_END
