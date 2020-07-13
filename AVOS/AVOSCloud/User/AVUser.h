// AVUser.h
// Copyright 2013 AVOS, Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import "AVConstants.h"
#import "AVObject.h"
#import "AVSubclassing.h"

@class AVRole;
@class AVQuery;

NS_ASSUME_NONNULL_BEGIN

typedef NSString * LeanCloudSocialPlatform NS_STRING_ENUM;
FOUNDATION_EXPORT LeanCloudSocialPlatform const LeanCloudSocialPlatformWeiBo;
FOUNDATION_EXPORT LeanCloudSocialPlatform const LeanCloudSocialPlatformQQ;
FOUNDATION_EXPORT LeanCloudSocialPlatform const LeanCloudSocialPlatformWeiXin;

/// The options for the request of the short message.
@interface AVUserShortMessageRequestOptions : NSObject

/// The token for validation.
@property (nonatomic, nullable) NSString *validationToken;

/// The time-to-live of the code.
@property (nonatomic, nullable) NSNumber *timeToLive;

@end

@interface AVUserAuthDataLoginOption : NSObject

/**
 Third platform.
 */
@property (nonatomic, nullable) LeanCloudSocialPlatform platform;

/**
 UnionId from the third platform.
 */
@property (nonatomic, nullable) NSString *unionId;

/**
 Set true to generate a platform-unionId signature.
 if a AVUser instance has a platform-unionId signature, then the platform and the unionId will be the highest priority in auth data matching.
 @Note must cooperate with platform & unionId.
 */
@property (nonatomic) BOOL isMainAccount;

/**
 Set true to check whether already exists a AVUser instance with the auth data.
 if not exists, return an error.
 */
@property (nonatomic) BOOL failOnNotExist;

@end

/// User
@interface AVUser : AVObject <AVSubclassing>

/** @name Accessing the Current User */

/*!
 Gets the currently logged in user from disk and returns an instance of it.
 @return a AVUser that is the currently logged in user. If there is none, returns nil.
 */
+ (nullable instancetype)currentUser;

/*!
 * change the current login user manually.
 *  @param newUser 新的 AVUser 实例
 *  @param save 是否需要把 newUser 保存到本地缓存。如果 newUser==nil && save==YES，则会清除本地缓存
 * Note: 请注意不要随意调用这个函数！
 */
+ (void)changeCurrentUser:(AVUser * _Nullable)newUser save:(BOOL)save;

/// The session token for the AVUser. This is set by the server upon successful authentication.
@property (nonatomic, copy, nullable) NSString *sessionToken;

/// Whether the AVUser was just created from a request. This is only set after a Facebook or Twitter login.
@property (nonatomic, assign, readonly) BOOL isNew;

/*!
 Whether the user is an authenticated object with the given sessionToken.
 */
- (void)isAuthenticatedWithSessionToken:(NSString *)sessionToken callback:(AVBooleanResultBlock)callback;

/** @name Creating a New User */

/*!
 Creates a new AVUser object.
 @return a new AVUser object.
 */
+ (instancetype)user;

/*!
 Enables automatic creation of anonymous users.  After calling this method, [AVUser currentUser] will always have a value.
 The user will only be created on the server once the user has been saved, or once an object with a relation to that user or
 an ACL that refers to the user has been saved.
 
 Note: saveEventually will not work if an item being saved has a relation to an automatic user that has never been saved.
 */
+ (void)enableAutomaticUser;

/// The username for the AVUser.
@property (nonatomic, copy, nullable) NSString *username;

/** 
 The password for the AVUser. This will not be filled in from the server with
 the password. It is only meant to be set.
 */
@property (nonatomic, copy, nullable) NSString *password;

/**
 *  Email of the user. If enable "Enable Email Verification" option in the console, when register a user, will send a verification email to the user. Otherwise, only save the email to the server.
 */
@property (nonatomic, copy, nullable) NSString *email;

/**
 *  Mobile phone number of the user. Can be set when registering. If enable the "Enable Mobile Phone Number Verification" option in the console, when register a user, will send an sms message to the phone. Otherwise, only save the mobile phone number to the server.
 */
@property (nonatomic, copy, nullable) NSString *mobilePhoneNumber;

/**
 *  Mobile phone number verification flag. Read-only. if calling verifyMobilePhone:withBlock: succeeds, the server will set this value YES.
 */
