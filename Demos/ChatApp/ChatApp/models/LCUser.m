//
//  LCUser.m
//  ChatApp
//
//  Created by Qihe Bian on 12/10/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCUser.h"
#import "LCCommon.h"

static NSMutableDictionary *_users = nil;

@interface LCUser ()
@property (nonatomic, strong)AVUser *internalUser;
@end

static LCUser *_currentUser = nil;

@implementation LCUser
@dynamic internalUser, nickname, photoUrl;

+ (void)load {
    [self registerSubclass];
    _users = [[NSMutableDictionary alloc] init];
}

+ (NSString *)className {
    return @"lc_user";
}

+ (NSString *)parseClassName {
    return [self className];
}

+ (instancetype)user {
    LCUser *user = [[self alloc] init];
    user.internalUser = [AVUser user];
    return user;
}

+ (instancetype)currentUser {
    if (!_currentUser && [AVUser currentUser]) {
        LCUser *user = [[self alloc] init];
        [user loadFromLocal];
        user.internalUser = [AVUser currentUser];
        _currentUser = user;
    }
    return _currentUser;
}
+ (void)logInWithUsernameInBackground:(NSString *)username
                             password:(NSString *)password
                                block:(LCUserResultBlock)block {
    [AVUser logInWithUsernameInBackground:username password:password block:^(AVUser *user, NSError *error) {
        if (user) {
            AVQuery *query = [AVQuery queryWithClassName:[self className]];
            [query whereKey:@"internalUser" equalTo:user];
            [query getFirstObjectInBackgroundWithBlock:^(AVObject *object, NSError *error) {
                if (object) {
                    LCUser *lcuser = (LCUser *)object;
//                    LCUser *lcuser = [[LCUser alloc] init];
//                    [lcuser objectFromDictionary:[object dictionaryForObject]];
                    lcuser.internalUser = user;
                    [lcuser saveToLocal];
                    _currentUser = lcuser;
                    [self addUserIfNeeded:lcuser];
                    block(lcuser, error);
                } else {
                    block(nil, error);
                }
            }];
        } else {
            block(nil, error);
        }
    }];
}

+ (void)clearLocal {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KEY_USERDATA];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)logOut {
    [AVUser logOut];
    [self clearLocal];
    _currentUser = nil;
}

+ (AVQuery *)query {
    AVQuery *query = [[AVQuery alloc] initWithClassName:[[self class] className]];
    return query;
}

//- (instancetype)init {
//    if ((self = [super init])) {
//        self.internalUser = [AVUser user];
//    }
//    return self;
//}

- (BOOL)isEqual:(id)object {
    LCUser *user = object;
    BOOL equal = [self.objectId isEqual:user.objectId];
    if (!equal) {
        NSLog(@"%@:%@", self.nickname, user.nickname);
    }
    return equal;
}

- (NSString *)className {
    return [[self class] className];
}

- (NSString *)username {
    return self.internalUser.username;
}

- (void)setUsername:(NSString *)username {
    self.internalUser.username = username;
    if (self.nickname.length == 0) {
        self.nickname = username;
    }
}

- (NSString *)password {
    return self.internalUser.password;
}

- (void)setPassword:(NSString *)password {
    self.internalUser.password = password;
}

- (NSString *)email {
    return self.internalUser.email;
}

- (void)setEmail:(NSString *)email {
    self.internalUser.email = email;
}

- (NSString *)mobilePhoneNumber {
    return self.internalUser.mobilePhoneNumber;
}

- (void)setMobilePhoneNumber:(NSString *)mobilePhoneNumber {
    self.internalUser.mobilePhoneNumber = mobilePhoneNumber;
}

- (BOOL)mobilePhoneVerified {
    return self.internalUser.mobilePhoneVerified;
}

- (void)saveToLocal {
    NSMutableDictionary *dict = [self dictionaryForObject];
    [dict removeObjectForKey:@"password"];
    [dict removeObjectForKey:@"internalUser"];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:dict];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:KEY_USERDATA];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadFromLocal {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:KEY_USERDATA];
    NSDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    [self objectFromDictionary:dict];
    [[self class] addUserIfNeeded:self];
}

- (void)saveInBackgroundWithBlock:(AVBooleanResultBlock)block {
    [super saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            [self saveToLocal];
            [[self class] addUserIfNeeded:self];
        }
        block(succeeded, error);
    }];
}

- (void)signUpInBackgroundWithBlock:(AVBooleanResultBlock)block {
    [self.internalUser signUpInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            [self saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
//                if (succeeded) {
//                    [self saveToLocal];
//                }
                
                block(succeeded, error);
                //                } else {
                //
                //                }
            }];
        } else {
            block(succeeded, error);
        }
    }];
}

+ (void)queryUsersSkip:(uint32_t)skip limit:(uint32_t)limit callback:(AVArrayResultBlock)callback {
    AVQuery * query = [self query];
    query.cachePolicy = kAVCachePolicyIgnoreCache;
    query.skip = skip;
    query.limit = limit;
    [query orderByAscending:@"nickname"];
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        for (LCUser *user in objects) {
            [self addUserIfNeeded:user];
        }
        callback(objects, error);
    }];
}

+ (void)queryUserWithId:(NSString *)userId callback:(AVObjectResultBlock)callback {
    AVQuery * query = [self query];
    query.cachePolicy = kAVCachePolicyIgnoreCache;
    [query getObjectInBackgroundWithId:userId block:^(AVObject *object, NSError *error) {
        if (object) {
            LCUser *user = (LCUser *)object;
            [self addUserIfNeeded:user];
            callback(object, error);
        } else {
            callback(nil, error);
        }
    }];
}

+ (void)queryUserWithIds:(NSArray *)userIds callback:(AVArrayResultBlock)callback {
    AVQuery * query = [self query];
    query.cachePolicy = kAVCachePolicyIgnoreCache;
    [query whereKey:@"objectId" containedIn:userIds];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (LCUser *user in objects) {
                [self addUserIfNeeded:user];
            }
            callback(objects, error);
        } else {
            callback(nil, error);
        }
    }];
}

+ (void)addUserIfNeeded:(LCUser *)user {
    NSString *userId = [user objectId];
    if (userId) {
        [_users setObject:user forKey:userId];
    }
}

+ (LCUser *)userById:(NSString *)userId {
    return [_users objectForKey:userId];
}

@end
