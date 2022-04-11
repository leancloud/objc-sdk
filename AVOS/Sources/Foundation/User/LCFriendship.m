//
//  LCFriendship.m
//  LeanCloudObjc
//
//  Created by pzheng on 2021/07/14.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

#import "LCFriendship.h"
#import "LCUser_Internal.h"
#import "LCErrorUtils.h"
#import "LCPaasClient.h"
#import "LCObjectUtils.h"
#import "LCQuery.h"

@implementation LCFriendshipRequest

+ (NSString *)className {
    return @"_FriendshipRequest";
}

+ (NSString *)parseClassName {
    return [self className];
}

+ (LCQuery *)query {
    LCQuery *query = [LCQuery queryWithClassName:[self className]];
    [query whereKey:@"friend" equalTo:[LCUser currentUser]];
    [query whereKey:@"status" equalTo:@"pending"];
    [query includeKey:@"user"];
    return query;
}

@end

@implementation LCFriendship

+ (void)requestWithUserId:(NSString *)userId callback:(void (^)(BOOL, NSError * _Nullable))callback {
    [self requestWithUserId:userId attributes:nil callback:callback];
}

+ (void)requestWithUserId:(NSString *)userId attributes:(NSDictionary *)attributes callback:(void (^)(BOOL, NSError * _Nullable))callback {
    if (!userId) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Parameter `userId` invalid.", nil);
        [LCUtils callBooleanResultBlock:callback error:error];
        return;
    }
    LCUser *currentUser = [LCUser currentUser];
    if (!currentUser.sessionToken) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Please signin an user.", nil);
        [LCUtils callBooleanResultBlock:callback error:error];
        return;
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"user"] = [LCObjectUtils dictionaryFromObjectPointer:currentUser];
    parameters[@"friend"] = [LCObjectUtils dictionaryFromObjectPointer:[LCUser objectWithObjectId:userId]];
    if (attributes && attributes.count > 0) {
        parameters[@"friendship"] = attributes;
    }
    [[LCPaasClient sharedInstance] postObject:@"users/friendshipRequests"
                               withParameters:parameters
                                        block:^(id  _Nullable object, NSError * _Nullable error) {
        [LCUtils callBooleanResultBlock:callback error:error];
    }];
}

+ (void)acceptRequest:(LCFriendshipRequest *)request callback:(void (^)(BOOL, NSError * _Nullable))callback {
    [self acceptRequest:request attributes:nil callback:callback];
}

+ (void)acceptRequest:(LCFriendshipRequest *)request attributes:(NSDictionary *)attributes callback:(void (^)(BOOL, NSError * _Nullable))callback {
    [self acceptOrDeclineRequest:request operation:@"accept" attributes:attributes callback:callback];
}

+ (void)declineRequest:(LCFriendshipRequest *)request callback:(void (^)(BOOL, NSError * _Nullable))callback {
    [self acceptOrDeclineRequest:request operation:@"decline" attributes:nil callback:callback];
}

+ (void)acceptOrDeclineRequest:(LCFriendshipRequest *)request
                     operation:(NSString *)operation
                    attributes:(NSDictionary *)attributes
                      callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    if (!request.objectId) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Parameter `request` invalid.", nil);
        [LCUtils callBooleanResultBlock:callback error:error];
        return;
    }
    LCUser *currentUser = [LCUser currentUser];
    if (!currentUser.sessionToken) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Please signin an user.", nil);
        [LCUtils callBooleanResultBlock:callback error:error];
        return;
    }
    NSString *path = [NSString stringWithFormat:@"users/friendshipRequests/%@/%@", request.objectId, operation];
    NSDictionary *parameters;
    if (attributes && attributes.count > 0) {
        parameters = @{ @"friendship" : attributes };
    }
    [[LCPaasClient sharedInstance] putObject:path
                              withParameters:parameters
                                sessionToken:currentUser.sessionToken
                                       block:^(id  _Nullable object, NSError * _Nullable error) {
        [LCUtils callBooleanResultBlock:callback error:error];
    }];
}

+ (void)blockFriendWithUserId:(NSString *)userId callback:(void (^)(BOOL, NSError * _Nullable))callback {
    [self blockOrUnblockFriendWithUserId:userId isBlock:true callback:callback];
}

+ (void)unblockFriendWithUserId:(NSString *)userId callback:(void (^)(BOOL, NSError * _Nullable))callback {
    [self blockOrUnblockFriendWithUserId:userId isBlock:false callback:callback];
}

+ (void)blockOrUnblockFriendWithUserId:(NSString *)userId
                               isBlock:(BOOL)isBlock
                              callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    if (!userId) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Parameter `userId` invalid.", nil);
        [LCUtils callBooleanResultBlock:callback error:error];
        return;
    }
    LCUser *currentUser = [LCUser currentUser];
    if (!currentUser.sessionToken) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Please signin an user.", nil);
        [LCUtils callBooleanResultBlock:callback error:error];
        return;
    }
    NSString *path = [NSString stringWithFormat:@"users/self/friendBlocklist/%@", userId];
    if (isBlock) {
        [[LCPaasClient sharedInstance] postObject:path
                                   withParameters:nil
                                            block:^(id  _Nullable object, NSError * _Nullable error) {
            [LCUtils callBooleanResultBlock:callback error:error];
        }];
    } else {
        [[LCPaasClient sharedInstance] deleteObject:path
                                     withParameters:nil
                                              block:^(id  _Nullable object, NSError * _Nullable error) {
            [LCUtils callBooleanResultBlock:callback error:error];
        }];
    }
}

@end
