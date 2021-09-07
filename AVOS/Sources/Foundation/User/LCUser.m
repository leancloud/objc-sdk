// LCUser.h
// Copyright 2013 LeanCloud, Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import "LCUser_Internal.h"
#import "LCObject_Internal.h"
#import "LCPaasClient.h"
#import "LCUtils_Internal.h"
#import "LCQuery.h"
#import "LCPersistenceUtils.h"
#import "LCObjectUtils.h"
#import "LCPaasClient.h"
#import "LCErrorUtils.h"
#import "LCFriendQuery.h"
#import "LCRelation_Internal.h"

LeanCloudSocialPlatform const LeanCloudSocialPlatformWeiBo  = @"weibo";
LeanCloudSocialPlatform const LeanCloudSocialPlatformQQ     = @"qq";
LeanCloudSocialPlatform const LeanCloudSocialPlatformWeiXin = @"weixin";

@implementation LCUserShortMessageRequestOptions

@end

@implementation LCUserAuthDataLoginOption

@end

@implementation  LCUser

static BOOL enableAutomatic = NO;

@dynamic sessionToken;
@dynamic isNew;
@dynamic username;
@dynamic password;
@dynamic email;
@dynamic mobilePhoneVerified;
@dynamic mobilePhoneNumber;

+ (void)load {
    [self registerSubclass];
}

+ (NSString *)parseClassName {
    return [LCUser userTag];
}

+ (void)changeCurrentUser:(LCUser *)newUser save:(BOOL)save
{
    if (newUser && save) {
        NSMutableDictionary * json = [newUser userDictionaryForCache];
        [json removeObjectForKey:passwordTag];
        [LCPersistenceUtils saveJSON:json toPath:[LCPersistenceUtils currentUserArchivePath]];
        [LCPersistenceUtils saveJSON:@{@"class": NSStringFromClass([newUser class])}
                              toPath:[LCPersistenceUtils currentUserClassArchivePath]];
    } else if (save) {
        [LCPersistenceUtils removeFile:[LCPersistenceUtils currentUserArchivePath]];
        [LCPersistenceUtils removeFile:[LCPersistenceUtils currentUserClassArchivePath]];
    }
    [LCPaasClient sharedInstance].currentUser = newUser;
}

+ (instancetype)currentUser
{
    LCUser *user = [LCPaasClient sharedInstance].currentUser;
    if (user) {
        return user;
    } else if ([LCPersistenceUtils fileExist:[LCPersistenceUtils currentUserArchivePath]]) {
        NSMutableDictionary *userDict = [NSMutableDictionary dictionaryWithDictionary:[LCPersistenceUtils getJSONFromPath:[LCPersistenceUtils currentUserArchivePath]]];
        if (userDict) {
            if ([LCPersistenceUtils fileExist:[LCPersistenceUtils currentUserClassArchivePath]]) {
                NSDictionary *classDict = [LCPersistenceUtils getJSONFromPath:[LCPersistenceUtils currentUserClassArchivePath]];
                user = [NSClassFromString(classDict[@"class"]) user];
            } else {
                user = [self userOrSubclassUser];
            }
            
            [LCObjectUtils copyDictionary:userDict toObject:user];
            [LCPaasClient sharedInstance].currentUser = user;
            return user;
        }
    }
    if (!enableAutomatic) {
        return user;
    }
    
    LCUser *newUser = [self userOrSubclassUser];
    [[self class] changeCurrentUser:newUser save:NO];
    return newUser;
}

- (void)isAuthenticatedWithSessionToken:(NSString *)sessionToken callback:(LCBooleanResultBlock)callback {
    if (sessionToken == nil) {
        [LCUtils callBooleanResultBlock:callback error:LCErrorInternalServer(@"sessionToken is nil")];
        return;
    }
    
    [[LCPaasClient sharedInstance] getObject:[NSString stringWithFormat:@"%@/%@", [[self class] endPoint], @"me"] withParameters:@{@"session_token": sessionToken} block:^(id object, NSError *error) {
        [LCUtils callBooleanResultBlock:callback error:error];
    }];
}

- (NSArray<LCRole *> *)getRoles:(NSError * _Nullable __autoreleasing *)error {
    LCQuery *query = [LCRelation reverseQuery:@"_Role" relationKey:@"users" childObject:self];
    return [query findObjects:error];
}

- (NSArray<LCRole *> *)getRolesAndThrowsWithError:(NSError * _Nullable __autoreleasing *)error {
    return [self getRoles:error];
}

- (void)getRolesInBackgroundWithBlock:(void (^)(NSArray<LCRole *> * _Nullable, NSError * _Nullable))block {
    [LCUtils asynchronizeTask:^{
        NSError *error = nil;
        NSArray<LCRole *> *result = [self getRoles:&error];
        [LCUtils callArrayResultBlock:block array:result error:error];
    }];
}

+ (instancetype)user
{
    LCUser *u = [[[self class] alloc] initWithClassName:[[self class] userTag]];
    return u;
}

+ (void)enableAutomaticUser
{
    enableAutomatic = YES;
}

-(NSError *)preSave
{
    if ([self isAuthDataExistInMemory])
    {
        return nil;
    }
    return LCError(kLCErrorUserCannotBeAlteredWithoutSession, nil, nil);
}

-(void)postSave
{
    [super postSave];
    [[self class] changeCurrentUser:self save:YES];
}

- (void)postDelete {
    [super postDelete];
    if (self == [LCUser currentUser]) {
        [LCUser logOut];
    }
}

- (BOOL)signUp:(NSError *__autoreleasing *)error
{
    return [self saveWithOption:nil eventually:NO verifyBefore:NO error:error];
}

