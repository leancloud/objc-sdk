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
#import "LCPaasClient_internal.h"
#import "LCObjectUtils.h"
#import "LCQuery.h"

@implementation LCFriendshipRequest

+ (NSString *)className {
    return @"_FriendshipRequest";
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
        callback(false, error);
        return;
    }
    LCUser *currentUser = [LCUser currentUser];
    if (!currentUser.sessionToken) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Please signin an user.", nil);
        callback(false, error);
        return;
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"user"] = [LCObjectUtils dictionaryFromObjectPointer:currentUser];
    parameters[@"friend"] = [LCObjectUtils dictionaryFromObjectPointer:[LCUser objectWithObjectId:userId]];
    if (attributes) {
        parameters[@"friendship"] = attributes;
    }
    [[LCPaasClient sharedInstance] postObject:@"users/friendshipRequests"
                               withParameters:parameters
                                        block:^(id  _Nullable object, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(!error, error);
        });
    }];
}

+ (void)acceptRequest:(LCFriendshipRequest *)request callback:(void (^)(BOOL, NSError * _Nullable))callback {
    [self acceptRequest:request attributes:nil callback:callback];
}

+ (void)acceptRequest:(LCFriendshipRequest *)request attributes:(NSDictionary *)attributes callback:(void (^)(BOOL, NSError * _Nullable))callback {
    if (!request.objectId) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Parameter `request` invalid.", nil);
        callback(false, error);
        return;
    }
    LCUser *currentUser = [LCUser currentUser];
    if (!currentUser.sessionToken) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Please signin an user.", nil);
        callback(false, error);
        return;
    }
    NSString *path = [NSString stringWithFormat:@"users/friendshipRequests/%@/accept", request.objectId];
    NSDictionary *parameters;
    if (attributes) {
        parameters = @{ @"friendship" : attributes };
    }
    [[LCPaasClient sharedInstance] putObject:path
                              withParameters:parameters
                                sessionToken:currentUser.sessionToken
                                       block:^(id  _Nullable object, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(!error, error);
        });
    }];
}

+ (void)declineRequest:(LCFriendshipRequest *)request callback:(void (^)(BOOL, NSError * _Nullable))callback {
    if (!request.objectId) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Parameter `request` invalid.", nil);
        callback(false, error);
        return;
    }
    LCUser *currentUser = [LCUser currentUser];
    if (!currentUser.sessionToken) {
        NSError *error = LCError(LCErrorInternalErrorCodeInconsistency, @"Please signin an user.", nil);
        callback(false, error);
        return;
    }
    NSString *path = [NSString stringWithFormat:@"users/friendshipRequests/%@/decline", request.objectId];
    [[LCPaasClient sharedInstance] putObject:path
                              withParameters:nil
                                sessionToken:currentUser.sessionToken
                                       block:^(id  _Nullable object, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(!error, error);
        });
    }];
}

@end
