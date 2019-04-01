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

@end