- (BOOL)signUpAndThrowsWithError:(NSError * _Nullable __autoreleasing *)error {
    return [self signUp:error];
}

- (void)signUpInBackgroundWithBlock:(LCBooleanResultBlock)block
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        [self signUp:&error];
        [LCUtils callBooleanResultBlock:block error:error];
    });
}

/*
 * If an user is not login, update that user will failed.
 * So, we should not include update requests when sign up user.
 */
- (BOOL)shouldIncludeUpdateRequests {
    return self.objectId != nil;
}

-(NSMutableDictionary *)userDictionary
{
    NSString *username = self.username;
    NSString *password = self.password;
    NSString *email = self.email;
    NSString *mobilePhoneNumber = self.mobilePhoneNumber;
    
    NSMutableDictionary * parameters = [[NSMutableDictionary alloc] init];
    
    if (username) {
        [parameters setObject:username forKey:usernameTag];
    }
    if (password) {
        [parameters setObject:password forKey:passwordTag];
    }
    if (email) {
        [parameters setObject:email forKey:emailTag];
    }
    if (mobilePhoneNumber) {
        [parameters setObject:mobilePhoneNumber forKey:mobilePhoneNumberTag];
    }
    
    return parameters;
}

-(NSMutableDictionary *)userDictionaryForCache
{
    NSMutableDictionary * data = [self postData];
    return data;
}

-(NSMutableDictionary *)initialBodyData {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    NSMutableDictionary *dict = [[self._requestManager jsonForCloud] firstObject];
    
    if (dict) {
        [body addEntriesFromDictionary:dict];
    }
    
    return body;
}

+(void)requestEmailVerify:(NSString*)email withBlock:(LCBooleanResultBlock)block{
    NSParameterAssert(email);
    
    [[LCPaasClient sharedInstance] postObject:@"requestEmailVerify" withParameters:@{@"email":email} block:^(id object, NSError *error) {
        [LCUtils callBooleanResultBlock:block error:error];
    }];
}

- (void)updatePassword:(NSString *)oldPassword newPassword:(NSString *)newPassword block:(LCIdResultBlock)block {
    if (self.isAuthDataExistInMemory && oldPassword && newPassword) {
        NSString *path = [NSString stringWithFormat:@"users/%@/updatePassword", self.objectId];
        NSDictionary *params = @{@"old_password":oldPassword,
                                 @"new_password":newPassword};
        [[LCPaasClient sharedInstance] putObject:path withParameters:params sessionToken:self.sessionToken block:^(id object, NSError *error) {
            if (!error) {
                // {"sessionToken":"kns1w56ch9b3mn308i13bkln6",
                //  "updatedAt":"2015-10-20T03:12:38.203Z",
                //  "objectId":"5625b11b60b2fc79c2fb8c40"}
                [LCObjectUtils copyDictionary:object toObject:self];
                if (self == [LCUser currentUser]) {
                    [LCUser changeCurrentUser:self save:YES];
                }
            }
            [LCUtils callIdResultBlock:block object:self error:error];
        }];
    } else {
        NSError *error = nil;
        if (!self.isAuthDataExistInMemory) {
            error = LCError(kLCErrorUserCannotBeAlteredWithoutSession, nil, nil);
        }
        
        if (!(oldPassword && newPassword)) {
            error = LCError(kLCErrorUserPasswordMissing, nil, nil);
        }
        [LCUtils callIdResultBlock:block object:nil error:error];
    }
}

- (void)refreshSessionTokenWithBlock:(LCBooleanResultBlock)block {
    NSString *objectId = self.objectId;
    
    if (!objectId) {
        NSError *error = LCError(kLCErrorUserNotFound, @"User ID not found.", nil);
        [LCUtils callBooleanResultBlock:block error:error];
        return;
    }
    
    NSString *sessionToken = self.sessionToken;
    
    if (!sessionToken) {
        NSError *error = LCError(kLCErrorUserCannotBeAlteredWithoutSession, @"User session token not found.", nil);
        [LCUtils callBooleanResultBlock:block error:error];
        return;
    }
    
    LCPaasClient *HTTPClient = [LCPaasClient sharedInstance];
    
    NSDictionary *headers = @{
        LCHeaderFieldNameSession: sessionToken
    };
    NSString *path = [[[[NSURL URLWithString:@"users"]
                        URLByAppendingPathComponent:objectId]
                       URLByAppendingPathComponent:@"refreshSessionToken"]
                      relativePath];
    NSMutableURLRequest *request = [HTTPClient requestWithPath:path
                                                        method:@"PUT"
                                                       headers:headers
                                                    parameters:nil];
    
    [HTTPClient performRequest:request
                       success:^(NSHTTPURLResponse *response, id result) {
        self.sessionToken = result[@"sessionToken"];
        self.updatedAt = [LCDate dateFromValue:result[@"updatedAt"]];
        if ([self isEqual:[LCUser currentUser]]) {
            [LCUser changeCurrentUser:self save:YES];
        }
        [LCUtils callBooleanResultBlock:block error:nil];
    }
                       failure:^(NSHTTPURLResponse *response, id responseObject, NSError *error) {
        [LCUtils callBooleanResultBlock:block error:error];
    }];
}

// MARK: - login with username & password

+ (instancetype)logInWithUsername:(NSString *)username
                         password:(NSString *)password
                            error:(NSError **)error
{
    __block LCUser * resultUser = nil;
    [[self class] logInWithUsername:username email:nil password:password block:^(LCUser *user, NSError *error) {
        resultUser = user;
    } waitUntilDone:YES error:error];
    return resultUser;
}

