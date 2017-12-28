//
//  AVTestUtil.m
//  AVOS
//
//  Created by Qihe Bian on 1/27/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVTestUtil.h"
#import "AVTestBase.h"

@implementation AVTestUtil
+ (void)registerUserWithName:(NSString *)name {
    AVUser *user = [AVUser user];
    user.username = name;
    user.password = @"123456";
    NSError *error = nil;
    [user signUp:&error];
    if (!error) {
        [AVTestBase addDeleteObject:user];
    } else {
        NSLog(@"%s:%@", __PRETTY_FUNCTION__, error);
        [self _loginUserWithName:name];
    }
}

+ (void)loginUserWithName:(NSString *)name {
    NSError *error = nil;
    [AVUser logInWithUsername:name password:@"123456" error:&error];
    if (error) {
        NSLog(@"%s:%@", __PRETTY_FUNCTION__, error);
        [self _registerUserWithName:name];
    }
}

+ (void)_registerUserWithName:(NSString *)name {
    AVUser *user = [AVUser user];
    user.username = name;
    user.password = @"123456";
    NSError *error = nil;
    [user signUp:&error];
    if (!error) {
        [AVTestBase addDeleteObject:user];
    } else {
        NSLog(@"%s:%@", __PRETTY_FUNCTION__, error);
    }
}

+ (void)_loginUserWithName:(NSString *)name {
    NSError *error = nil;
    [AVUser logInWithUsername:name password:@"123456" error:&error];
    if (error) {
        //        [self registerUserWithName:name];
        NSLog(@"%s:%@", __PRETTY_FUNCTION__, error);
    }
}

+ (void)logoutUser {
    [AVUser logOut];
}
@end