@property (nonatomic, assign, readonly) BOOL mobilePhoneVerified;

/**
 *  请求重发验证邮件
 *  如果用户邮箱没有得到验证或者用户修改了邮箱, 通过本方法重新发送验证邮件.
 *  
 *  @warning 为防止滥用,同一个邮件地址，1分钟内只能发1次!
 *
 *  @param email 邮件地址
 *  @param block 回调结果
 */
+(void)requestEmailVerify:(NSString*)email withBlock:(AVBooleanResultBlock)block;

/*!
 Get roles which current user belongs to.

 @param error The error of request, or nil if request did succeed.

 @return An array of roles, or nil if some error occured.
 */
- (nullable NSArray<AVRole *> *)getRoles:(NSError **)error;

/*!
 An alias of `-[AVUser getRolesAndThrowsWithError:]` methods that supports Swift exception.
 @seealso `-[AVUser getRolesAndThrowsWithError:]`
 */
- (nullable NSArray<AVRole *> *)getRolesAndThrowsWithError:(NSError **)error;

/*!
 Asynchronously get roles which current user belongs to.

 @param block The callback for request.
 */
- (void)getRolesInBackgroundWithBlock:(void (^)(NSArray<AVRole *> * _Nullable objects, NSError * _Nullable error))block;

/*!
 Signs up the user. Make sure that password and username are set. This will also enforce that the username isn't already taken.
 @param error Error object to set on error. 
 @return whether the sign up was successful.
 */
- (BOOL)signUp:(NSError **)error;

/*!
 An alias of `-[AVUser signUp:]` methods that supports Swift exception.
 @seealso `-[AVUser signUp:]`
 */
- (BOOL)signUpAndThrowsWithError:(NSError **)error;

/*!
 Signs up the user asynchronously. Make sure that password and username are set. This will also enforce that the username isn't already taken.
 @param block The block to execute. The block should have the following argument signature: (BOOL succeeded, NSError *error) 
 */
- (void)signUpInBackgroundWithBlock:(AVBooleanResultBlock)block;

/*!
 用旧密码来更新密码。在 3.1.6 之后，更新密码成功之后不再需要强制用户重新登录，仍然保持登录状态。
 @param oldPassword 旧密码
 @param newPassword 新密码
 @param block 完成时的回调，有以下签名 (id object, NSError *error)
 @warning 此用户必须登录且同时提供了新旧密码，否则不能更新成功。
 */
- (void)updatePassword:(NSString *)oldPassword newPassword:(NSString *)newPassword block:(AVIdResultBlock)block;

/*!
 Refresh user session token asynchronously.

 @param block The callback of request.
 */
- (void)refreshSessionTokenWithBlock:(AVBooleanResultBlock)block;

/*!
 Makes a request to login a user with specified credentials. Returns an
 instance of the successfully logged in AVUser. This will also cache the user 
 locally so that calls to userFromCurrentUser will use the latest logged in user.
 @param username The username of the user.
 @param password The password of the user.
 @param error The error object to set on error.
 @return an instance of the AVUser on success. If login failed for either wrong password or wrong username, returns nil.
 */
+ (nullable instancetype)logInWithUsername:(NSString *)username
                                  password:(NSString *)password
                                     error:(NSError **)error;

/*!
 Makes an asynchronous request to log in a user with specified credentials.
 Returns an instance of the successfully logged in AVUser. This will also cache 
 the user locally so that calls to userFromCurrentUser will use the latest logged in user. 
 @param username The username of the user.
 @param password The password of the user.
 @param block The block to execute. The block should have the following argument signature: (AVUser *user, NSError *error) 
 */
+ (void)logInWithUsernameInBackground:(NSString *)username
                             password:(NSString *)password
                                block:(AVUserResultBlock)block;

/**
 Login by email and password.

 @param email The email string.
 @param password The password string.
 @param block callback.
 */
+ (void)loginWithEmail:(NSString *)email password:(NSString *)password block:(AVUserResultBlock)block;

//phoneNumber + password
/*!
 *  使用手机号码和密码登录
 *  @param phoneNumber 11位电话号码
 *  @param password 密码
 *  @param error 发生错误通过此参数返回
 */
+ (nullable instancetype)logInWithMobilePhoneNumber:(NSString *)phoneNumber
                                           password:(NSString *)password
                                              error:(NSError **)error;