+ (void)logInWithUsernameInBackground:(NSString *)username
                             password:(NSString *)password
                                block:(LCUserResultBlock)block
{
    [[self class] logInWithUsername:username email:nil password:password block:^(LCUser *user, NSError * error) {
        [LCUtils callUserResultBlock:block user:user error:error];
    }
                      waitUntilDone:NO error:nil];
    
}

+ (void)loginWithEmail:(NSString *)email password:(NSString *)password block:(LCUserResultBlock)block {
    [[self class] logInWithUsername:nil email:email password:password block:^(LCUser * _Nullable user, NSError * _Nullable error) {
        [LCUtils callUserResultBlock:block user:user error:error];
    } waitUntilDone:false error:nil];
}

+ (BOOL)logInWithUsername:(NSString *)username
                    email:(NSString *)email
                 password:(NSString *)password
                    block:(LCUserResultBlock)block
            waitUntilDone:(BOOL)wait
                    error:(NSError **)theError {
    
    BOOL __block theResult = NO;
    BOOL __block hasCalledBack = NO;
    NSError __block *blockError = nil;
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (username) { parameters[usernameTag] = username; }
    if (email) { parameters[emailTag] = email; }
    if (password) { parameters[passwordTag] = password; }
    [[LCPaasClient sharedInstance] postObject:@"login" withParameters:parameters block:^(id object, NSError *error) {
        LCUser * user = nil;
        if (error == nil)
        {
            user = [self userOrSubclassUser];
            user.username = username;
            user.password = password;
            
            [self configAndChangeCurrentUserWithUser:user
                                              object:object];
        }
        
        if (wait) {
            blockError = error;
            theResult = (error == nil);
            hasCalledBack = YES;
        }
        [LCUtils callUserResultBlock:block user:user error:error];
    }];
    
    // wait until called back if necessary
    if (wait) {
        [LCUtils warnMainThreadIfNecessary];
        LC_WAIT_TIL_TRUE(hasCalledBack, 0.1);
    };
    
    if (theError != NULL) *theError = blockError;
    return theResult;
}

// MARK: - login with mobile

+ (instancetype)logInWithMobilePhoneNumber:(NSString *)phoneNumber
                                  password:(NSString *)password
                                     error:(NSError **)error
{
    __block LCUser * resultUser = nil;
    [self logInWithMobilePhoneNumber:phoneNumber password:password block:^(LCUser *user, NSError *error) {
        resultUser = user;
    } waitUntilDone:YES error:error];
    return resultUser;
}

+ (void)logInWithMobilePhoneNumberInBackground:(NSString *)phoneNumber
                                      password:(NSString *)password
                                         block:(LCUserResultBlock)block
{
    [self logInWithMobilePhoneNumber:phoneNumber password:password block:^(LCUser *user, NSError * error) {
        [LCUtils callUserResultBlock:block user:user error:error];
    }
                       waitUntilDone:NO error:nil];
    
}
+ (BOOL)logInWithMobilePhoneNumber:(NSString *)phoneNumber
                          password:(NSString *)password
                             block:(LCUserResultBlock)block
                     waitUntilDone:(BOOL)wait
                             error:(NSError **)theError {
    
    BOOL __block theResult = NO;
    BOOL __block hasCalledBack = NO;
    NSError __block *blockError = nil;
    
    NSDictionary * parameters = @{mobilePhoneNumberTag: phoneNumber, passwordTag:password};
    [[LCPaasClient sharedInstance] postObject:@"login" withParameters:parameters block:^(id object, NSError *error) {
        LCUser * user = nil;
        if (error == nil)
        {
            user = [self userOrSubclassUser];
            
            [self configAndChangeCurrentUserWithUser:user
                                              object:object];
        }
        
        if (wait) {
            blockError = error;
            theResult = (error == nil);
            hasCalledBack = YES;
        }
        [LCUtils callUserResultBlock:block user:user error:error];
    }];
    
    // wait until called back if necessary
    if (wait) {
        [LCUtils warnMainThreadIfNecessary];
        LC_WAIT_TIL_TRUE(hasCalledBack, 0.1);
    };
    
    if (theError != NULL) *theError = blockError;
    return theResult;
}

// MARK: - login with token

+ (void)becomeWithSessionTokenInBackground:(NSString *)sessionToken block:(LCUserResultBlock)block {
    [self internalBecomeWithSessionTokenInBackground:sessionToken block:^(LCUser *user, NSError *error) {
        [LCUtils callUserResultBlock:block user:user error:error];
    }];
}

+ (void)internalBecomeWithSessionTokenInBackground:(NSString *)sessionToken block:(LCUserResultBlock)block {
    if (sessionToken == nil) {
        if (block) {
            block(nil, LCErrorInternalServer(@"sessionToken is nil"));
        }
        return;
    }
    [[LCPaasClient sharedInstance] getObject:[NSString stringWithFormat:@"%@/%@", [self endPoint], @"me"] withParameters:@{@"session_token": sessionToken} block:^(id object, NSError *error) {
        LCUser *user;
        if (!error) {
            user = [self userOrSubclassUser];
            [user objectFromDictionary:object];
            [[self class] changeCurrentUser:user save:YES];
        }
        if (block) {
            block(user, error);
        }
    }];
}

+ (instancetype)becomeWithSessionToken:(NSString *)sessionToken error:(NSError * __autoreleasing *)error {
    __block Boolean hasCallback = NO;
    __block LCUser *user;
    [self internalBecomeWithSessionTokenInBackground:sessionToken block:^(LCUser *theUser, NSError *theError) {
        user = theUser;
        if (error) {
            *error = theError;
        }
        hasCallback = YES;
    }];
    LC_WAIT_TIL_TRUE(hasCallback, 0.1);
    return user;
}

