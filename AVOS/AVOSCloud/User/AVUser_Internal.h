//
//  AVUser_Internal.h
//  paas
//
//  Created by Zhu Zeng on 3/14/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "AVUser.h"

#define AnonymousIdKey @"LeanCloud.AnonymousId"

@interface AVUser ()

@property (nonatomic, readwrite, copy) NSString *facebookToken;
@property (nonatomic, readwrite, copy) NSString *twitterToken;
@property (nonatomic, readwrite, copy) NSString *sinaWeiboToken;
@property (nonatomic, readwrite, copy) NSString *qqWeiboToken;
@property (nonatomic, readwrite) BOOL isNew;
@property (nonatomic, readwrite) BOOL mobilePhoneVerified;

- (BOOL)isAuthDataExistInMemory;

+ (AVUser *)userOrSubclassUser;

+ (NSString *)userTag;

+ (NSString *)endPoint;
- (NSString *)internalClassName;
- (void)setNewFlag:(BOOL)isNew;

- (NSArray *)linkedServiceNames;

+ (void)configAndChangeCurrentUserWithUser:(AVUser *)user
                                    object:(id)object;

+ (void)loginOrSignUpWithAuthData:(NSDictionary *)authData
                             user:(AVUser *)user
                         platform:(NSString *)platform
                            queue:(dispatch_queue_t)queue
                            block:(AVUserResultBlock)block;

- (void)associateWithAuthData:(NSDictionary *)authData
                     platform:(NSString *)platform
                        queue:(dispatch_queue_t)queue
                        block:(AVUserResultBlock)block;

- (void)disassociateWithPlatform:(NSString *)platform
                           queue:(dispatch_queue_t)queue
                           block:(AVUserResultBlock)block;

@end