/*!
 *  使用手机号码和密码登录
 *  @param phoneNumber 11位电话号码
 *  @param password 密码
 *  @param block 回调结果
 */
+ (void)logInWithMobilePhoneNumberInBackground:(NSString *)phoneNumber
                                      password:(NSString *)password
                                         block:(AVUserResultBlock)block;
//phoneNumber + smsCode

/*!
 *  请求登录码验证
 *  发送短信到指定的手机上，内容有6位数字验证码。验证码10分钟内有效。
 *  @param phoneNumber 11位电话号码
 *  @param block 回调结果
 */
+(void)requestLoginSmsCode:(NSString *)phoneNumber withBlock:(AVBooleanResultBlock)block;

/**
 Request a login code for a phone number.

 @param phoneNumber The phone number of an user who will login later.
 @param options     The short message request options.
 @param callback    The callback of request.
 */
+ (void)requestLoginCodeForPhoneNumber:(NSString *)phoneNumber
                               options:(nullable AVUserShortMessageRequestOptions *)options
                              callback:(AVBooleanResultBlock)callback;

/*!
 *  使用手机号码和验证码登录
 *  @param phoneNumber 11位电话号码
 *  @param code 6位验证码
 *  @param error 发生错误通过此参数返回
 */
+ (nullable instancetype)logInWithMobilePhoneNumber:(NSString *)phoneNumber
                                            smsCode:(NSString *)code
                                              error:(NSError **)error;

/*!
 *  使用手机号码和验证码登录
 *  @param phoneNumber 11位电话号码
 *  @param code 6位验证码
 *  @param block 回调结果
 */
+ (void)logInWithMobilePhoneNumberInBackground:(NSString *)phoneNumber
                                       smsCode:(NSString *)code
                                         block:(AVUserResultBlock)block;


/*!
 *  使用手机号码和验证码注册或登录
 *  用于手机号直接注册用户，需要使用 [AVOSCloud requestSmsCodeWithPhoneNumber:callback:] 获取验证码
 *  @param phoneNumber 11位电话号码
 *  @param code 6位验证码
 *  @param error 发生错误通过此参数返回
 */
+ (nullable instancetype)signUpOrLoginWithMobilePhoneNumber:(NSString *)phoneNumber
                                                    smsCode:(NSString *)code
                                                      error:(NSError **)error;

/*!
 *  使用手机号码和验证码注册或登录
 *  用于手机号直接注册用户，需要使用 [AVOSCloud requestSmsCodeWithPhoneNumber:callback:] 获取验证码
 *  @param phoneNumber 11位电话号码
 *  @param code 6位验证码
 *  @param block 回调结果
 */
+ (void)signUpOrLoginWithMobilePhoneNumberInBackground:(NSString *)phoneNumber
                                               smsCode:(NSString *)code
                                                 block:(AVUserResultBlock)block;

/**
 Use mobile phone number & SMS code & password to sign up or login.

 @param phoneNumber Phone number.
 @param smsCode SMS code.
 @param password Password.
 @param block Result callback.
 */
+ (void)signUpOrLoginWithMobilePhoneNumberInBackground:(NSString *)phoneNumber
                                               smsCode:(NSString *)smsCode
                                              password:(NSString *)password
                                                 block:(AVUserResultBlock)block;


/** @name Logging Out */

/*!
 Logs out the currently logged in user on disk.
 */
+ (void)logOut;

/** @name Requesting a Password Reset */


/*!
 Send a password reset request for a specified email and sets an error object. If a user
 account exists with that email, an email will be sent to that address with instructions 
 on how to reset their password.
 @param email Email of the account to send a reset password request.
 @param error Error object to set on error.
 @return true if the reset email request is successful. False if no account was found for the email address.
 */
+ (BOOL)requestPasswordResetForEmail:(NSString *)email
                               error:(NSError **)error;

/*!
 Send a password reset request asynchronously for a specified email.
 If a user account exists with that email, an email will be sent to that address with instructions
 on how to reset their password.
 @param email Email of the account to send a reset password request.
 @param block The block to execute. The block should have the following argument signature: (BOOL succeeded, NSError *error) 
 */
+ (void)requestPasswordResetForEmailInBackground:(NSString *)email
                                           block:(AVBooleanResultBlock)block;