+ (void)requestLoginSmsCode:(NSString *)phoneNumber withBlock:(LCBooleanResultBlock)block {
    [self requestLoginCodeForPhoneNumber:phoneNumber options:nil callback:block];
}

+ (void)requestLoginCodeForPhoneNumber:(NSString *)phoneNumber
                               options:(LCUserShortMessageRequestOptions *)options
                              callback:(LCBooleanResultBlock)callback
{
    NSParameterAssert(phoneNumber);
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    parameters[@"mobilePhoneNumber"] = phoneNumber;
    parameters[@"validate_token"] = options.validationToken;
    
    [[LCPaasClient sharedInstance] postObject:@"requestLoginSmsCode" withParameters:parameters block:^(id object, NSError *error) {
        [LCUtils callBooleanResultBlock:callback error:error];
    }];
}

// MARK: - login with mobile

+ (instancetype)logInWithMobilePhoneNumber:(NSString *)phoneNumber
                                   smsCode:(NSString *)code
                                     error:(NSError **)error
{
    __block LCUser * resultUser = nil;
    [self logInWithMobilePhoneNumber:phoneNumber smsCode:code block:^(LCUser *user, NSError *error) {
        resultUser = user;
    } waitUntilDone:YES error:error];
    return resultUser;
}

+ (void)logInWithMobilePhoneNumberInBackground:(NSString *)phoneNumber
                                       smsCode:(NSString *)code
                                         block:(LCUserResultBlock)block
{
    [self logInWithMobilePhoneNumber:phoneNumber smsCode:code block:^(LCUser *user, NSError * error) {
        [LCUtils callUserResultBlock:block user:user error:error];
    }
                       waitUntilDone:NO error:nil];
    
}
+ (BOOL)logInWithMobilePhoneNumber:(NSString *)phoneNumber
                           smsCode:(NSString *)smsCode
                             block:(LCUserResultBlock)block
                     waitUntilDone:(BOOL)wait
                             error:(NSError **)theError {
    
    BOOL __block theResult = NO;
    BOOL __block hasCalledBack = NO;
    NSError __block *blockError = nil;
    
    NSDictionary * parameters = @{mobilePhoneNumberTag: phoneNumber, smsCodeTag:smsCode};
    [[LCPaasClient sharedInstance] postObject:@"login" withParameters:parameters block:^(id object, NSError *error) {
        LCUser * user = nil;
        if (error == nil)
        {
            user = [self userOrSubclassUser];
            user.mobilePhoneVerified = YES;
            
            [self configAndChangeCurrentUserWithUser:user
                                              object:object];
        }
        
        if (wait) {
            blockError = error;
            theResult = (error == nil);
            hasCalledBack = YES;
        }
        [LCUtils callUserResultBlock:block user:user error:error];
    }];
    
    // wait until called back if necessary
    if (wait) {
        [LCUtils warnMainThreadIfNecessary];
        LC_WAIT_TIL_TRUE(hasCalledBack, 0.1);
    };
    
    if (theError != NULL) *theError = blockError;
    return theResult;
}

+ (instancetype)signUpOrLoginWithMobilePhoneNumber:(NSString *)phoneNumber
                                           smsCode:(NSString *)code {
    return [self signUpOrLoginWithMobilePhoneNumber:phoneNumber smsCode:code error:nil];
}

+ (instancetype)signUpOrLoginWithMobilePhoneNumber:(NSString *)phoneNumber
                                           smsCode:(NSString *)code
                                             error:(NSError **)error {
    __block LCUser * resultUser = nil;
    [self signUpOrLoginWithMobilePhoneNumber:phoneNumber smsCode:code block:^(LCUser *user, NSError *error) {
        resultUser = user;
    } waitUntilDone:YES error:error];
    return resultUser;
}

+ (void)signUpOrLoginWithMobilePhoneNumberInBackground:(NSString *)phoneNumber
                                               smsCode:(NSString *)code {
    [self signUpOrLoginWithMobilePhoneNumber:phoneNumber smsCode:code block:nil waitUntilDone:YES error:nil];
}

+ (void)signUpOrLoginWithMobilePhoneNumberInBackground:(NSString *)phoneNumber
                                               smsCode:(NSString *)code
                                                 block:(LCUserResultBlock)block {
    [self signUpOrLoginWithMobilePhoneNumber:phoneNumber smsCode:code block:^(LCUser *user, NSError *error) {
        [LCUtils callUserResultBlock:block user:user error:error];
    } waitUntilDone:NO error:NULL];
}

+ (BOOL)signUpOrLoginWithMobilePhoneNumber:(NSString *)phoneNumber
                                   smsCode:(NSString *)smsCode
                                     block:(LCUserResultBlock)block
                             waitUntilDone:(BOOL)wait
                                     error:(NSError **)theError {
    
    BOOL __block theResult = NO;
    BOOL __block hasCalledBack = NO;
    NSError __block *blockError = nil;
    
    NSDictionary * parameters = @{mobilePhoneNumberTag: phoneNumber, smsCodeTag:smsCode};
    [[LCPaasClient sharedInstance] postObject:@"usersByMobilePhone" withParameters:parameters block:^(id object, NSError *error) {
        LCUser * user = nil;
        if (error == nil)
        {
            user = [self userOrSubclassUser];
            
            [self configAndChangeCurrentUserWithUser:user
                                              object:object];
        }
        
        if (wait) {
            blockError = error;
            theResult = (error == nil);
            hasCalledBack = YES;
        }
        [LCUtils callUserResultBlock:block user:user error:error];
    }];
    
    // wait until called back if necessary
    if (wait) {
        [LCUtils warnMainThreadIfNecessary];
        LC_WAIT_TIL_TRUE(hasCalledBack, 0.1);
    };
    
    if (theError != NULL) *theError = blockError;
    return theResult;
}

