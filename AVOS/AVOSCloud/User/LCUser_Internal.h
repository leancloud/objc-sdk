//
//  LCUser_Internal.h
//  paas
//
//  Created by Zhu Zeng on 3/14/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "LCUser.h"

#define AnonymousIdKey @"LeanCloud.AnonymousId"

@interface LCUser ()

@property (nonatomic, readwrite) BOOL isNew;
@property (nonatomic, readwrite) BOOL mobilePhoneVerified;

- (BOOL)isAuthDataExistInMemory;

+ (LCUser *)userOrSubclassUser;

+ (NSString *)userTag;

+ (NSString *)endPoint;
- (NSString *)internalClassName;
- (void)setNewFlag:(BOOL)isNew;

- (NSArray *)linkedServiceNames;

+ (void)configAndChangeCurrentUserWithUser:(LCUser *)user
                                    object:(id)object;

@end
