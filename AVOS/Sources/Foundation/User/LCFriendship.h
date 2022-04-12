//
//  LCFriendship.h
//  LeanCloudObjc
//
//  Created by pzheng on 2021/07/14.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LCObject.h"

@class LCQuery;

NS_ASSUME_NONNULL_BEGIN

/// The request of becoming friends.
@interface LCFriendshipRequest : LCObject

/// The name of this class.
+ (NSString *)className;

/// New a query for this class.
+ (LCQuery *)query;

@end

/// Friendship.
@interface LCFriendship : NSObject

/// The request for becoming friends.
/// @param userId The ID of the target user.
/// @param callback Result callback.
+ (void)requestWithUserId:(NSString *)userId
                 callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/// The request for becoming friends.
/// @param userId The ID of the target user.
/// @param attributes Custom key-value attributes.
/// @param callback Result callback.
+ (void)requestWithUserId:(NSString *)userId
               attributes:(NSDictionary * _Nullable)attributes
                 callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/// Accept a friendship request.
/// @param request See `LCFriendshipRequest`.
/// @param callback Result callback.
+ (void)acceptRequest:(LCFriendshipRequest *)request
             callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/// Accept a friendship request.
/// @param request See `LCFriendshipRequest`.
/// @param attributes Custom key-value attributes.
/// @param callback Result callback.
+ (void)acceptRequest:(LCFriendshipRequest *)request
           attributes:(NSDictionary * _Nullable)attributes
             callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/// Decline a friendship request.
/// @param request See `LCFriendshipRequest`.
/// @param callback Result callback.
+ (void)declineRequest:(LCFriendshipRequest *)request
              callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/// Block a friend by user id.
/// @param userId The `objectId` of the user.
/// @param callback Result callback.
+ (void)blockFriendWithUserId:(NSString *)userId
                     callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/// Unblock a friend by user id.
/// @param userId The `objectId` of the user.
/// @param callback Result callback.
+ (void)unblockFriendWithUserId:(NSString *)userId
                       callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

@end

NS_ASSUME_NONNULL_END