+ (void)signUpOrLoginWithMobilePhoneNumberInBackground:(NSString *)phoneNumber
                                               smsCode:(NSString *)smsCode
                                              password:(NSString *)password
                                                 block:(LCUserResultBlock)block
{    
    NSDictionary *parameters = @{ mobilePhoneNumberTag: phoneNumber, smsCodeTag: smsCode, passwordTag: password };
    [[LCPaasClient sharedInstance] postObject:@"usersByMobilePhone" withParameters:parameters block:^(id object, NSError *error) {
        if (error) {
            [LCUtils callUserResultBlock:block user:nil error:error];
            return;
        }
        LCUser *user = [self userOrSubclassUser];
        [self configAndChangeCurrentUserWithUser:user object:object];
        [LCUtils callUserResultBlock:block user:user error:nil];
    }];
}

// MARK: Log out

+ (void)logOut {
    [self logOutWithClearingAnonymousId:true];
}

+ (void)logOutWithClearingAnonymousId:(BOOL)clearingAnonymousId {
    if (clearingAnonymousId) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:AnonymousIdKey];
    }
    [self changeCurrentUser:nil save:true];
}

// MARK: - password reset

+ (BOOL)requestPasswordResetForEmail:(NSString *)email
                               error:(NSError **)resultError
{
    BOOL wait = YES;
    BOOL __block theResult = NO;
    BOOL __block hasCalledBack = NO;
    NSError * __block  theError = nil;
    
    [self internalRequestPasswordResetForEmailInBackground:email block:^(BOOL succeeded, NSError *callBackError) {
        if (wait) {
            hasCalledBack = YES;
            theResult = succeeded;
            theError = callBackError;
        }
    }];
    
    // wait until called back if necessary
    if (wait) {
        [LCUtils warnMainThreadIfNecessary];
        LC_WAIT_TIL_TRUE(hasCalledBack, 0.1);
    };
    
    if (resultError != NULL) *resultError = theError;
    return theResult;
    
}

+ (void)requestPasswordResetForEmailInBackground:(NSString *)email
                                           block:(LCBooleanResultBlock)block {
    [self internalRequestPasswordResetForEmailInBackground:email block:^(BOOL succeeded, NSError *error) {
        [LCUtils callBooleanResultBlock:block error:error];
    }];
}

+ (void)internalRequestPasswordResetForEmailInBackground:(NSString *)email
                                                   block:(LCBooleanResultBlock)block
{
    NSDictionary * parameters = @{emailTag: email};
    [[LCPaasClient sharedInstance] postObject:@"requestPasswordReset" withParameters:parameters block:^(id object, NSError *error) {
        if (block) {
            block(error == nil, error);
        }
    }];
}

+ (void)requestPasswordResetWithPhoneNumber:(NSString *)phoneNumber block:(LCBooleanResultBlock)block {
    [self requestPasswordResetCodeForPhoneNumber:phoneNumber options:nil callback:block];
}

+ (void)requestPasswordResetCodeForPhoneNumber:(NSString *)phoneNumber
                                       options:(LCUserShortMessageRequestOptions *)options
                                      callback:(LCBooleanResultBlock)callback
{
    NSParameterAssert(phoneNumber);
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    parameters[@"mobilePhoneNumber"] = phoneNumber;
    parameters[@"validate_token"] = options.validationToken;
    
    [[LCPaasClient sharedInstance] postObject:@"requestPasswordResetBySmsCode" withParameters:parameters block:^(id object, NSError *error) {
        [LCUtils callBooleanResultBlock:callback error:error];
    }];
}

+(void)resetPasswordWithSmsCode:(NSString *)code
                    newPassword:(NSString *)password
                          block:(LCBooleanResultBlock)block {
    NSParameterAssert(code);
    
    NSString *path=[NSString stringWithFormat:@"resetPasswordBySmsCode/%@",code];
    [[LCPaasClient sharedInstance] putObject:path withParameters:@{ @"password" : password } sessionToken:nil block:^(id object, NSError *error) {
        [LCUtils callBooleanResultBlock:block error:error];
    }];
}

// MARK: - query

+ (LCQuery *)query
{
    LCQuery *query = [[LCQuery alloc] initWithClassName:[[self class] userTag]];
    return query;
}

// MARK: SMS

+ (void)requestMobilePhoneVerify:(NSString *)phoneNumber
                       withBlock:(void (^)(BOOL, NSError * _Nullable))block
{
    [self requestVerificationCodeForPhoneNumber:phoneNumber
                                        options:nil
                                       callback:block];
}

+ (void)requestVerificationCodeForPhoneNumber:(NSString *)phoneNumber
                                      options:(LCUserShortMessageRequestOptions *)options
                                     callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"mobilePhoneNumber"] = phoneNumber;
    if (options.validationToken) {
        parameters[@"validate_token"] = options.validationToken;
    }
    [[LCPaasClient sharedInstance] postObject:@"requestMobilePhoneVerify"
                               withParameters:parameters
                                        block:^(id  _Nullable object, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(false, error);
            });
            return;
        }
        if ([NSDictionary _lc_isTypeOf:object]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(true, nil);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(false, LCError(LCErrorInternalErrorCodeMalformedData,
                                        @"Response data is malformed.",
                                        @{ @"data": (object ?: @"nil") }));
            });
        }
    }];
}