/*!
 *  使用手机号请求密码重置，需要用户绑定手机号码
 *  发送短信到指定的手机上，内容有6位数字验证码。验证码10分钟内有效。
 *  @param phoneNumber 11位电话号码
 *  @param block 回调结果
 */
+(void)requestPasswordResetWithPhoneNumber:(NSString *)phoneNumber
                                     block:(AVBooleanResultBlock)block;

/**
 Request a password reset code for a phone number.

 @param phoneNumber The phone number of an user whose password will be reset.
 @param options     The short message request options.
 @param callback    The callback of request.
 */
+ (void)requestPasswordResetCodeForPhoneNumber:(NSString *)phoneNumber
                                       options:(nullable AVUserShortMessageRequestOptions *)options
                                      callback:(AVBooleanResultBlock)callback;

/*!
 *  使用验证码重置密码
 *  @param code 6位验证码
 *  @param password 新密码
 *  @param block 回调结果
 */
+(void)resetPasswordWithSmsCode:(NSString *)code
                    newPassword:(NSString *)password
                          block:(AVBooleanResultBlock)block;

/*!
 *  用 sessionToken 来登录用户
 *  @param sessionToken sessionToken
 *  @param block        回调结果
 */
+ (void)becomeWithSessionTokenInBackground:(NSString *)sessionToken block:(AVUserResultBlock)block;
/*!
 *  用 sessionToken 来登录用户
 *  @param sessionToken sessionToken
 *  @param error        回调错误
 *  @return 登录的用户对象
 */
+ (nullable instancetype)becomeWithSessionToken:(NSString *)sessionToken error:(NSError **)error;

/** @name Querying for Users */

/*!
 Creates a query for AVUser objects.
 */
+ (AVQuery *)query;

// MARK: SMS

/// Request a SMS code to verify phone number.
/// @param phoneNumber The phone number to receive SMS code.
/// @param block The result callback.
+ (void)requestMobilePhoneVerify:(NSString *)phoneNumber
                       withBlock:(void (^)(BOOL succeeded, NSError * _Nullable error))block;

/// Request a SMS code to verify phone number.
/// @param phoneNumber The phone number to receive SMS code.
/// @param options See `AVUserShortMessageRequestOptions`.
/// @param callback The result callback.
+ (void)requestVerificationCodeForPhoneNumber:(NSString *)phoneNumber
                                      options:(AVUserShortMessageRequestOptions * _Nullable)options
                                     callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/// Verify a phone number with the SMS code.
/// @param phoneNumber The phone number to be verified.
/// @param code The verification code.
/// @param block The result callback.
+ (void)verifyCodeForPhoneNumber:(NSString *)phoneNumber
                            code:(NSString *)code
                           block:(void (^)(BOOL succeeded, NSError * _Nullable error))block;

/// Request a SMS code to bind or update phone number.
/// @param phoneNumber The phone number to receive SMS code.
/// @param options See `AVUserShortMessageRequestOptions`.
/// @param block The result callback.
+ (void)requestVerificationCodeForUpdatingPhoneNumber:(NSString *)phoneNumber
                                              options:(AVUserShortMessageRequestOptions * _Nullable)options
                                                block:(void (^)(BOOL succeeded, NSError * _Nullable error))block;

/// Verify a phone number with the SMS code to bind or update phone number.
/// @param phoneNumber The phone number to be bound or updated.
/// @param code The verification code.
/// @param block The result callback.
+ (void)verifyCodeToUpdatePhoneNumber:(NSString *)phoneNumber
                                 code:(NSString *)code
                                block:(void (^)(BOOL succeeded, NSError * _Nullable error))block;

// MARK: Auth Data

/**
 Login use auth data.
 
 @param authData Get from third platform, data format e.g. { "id" : "id_string", "access_token" : "access_token_string", ... ... }.
 @param platformId The key for the auth data, to identify auth data.
 @param options See AVUserAuthDataLoginOption.
 @param callback Result callback.
 */
- (void)loginWithAuthData:(NSDictionary *)authData
               platformId:(NSString *)platformId
                  options:(AVUserAuthDataLoginOption * _Nullable)options
                 callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/**
 Associate auth data to the AVUser instance.
 
 @param authData Get from third platform, data format e.g. { "id" : "id_string", "access_token" : "access_token_string", ... ... }.
 @param platformId The key for the auth data, to identify auth data.
 @param options See AVUserAuthDataLoginOption.
 @param callback Result callback.
 */
