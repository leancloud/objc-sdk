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

/**
 Protocol of delegate that receives live query notifications.
 */
@protocol AVLiveQueryDelegate <NSObject>

@optional

/**
 Called when an object created and it matches the query.

 @param liveQuery The live query object.
 @param object    The object that matches live query.
 */
- (void)liveQuery:(AVLiveQuery *)liveQuery objectDidCreate:(id)object;

/**
 Called when an object updated and it matches the query.

 @param liveQuery   The live query object.
 @param object      The object that matches live query.
 @param updatedKeys The updated keys.
 */
- (void)liveQuery:(AVLiveQuery *)liveQuery objectDidUpdate:(id)object updatedKeys:(NSArray<NSString *> *)updatedKeys;

/**
 Called when an object deleted and it matches the query.

 @param liveQuery The live query object.
 @param object    The object that matches live query.
 */
- (void)liveQuery:(AVLiveQuery *)liveQuery objectDidDelete:(id)object;

/**
 Called when an object matches query after updated.

 @param liveQuery The live query object.
 @param object    The object that matches live query.
 */
- (void)liveQuery:(AVLiveQuery *)liveQuery objectDidEnter:(id)object updatedKeys:(NSArray<NSString *> *)updatedKeys;

/**
 Called when an object mismatches query after updated.

 @param liveQuery The live query object.
 @param object    The object that matches live query.
 */
- (void)liveQuery:(AVLiveQuery *)liveQuery objectDidLeave:(id)object updatedKeys:(NSArray<NSString *> *)updatedKeys;

/**
 Called when an user did login and who matches the query.

 @param liveQuery The live query object.
 @param user      The user who did login.
 */
- (void)liveQuery:(AVLiveQuery *)liveQuery userDidLogin:(AVUser *)user;

@end

/**
 A type that defines an object which can observe various kinds of
 change events of objects that a query matches.
 */
@interface AVLiveQuery : NSObject

/**
 The delegate which receive change event of objects which the query matches.
 */
@property (nonatomic, weak, nullable) id<AVLiveQueryDelegate> delegate;

/**
 The query which matches objects that you want to observe.
 */
@property (nonatomic, strong, readonly) AVQuery *query;

/**
 Initialize live query with a AVQuery object.

 @param query The query which matches objects that you want to observe.
 */
- (instancetype)initWithQuery:(AVQuery *)query;

/**
 Subscribe change notifications for query.

 @param callback The callback block of subscription.
 */
- (void)subscribeWithCallback:(void(^)(BOOL succeeded, NSError *error))callback;

/**
 Unsubscribe change notifications for query.

 @param callback The callback block of unsubscription.
 */
- (void)unsubscribeWithCallback:(void(^)(BOOL succeeded, NSError *error))callback;

@end

NS_ASSUME_NONNULL_END