+ (void)verifyCodeForPhoneNumber:(NSString *)phoneNumber
                            code:(NSString *)code
                           block:(void (^)(BOOL, NSError * _Nullable))block
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (phoneNumber) {
        parameters[@"mobilePhoneNumber"] = phoneNumber;
    }
    [[LCPaasClient sharedInstance] postObject:[NSString stringWithFormat:@"verifyMobilePhone/%@", code]
                               withParameters:parameters
                                        block:^(id  _Nullable object, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(false, error);
            });
            return;
        }
        if ([NSDictionary _lc_isTypeOf:object]) {
            LCUser *currentUser = [LCPaasClient sharedInstance].currentUser;
            NSString *objectId = [NSString _lc_decoding:object
                                                    key:@"objectId"];
            if (currentUser && objectId &&
                [currentUser.objectId isEqualToString:objectId]) {
                [LCObjectUtils copyDictionary:object toObject:currentUser];
                currentUser.mobilePhoneNumber = phoneNumber;
                currentUser.mobilePhoneVerified = true;
                [self changeCurrentUser:currentUser save:true];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                block(true, nil);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(false, LCError(LCErrorInternalErrorCodeMalformedData,
                                     @"Response data is malformed.",
                                     @{ @"data": (object ?: @"nil") }));
            });
        }
    }];
}

+ (void)requestVerificationCodeForUpdatingPhoneNumber:(NSString *)phoneNumber
                                              options:(LCUserShortMessageRequestOptions *)options
                                                block:(void (^)(BOOL, NSError * _Nullable))block
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"mobilePhoneNumber"] = phoneNumber;
    if (options.validationToken) {
        parameters[@"validate_token"] = options.validationToken;
    }
    if (options.timeToLive != nil) {
        parameters[@"ttl"] = options.timeToLive;
    }
    [[LCPaasClient sharedInstance] postObject:@"requestChangePhoneNumber"
                               withParameters:parameters
                                        block:^(id  _Nullable object, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(false, error);
            });
            return;
        }
        if ([NSDictionary _lc_isTypeOf:object]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(true, nil);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(false, LCError(LCErrorInternalErrorCodeMalformedData,
                                     @"Response data is malformed.",
                                     @{ @"data": (object ?: @"nil") }));
            });
        }
    }];
}

+ (void)verifyCodeToUpdatePhoneNumber:(NSString *)phoneNumber
                                 code:(NSString *)code
                                block:(void (^)(BOOL, NSError * _Nullable))block
{
    [[LCPaasClient sharedInstance] postObject:@"changePhoneNumber"
                               withParameters:@{ @"mobilePhoneNumber": phoneNumber,
                                                 @"code": code }
                                        block:^(id  _Nullable object, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(false, error);
            });
            return;
        }
        if ([NSDictionary _lc_isTypeOf:object]) {
            LCUser *currentUser = [LCPaasClient sharedInstance].currentUser;
            NSString *objectId = [NSString _lc_decoding:object
                                                    key:@"objectId"];
            if (currentUser && objectId &&
                [currentUser.objectId isEqualToString:objectId]) {
                [LCObjectUtils copyDictionary:object toObject:currentUser];
                currentUser.mobilePhoneNumber = phoneNumber;
                currentUser.mobilePhoneVerified = true;
                [self changeCurrentUser:currentUser save:true];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                block(true, nil);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(false, LCError(LCErrorInternalErrorCodeMalformedData,
                                     @"Response data is malformed.",
                                     @{ @"data": (object ?: @"nil") }));
            });
        }
    }];
}

// MARK: Auth Data

- (void)loginWithAuthData:(NSDictionary *)authData
               platformId:(NSString *)platformId
                  options:(LCUserAuthDataLoginOption * _Nullable)options
                 callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    NSMutableDictionary *parameters = [self initialBodyData];
    
    if (options) {
        
        parameters[authDataTag] =  @{ platformId : ({
            NSMutableDictionary *mutableAuthData = authData.mutableCopy;
            if (options.platform) {
                mutableAuthData[@"platform"] = options.platform;
            }
            if (options.unionId) {
                mutableAuthData[@"unionid"] = options.unionId;
            }
            if (options.isMainAccount) {
                mutableAuthData[@"main_account"] = @(options.isMainAccount);
            }
            mutableAuthData;
        }) };
        
    } else {
        
        parameters[authDataTag] = @{ platformId : authData };
    }
    
    NSString *path = ({
        NSString *path = nil;
        if (options && options.failOnNotExist) {
            path = [NSString stringWithFormat:@"users?%@=%@", @"failOnNotExist", @"true"];
        } else {
            path = @"users";
        }
        path;
    });
    
    [LCPaasClient.sharedInstance postObject:path withParameters:parameters block:^(id object, NSError *error) {
        
        if (error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(false, error);
            });
            
            return;
        }
        
        NSDictionary *dic = (NSDictionary *)object;
        
        if (![NSDictionary _lc_isTypeOf:dic]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(false, ({
                    NSString *reason = @"response invalid.";
                    LCErrorInternalServer(reason);
                }));
            });
            
            return;
        }
        
        [self setNewFlag:true];
        [LCObjectUtils copyDictionary:dic toObject:self];
        [self._requestManager clear];
        [LCUser changeCurrentUser:self save:YES];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            callback(true, nil);
        });
    }];
}