- (void)associateWithAuthData:(NSDictionary *)authData
                   platformId:(NSString *)platformId
                      options:(AVUserAuthDataLoginOption * _Nullable)options
                     callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/**
 Disassociate auth data from the AVUser instance.
 
 @param platformId The key for the auth data, to identify auth data.
 @param callback Result callback.
 */
- (void)disassociateWithPlatformId:(NSString *)platformId
                          callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

// MARK: Anonymous

/**
 Login anonymously.
 
 @param callback Result callback.
 */
+ (void)loginAnonymouslyWithCallback:(void (^)(AVUser * _Nullable user, NSError * _Nullable error))callback;

/**
 Check whether the instance of AVUser is anonymous.
 
 @return Result.
 */
- (BOOL)isAnonymous;

@end

@interface AVUser (Deprecated)

+ (void)loginOrSignUpWithAuthData:(NSDictionary *)authData
                         platform:(NSString *)platform
                            block:(AVUserResultBlock)block
__deprecated_msg("Deprecated, use `-[AVUser loginWithAuthData:platformId:options:callback:]` instead.");

- (void)associateWithAuthData:(NSDictionary *)authData
                     platform:(NSString *)platform
                        block:(AVUserResultBlock)block
__deprecated_msg("Deprecated, use `-[AVUser associateWithAuthData:platformId:options:callback:]` instead.");

- (void)disassociateWithPlatform:(NSString *)platform
                           block:(AVUserResultBlock)block
__deprecated_msg("Deprecated, use `-[AVUser disassociateWithPlatformId:callback:]` instead.");

- (BOOL)signUp
__deprecated_msg("Deprecated, use `-[AVUser signUp:]` instead.");

- (void)signUpInBackground
__deprecated_msg("Deprecated, use `-[AVUser signUpInBackgroundWithBlock:]` instead.");

+ (nullable instancetype)logInWithUsername:(NSString *)username
                                  password:(NSString *)password
__deprecated_msg("Deprecated, use `+[AVUser logInWithUsername:password:error:]` instead.");

+ (void)logInWithUsernameInBackground:(NSString *)username
                             password:(NSString *)password
__deprecated_msg("Deprecated, use `+[AVUser logInWithUsernameInBackground:password:block:]` instead.");

+ (nullable instancetype)logInWithMobilePhoneNumber:(NSString *)phoneNumber
                                           password:(NSString *)password
__deprecated_msg("Deprecated, use `+[AVUser logInWithMobilePhoneNumber:password:error:]` instead.");

+ (void)logInWithMobilePhoneNumberInBackground:(NSString *)phoneNumber
                                      password:(NSString *)password
__deprecated_msg("Deprecated, use `+[AVUser logInWithMobilePhoneNumberInBackground:password:block:]` instead.");

+ (nullable instancetype)logInWithMobilePhoneNumber:(NSString *)phoneNumber
                                            smsCode:(NSString *)code
__deprecated_msg("Deprecated, use `+[AVUser logInWithMobilePhoneNumber:smsCode:error:]` instead.");

+ (void)logInWithMobilePhoneNumberInBackground:(NSString *)phoneNumber
                                       smsCode:(NSString *)code
__deprecated_msg("Deprecated, use `+[AVUser logInWithMobilePhoneNumberInBackground:smsCode:block:]` instead.");

+ (BOOL)requestPasswordResetForEmail:(NSString *)email
__deprecated_msg("Deprecated, use `+[AVUser requestPasswordResetForEmail:error:]` instead.");

+ (void)requestPasswordResetForEmailInBackground:(NSString *)email
__deprecated_msg("Deprecated, use `+[AVUser requestPasswordResetForEmailInBackground:block:]` instead.");

- (BOOL)isAuthenticated
__deprecated_msg("Deprecated, use `-[AVUser isAuthenticatedWithSessionToken:callback:]` instead.");

+ (void)verifyMobilePhone:(NSString *)code
                withBlock:(void (^)(BOOL succeeded, NSError * _Nullable error))block
__deprecated_msg("Deprecated, use `+[AVUser verifyCodeForPhoneNumber:code:block:]` instead.");

@end

NS_ASSUME_NONNULL_END
