//
//  LCUser.h
//  ChatApp
//
//  Created by Qihe Bian on 12/10/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCCommon.h"

@class LCUser;
typedef void (^LCUserResultBlock)(LCUser *user, NSError *error);

@interface LCUser : AVObject
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, retain) NSString *email;
@property (nonatomic, strong) NSString *mobilePhoneNumber;
@property (nonatomic, readonly) BOOL mobilePhoneVerified;
@property (nonatomic, strong) NSString *nickname;
@property (nonatomic, strong) NSString *photoUrl;

+ (instancetype)user;
+ (instancetype)currentUser;
+ (void)logInWithUsernameInBackground:(NSString *)username
                             password:(NSString *)password
                                block:(LCUserResultBlock)block;
+ (void)logOut;
+ (AVQuery *)query;
+ (void)queryUsersSkip:(uint32_t)skip limit:(uint32_t)limit callback:(AVArrayResultBlock)callback;
+ (void)queryUserWithId:(NSString *)userId callback:(AVObjectResultBlock)callback;
+ (void)queryUserWithIds:(NSArray *)userIds callback:(AVArrayResultBlock)callback;
+ (LCUser *)userById:(NSString *)userId;

- (void)signUpInBackgroundWithBlock:(AVBooleanResultBlock)block;
@end