- (void)associateWithAuthData:(NSDictionary *)authData
                   platformId:(NSString *)platformId
                      options:(LCUserAuthDataLoginOption * _Nullable)options
                     callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    NSString *objectId = self.objectId;
    
    if (!objectId) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"objectId invalid.";
                LCErrorInternalServer(reason);
            });
            
            callback(false, aError);
        });
        
        return;
    }
    
    NSDictionary *parameters = nil;
    
    if (options) {
        
        NSMutableDictionary *mutableAuthData = ({
            NSMutableDictionary *mutableAuthData = authData.mutableCopy;
            if (options.platform) {
                mutableAuthData[@"platform"] = options.platform;
            }
            if (options.unionId) {
                mutableAuthData[@"unionid"] = options.unionId;
            }
            if (options.isMainAccount) {
                mutableAuthData[@"main_account"] = @(options.isMainAccount);
            }
            mutableAuthData;
        });
        
        parameters =  @{ authDataTag :
                             @{ platformId : mutableAuthData } };
        
    } else {
        
        parameters =  @{ authDataTag :
                             @{ platformId : authData } };
    }
    
    NSString *path = [NSString stringWithFormat:@"users/%@", objectId];
    NSString *sessionToken = self.sessionToken;
    
    [LCPaasClient.sharedInstance putObject:path withParameters:parameters sessionToken:sessionToken block:^(id object, NSError *error) {
        
        if (error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(false, error);
            });
            
            return;
        }
        
        NSDictionary *dic = (NSDictionary *)object;
        
        if (![NSDictionary _lc_isTypeOf:dic]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(false, ({
                    NSString *reason = @"response invalid.";
                    LCErrorInternalServer(reason);
                }));
            });
            
            return;
        }
        
        [LCObjectUtils copyDictionary:dic toObject:self];
        
        NSDictionary *oldAuthData = [self objectForKey:authDataTag];
        NSDictionary *newAuthData = parameters[authDataTag];
        
        if ([NSDictionary _lc_isTypeOf:oldAuthData]) {
            
            NSMutableDictionary *mutableCopy = oldAuthData.mutableCopy;
            [mutableCopy addEntriesFromDictionary:newAuthData];
            [self setObject:mutableCopy forKey:authDataTag];
            
        } else {
            
            [self setObject:newAuthData forKey:authDataTag];
        }
        
        [LCUser changeCurrentUser:self save:YES];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            callback(true, nil);
        });
    }];
}

- (void)disassociateWithPlatformId:(NSString *)platformId
                          callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    NSString *objectId = self.objectId;
    
    if (!objectId) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"objectId invalid.";
                LCErrorInternalServer(reason);
            });
            
            callback(false, aError);
        });
        
        return;
    }
    
    NSDictionary *parameters = @{ [NSString stringWithFormat:@"%@.%@", authDataTag, platformId] :
                                      @{ @"__op" : @"Delete" } };
    
    NSString *path = [NSString stringWithFormat:@"users/%@", self.objectId];
    NSString *sessionToken = self.sessionToken;
    
    [LCPaasClient.sharedInstance putObject:path withParameters:parameters sessionToken:sessionToken block:^(id object, NSError *error) {
        
        if (error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(false, error);
            });
            
            return;
        }
        
        NSDictionary *dic = (NSDictionary *)object;
        
        if (![NSDictionary _lc_isTypeOf:dic]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(false, ({
                    NSString *reason = @"response invalid.";
                    LCErrorInternalServer(reason);
                }));
            });
            
            return;
        }
        
        [LCObjectUtils copyDictionary:dic toObject:self];
        
        NSDictionary *oldAuthData = [self objectForKey:authDataTag];
        
        if ([NSDictionary _lc_isTypeOf:oldAuthData]) {
            
            NSMutableDictionary *mutableCopy = oldAuthData.mutableCopy;
            [mutableCopy removeObjectForKey:platformId];
            [self setObject:mutableCopy forKey:authDataTag];
        }
        
        [LCUser changeCurrentUser:self save:YES];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            callback(true, nil);
        });
    }];
}

// MARK: Anonymous

+ (void)loginAnonymouslyWithCallback:(void (^)(LCUser * _Nullable user, NSError * _Nullable error))callback
{
    NSDictionary *parameters = ({
        NSString *anonymousId = [[NSUserDefaults standardUserDefaults] objectForKey:AnonymousIdKey];
        if (!anonymousId) {
            anonymousId = [LCUtils generateCompactUUID];
            [[NSUserDefaults standardUserDefaults] setObject:anonymousId forKey:AnonymousIdKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        @{ authDataTag: @{ anonymousTag: @{ @"id": anonymousId } } };
    });
    [LCPaasClient.sharedInstance postObject:@"users" withParameters:parameters block:^(id object, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil, error);
            });
            return;
        }
        LCUser *user = [LCUser userOrSubclassUser];
        [LCObjectUtils copyDictionary:object toObject:user];
        [LCUser changeCurrentUser:user save:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(user, nil);
        });
    }];
}

- (BOOL)isAnonymous
{
    return [[self linkedServiceNames] containsObject:anonymousTag];
}

#pragma mark - Override from LCObject

/**
 Avoid session token to be removed after fetching or refreshing.
 */
- (void)removeLocalData {
    __block NSString *sessionToken = nil;
    [self internalSyncLock:^{
        sessionToken = self._localData[@"sessionToken"];
    }];
    
    [super removeLocalData];
    
    if (sessionToken) {
        [self internalSyncLock:^{
            self._localData[@"sessionToken"] = sessionToken;
        }];
    }
}

-(NSMutableDictionary *)postData
{
    // TO BE REMOVED
    NSMutableDictionary * data = [super postData];
    [data addEntriesFromDictionary:[self userDictionary]];
    return data;
}

- (NSDictionary *)snapshot {
    NSMutableDictionary *snapshot = [[super snapshot] mutableCopy];
    [snapshot removeObjectForKey:passwordTag];
    return snapshot;
}

#pragma mark - internal method

+(NSString *)userTag
{
    return @"_User";
}

+(NSString *)endPoint
{
    return @"users";
}

+ (LCUser *)userOrSubclassUser {
    return (LCUser *)[LCObjectUtils lcObjectForClass:[LCUser userTag]];
}

+ (void)configAndChangeCurrentUserWithUser:(LCUser *)user
                                    object:(id)object
{
    if (!object || [object isKindOfClass:[NSDictionary class]] == false) {
        return;
    }
    
    NSDictionary *dic = (NSDictionary *)object;
    
    [LCObjectUtils copyDictionary:dic toObject:user];
    
    [user._requestManager clear];
    
    [self changeCurrentUser:user save:YES];
}

-(void)setNewFlag:(BOOL)isNew
{
    self.isNew = isNew;
}

- (BOOL)isAuthDataExistInMemory {
    if (self.sessionToken.length > 0 || [self objectForKey:authDataTag]) {
        return YES;
    }
    return NO;
}

- (NSArray *)linkedServiceNames {
    NSDictionary *dict = [self objectForKey:authDataTag];
    return[dict allKeys];
}

@end

@implementation LCUser (Friendship)

+ (LCQuery *)followerQuery:(NSString *)userObjectId {
    LCFriendQuery *query = [LCFriendQuery queryWithClassName:@"_Follower"];
    query.targetFeild = @"follower";
    
    LCUser *user = [self user];
    user.objectId = userObjectId;
    [query whereKey:@"user" equalTo:user];
    
    [query includeKey:@"follower"];
    [query selectKeys:@[@"follower"]];
    
    return query;
}

+ (LCQuery *)followeeQuery:(NSString *)userObjectId {
    LCFriendQuery *query = [LCFriendQuery queryWithClassName:@"_Followee"];
    query.targetFeild = @"followee";
    
    LCUser *user = [self user];
    user.objectId = userObjectId;
    [query whereKey:@"user" equalTo:user];
    
    [query includeKey:@"followee"];
    [query selectKeys:@[@"followee"]];
    
    return query;
}

- (LCQuery *)followeeQuery {
    return [LCUser followeeQuery:self.objectId];
}

- (LCQuery *)followerQuery {
    return [LCUser followerQuery:self.objectId];
}

- (LCQuery *)followeeObjectsQuery {
    LCQuery *query = [LCQuery queryWithClassName:@"_Followee"];
    [query whereKey:@"user" equalTo:self];
    [query includeKey:@"followee"];
    return query;
}

- (void)follow:(NSString *)userId andCallback:(LCBooleanResultBlock)callback {
    [self follow:userId userDictionary:nil andCallback:callback];
}

- (void)follow:(NSString *)userId userDictionary:(NSDictionary *)dictionary andCallback:(LCBooleanResultBlock)callback {
    if (![self isAuthDataExistInMemory]) {
        callback(NO, LCError(kLCErrorUserCannotBeAlteredWithoutSession, nil, nil));
        return;
    }
    NSDictionary *dict = [LCObjectUtils dictionaryFromObject:dictionary];
    NSString *path = [NSString stringWithFormat:@"users/self/friendship/%@", userId];
    
    [[LCPaasClient sharedInstance] postObject:path withParameters:dict block:^(id object, NSError *error) {
        [LCUtils callBooleanResultBlock:callback error:error];
    }];
}

- (void)unfollow:(NSString *)userId andCallback:(LCBooleanResultBlock)callback {
    if (![self isAuthDataExistInMemory]) {
        callback(NO, LCError(kLCErrorUserCannotBeAlteredWithoutSession, nil, nil));
        return;
    }
    
    NSString *path = [NSString stringWithFormat:@"users/self/friendship/%@", userId];
    
    [[LCPaasClient sharedInstance] deleteObject:path withParameters:nil block:^(id object, NSError *error) {
        [LCUtils callBooleanResultBlock:callback error:error];
    }];
}

- (void)getFollowers:(LCArrayResultBlock)callback {
    LCQuery *query = [LCUser followerQuery:self.objectId];
    [query findObjectsInBackgroundWithBlock:callback];
}

- (void)getFollowees:(LCArrayResultBlock)callback {
    LCQuery *query = [LCUser followeeQuery:self.objectId];
    [query findObjectsInBackgroundWithBlock:callback];
}

- (void)getFollowersAndFollowees:(LCDictionaryResultBlock)callback {
    NSString *path = [NSString stringWithFormat:@"users/%@/followersAndFollowees?include=follower,followee", self.objectId];
    
    [[LCPaasClient sharedInstance] getObject:path withParameters:nil block:^(NSDictionary *object, NSError *error) {
        if (!error) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
            @try {
                NSArray *orig;
                NSArray *result;
                
                orig = [object[@"followees"] valueForKeyPath:@"followee"];
                result = [LCObjectUtils arrayFromArray:orig];
                [dict setObject:result forKey:@"followees"];
                
                orig = [object[@"followers"] valueForKeyPath:@"follower"];
                result = [LCObjectUtils arrayFromArray:orig];
                [dict setObject:result forKey:@"followers"];
            }
            @catch (NSException *exception) {
                error = LCErrorInternalServer(@"wrong format return");
            }
            @finally {
                [LCUtils callIdResultBlock:callback object:dict error:error];
            }
        } else {
            [LCUtils callIdResultBlock:callback object:object error:error];
        }
    }];
}

@end
