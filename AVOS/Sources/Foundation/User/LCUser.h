// LCUser.h
// Copyright 2013 LeanCloud, Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import "LCObject.h"
#import "LCSubclassing.h"

@class LCRole;
@class LCQuery;

NS_ASSUME_NONNULL_BEGIN

typedef NSString * LeanCloudSocialPlatform NS_STRING_ENUM;
FOUNDATION_EXPORT LeanCloudSocialPlatform const LeanCloudSocialPlatformWeiBo;
FOUNDATION_EXPORT LeanCloudSocialPlatform const LeanCloudSocialPlatformQQ;
FOUNDATION_EXPORT LeanCloudSocialPlatform const LeanCloudSocialPlatformWeiXin;

/// The options for the request of the short message.
@interface LCUserShortMessageRequestOptions : NSObject

/// The token for validation.
@property (nonatomic, nullable) NSString *validationToken;

/// The time-to-live of the code.
@property (nonatomic, nullable) NSNumber *timeToLive;

@end

@interface LCUserAuthDataLoginOption : NSObject

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
 if a LCUser instance has a platform-unionId signature, then the platform and the unionId will be the highest priority in auth data matching.
 @Note must cooperate with platform & unionId.
 */
@property (nonatomic) BOOL isMainAccount;

/**
 Set true to check whether already exists a LCUser instance with the auth data.
 if not exists, return an error.
 */
@property (nonatomic) BOOL failOnNotExist;

@end

/// User
@interface LCUser : LCObject <LCSubclassing>

/** @name Accessing the Current User */

/*!
 Gets the currently logged in user from disk and returns an instance of it.
 @return a LCUser that is the currently logged in user. If there is none, returns nil.
 */
+ (nullable instancetype)currentUser;

/*!
 * change the current login user manually.
 *  @param newUser 新的 LCUser 实例
 *  @param save 是否需要把 newUser 保存到本地缓存。如果 newUser==nil && save==YES，则会清除本地缓存
 * Note: 请注意不要随意调用这个函数！
 */
+ (void)changeCurrentUser:(LCUser * _Nullable)newUser save:(BOOL)save;

/// The session token for the LCUser. This is set by the server upon successful authentication.
@property (nonatomic, copy, nullable) NSString *sessionToken;

/// Whether the LCUser was just created from a request. This is only set after a Facebook or Twitter login.
@property (nonatomic, assign, readonly) BOOL isNew;

/*!
 Whether the user is an authenticated object with the given sessionToken.
 */
- (void)isAuthenticatedWithSessionToken:(NSString *)sessionToken callback:(LCBooleanResultBlock)callback;

/** @name Creating a New User */

/*!
 Creates a new LCUser object.
 @return a new LCUser object.
 */
+ (instancetype)user;

/*!
 Enables automatic creation of anonymous users.  After calling this method, [LCUser currentUser] will always have a value.
 The user will only be created on the server once the user has been saved, or once an object with a relation to that user or
 an ACL that refers to the user has been saved.
 
 Note: saveEventually will not work if an item being saved has a relation to an automatic user that has never been saved.
 */
+ (void)enableAutomaticUser;

/// The username for the LCUser.
@property (nonatomic, copy, nullable) NSString *username;

/** 
 The password for the LCUser. This will not be filled in from the server with
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
+(void)requestEmailVerify:(NSString*)email withBlock:(LCBooleanResultBlock)block;

/*!
 Get roles which current user belongs to.

 @param error The error of request, or nil if request did succeed.

 @return An array of roles, or nil if some error occured.
 */
- (nullable NSArray<LCRole *> *)getRoles:(NSError **)error;

/*!
 An alias of `-[LCUser getRolesAndThrowsWithError:]` methods that supports Swift exception.
 @seealso `-[LCUser getRolesAndThrowsWithError:]`
 */
- (nullable NSArray<LCRole *> *)getRolesAndThrowsWithError:(NSError **)error;

/*!
 Asynchronously get roles which current user belongs to.

 @param block The callback for request.
 */
- (void)getRolesInBackgroundWithBlock:(void (^)(NSArray<LCRole *> * _Nullable objects, NSError * _Nullable error))block;

/*!
 Signs up the user. Make sure that password and username are set. This will also enforce that the username isn't already taken.
 @param error Error object to set on error. 
 @return whether the sign up was successful.
 */
- (BOOL)signUp:(NSError **)error;

/*!
 An alias of `-[LCUser signUp:]` methods that supports Swift exception.
 @seealso `-[LCUser signUp:]`
 */
- (BOOL)signUpAndThrowsWithError:(NSError **)error;

/*!
 Signs up the user asynchronously. Make sure that password and username are set. This will also enforce that the username isn't already taken.
 @param block The block to execute. The block should have the following argument signature: (BOOL succeeded, NSError *error) 
 */
- (void)signUpInBackgroundWithBlock:(LCBooleanResultBlock)block;

/*!
 用旧密码来更新密码。在 3.1.6 之后，更新密码成功之后不再需要强制用户重新登录，仍然保持登录状态。
 @param oldPassword 旧密码
 @param newPassword 新密码
 @param block 完成时的回调，有以下签名 (id object, NSError *error)
 @warning 此用户必须登录且同时提供了新旧密码，否则不能更新成功。
 */
- (void)updatePassword:(NSString *)oldPassword newPassword:(NSString *)newPassword block:(LCIdResultBlock)block;

/*!
 Refresh user session token asynchronously.

 @param block The callback of request.
 */
- (void)refreshSessionTokenWithBlock:(LCBooleanResultBlock)block;

/*!
 Makes a request to login a user with specified credentials. Returns an
 instance of the successfully logged in LCUser. This will also cache the user 
 locally so that calls to userFromCurrentUser will use the latest logged in user.
 @param username The username of the user.
 @param password The password of the user.
 @param error The error object to set on error.
 @return an instance of the LCUser on success. If login failed for either wrong password or wrong username, returns nil.
 */
+ (nullable instancetype)logInWithUsername:(NSString *)username
                                  password:(NSString *)password
                                     error:(NSError **)error;

/*!
 Makes an asynchronous request to log in a user with specified credentials.
 Returns an instance of the successfully logged in LCUser. This will also cache 
 the user locally so that calls to userFromCurrentUser will use the latest logged in user. 
 @param username The username of the user.
 @param password The password of the user.
 @param block The block to execute. The block should have the following argument signature: (LCUser *user, NSError *error) 
 */
+ (void)logInWithUsernameInBackground:(NSString *)username
                             password:(NSString *)password
                                block:(LCUserResultBlock)block;

/**
 Login by email and password.

 @param email The email string.
 @param password The password string.
 @param block callback.
 */
+ (void)loginWithEmail:(NSString *)email password:(NSString *)password block:(LCUserResultBlock)block;

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
                                         block:(LCUserResultBlock)block;
//phoneNumber + smsCode

/*!
 *  请求登录码验证
 *  发送短信到指定的手机上，内容有6位数字验证码。验证码10分钟内有效。
 *  @param phoneNumber 11位电话号码
 *  @param block 回调结果
 */
+(void)requestLoginSmsCode:(NSString *)phoneNumber withBlock:(LCBooleanResultBlock)block;

/**
 Request a login code for a phone number.

 @param phoneNumber The phone number of an user who will login later.
 @param options     The short message request options.
 @param callback    The callback of request.
 */
+ (void)requestLoginCodeForPhoneNumber:(NSString *)phoneNumber
                               options:(nullable LCUserShortMessageRequestOptions *)options
                              callback:(LCBooleanResultBlock)callback;

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
                                         block:(LCUserResultBlock)block;


/*!
 *  使用手机号码和验证码注册或登录
 *  用于手机号直接注册用户，需要使用 [LCApplication requestSmsCodeWithPhoneNumber:callback:] 获取验证码
 *  @param phoneNumber 11位电话号码
 *  @param code 6位验证码
 *  @param error 发生错误通过此参数返回
 */
+ (nullable instancetype)signUpOrLoginWithMobilePhoneNumber:(NSString *)phoneNumber
                                                    smsCode:(NSString *)code
                                                      error:(NSError **)error;

/*!
 *  使用手机号码和验证码注册或登录
 *  用于手机号直接注册用户，需要使用 [LCApplication requestSmsCodeWithPhoneNumber:callback:] 获取验证码
 *  @param phoneNumber 11位电话号码
 *  @param code 6位验证码
 *  @param block 回调结果
 */
+ (void)signUpOrLoginWithMobilePhoneNumberInBackground:(NSString *)phoneNumber
                                               smsCode:(NSString *)code
                                                 block:(LCUserResultBlock)block;

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
                                                 block:(LCUserResultBlock)block;

// MARK: Log out

/// Clearing local persistent cache data of the current user and set it to `nil`.
/// It will also clearing local persistent cache of anonymous id.
+ (void)logOut;

/// Clearing local persistent cache data of the current user and set it to `nil`.
/// @param clearingAnonymousId `true` means clearing local persistent cache of anonymous id, `false` means NOT.
+ (void)logOutWithClearingAnonymousId:(BOOL)clearingAnonymousId;

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
                                           block:(LCBooleanResultBlock)block;

/*!
 *  使用手机号请求密码重置，需要用户绑定手机号码
 *  发送短信到指定的手机上，内容有6位数字验证码。验证码10分钟内有效。
 *  @param phoneNumber 11位电话号码
 *  @param block 回调结果
 */
+(void)requestPasswordResetWithPhoneNumber:(NSString *)phoneNumber
                                     block:(LCBooleanResultBlock)block;

/**
 Request a password reset code for a phone number.

 @param phoneNumber The phone number of an user whose password will be reset.
 @param options     The short message request options.
 @param callback    The callback of request.
 */
+ (void)requestPasswordResetCodeForPhoneNumber:(NSString *)phoneNumber
                                       options:(nullable LCUserShortMessageRequestOptions *)options
                                      callback:(LCBooleanResultBlock)callback;

/*!
 *  使用验证码重置密码
 *  @param code 6位验证码
 *  @param password 新密码
 *  @param block 回调结果
 */
+(void)resetPasswordWithSmsCode:(NSString *)code
                    newPassword:(NSString *)password
                          block:(LCBooleanResultBlock)block;

/*!
 *  用 sessionToken 来登录用户
 *  @param sessionToken sessionToken
 *  @param block        回调结果
 */
+ (void)becomeWithSessionTokenInBackground:(NSString *)sessionToken block:(LCUserResultBlock)block;
/*!
 *  用 sessionToken 来登录用户
 *  @param sessionToken sessionToken
 *  @param error        回调错误
 *  @return 登录的用户对象
 */
+ (nullable instancetype)becomeWithSessionToken:(NSString *)sessionToken error:(NSError **)error;

/** @name Querying for Users */

/*!
 Creates a query for LCUser objects.
 */
+ (LCQuery *)query;

// MARK: SMS

/// Request a SMS code to verify phone number.
/// @param phoneNumber The phone number to receive SMS code.
/// @param block The result callback.
+ (void)requestMobilePhoneVerify:(NSString *)phoneNumber
                       withBlock:(void (^)(BOOL succeeded, NSError * _Nullable error))block;

/// Request a SMS code to verify phone number.
/// @param phoneNumber The phone number to receive SMS code.
/// @param options See `LCUserShortMessageRequestOptions`.
/// @param callback The result callback.
+ (void)requestVerificationCodeForPhoneNumber:(NSString *)phoneNumber
                                      options:(LCUserShortMessageRequestOptions * _Nullable)options
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
/// @param options See `LCUserShortMessageRequestOptions`.
/// @param block The result callback.
+ (void)requestVerificationCodeForUpdatingPhoneNumber:(NSString *)phoneNumber
                                              options:(LCUserShortMessageRequestOptions * _Nullable)options
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
 @param options See LCUserAuthDataLoginOption.
 @param callback Result callback.
 */
- (void)loginWithAuthData:(NSDictionary *)authData
               platformId:(NSString *)platformId
                  options:(LCUserAuthDataLoginOption * _Nullable)options
                 callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/**
 Associate auth data to the LCUser instance.
 
 @param authData Get from third platform, data format e.g. { "id" : "id_string", "access_token" : "access_token_string", ... ... }.
 @param platformId The key for the auth data, to identify auth data.
 @param options See LCUserAuthDataLoginOption.
 @param callback Result callback.
 */
- (void)associateWithAuthData:(NSDictionary *)authData
                   platformId:(NSString *)platformId
                      options:(LCUserAuthDataLoginOption * _Nullable)options
                     callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/**
 Disassociate auth data from the LCUser instance.
 
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
+ (void)loginAnonymouslyWithCallback:(void (^)(LCUser * _Nullable user, NSError * _Nullable error))callback;

/**
 Check whether the instance of LCUser is anonymous.
 
 @return Result.
 */
- (BOOL)isAnonymous;

// MARK: Strictly Find

/// More restrictive on query conditions to find user.
/// Constraints: NOT support `skip`; NOT support the protected fields; NOT support `inQuery` ...
/// @param query The query conditions.
/// @param callback Result callback.
+ (void)strictlyFindWithQuery:(LCQuery *)query
                     callback:(void (^)(NSArray<LCUser *> * _Nullable users, NSError * _Nullable error))callback;

@end

/**
 *  用户好友关系
 */
@interface LCUser (Friendship)

/* @name 好友关系 */

/**
 *  获取用户粉丝LCQuery
 *
 *  @param userObjectId 用户ID
 *
 *  @return 用于查询的LCQuery
 */
+ (LCQuery *)followerQuery:(NSString *)userObjectId;

/**
 *  获取本用户粉丝LCQuery
 *
 *  @return 用于查询的LCQuery
 */
- (LCQuery *)followerQuery;

/**
 *  获取用户关注LCQuery
 *
 *  @param userObjectId 用户ID
 *
 *  @return 用于查询的LCQuery
 */
+ (LCQuery *)followeeQuery:(NSString *)userObjectId;

/**
 *  获取本用户关注LCQuery
 *
 *  @return 用于查询的LCQuery
 */
- (LCQuery *)followeeQuery;

/// New query for followee objects.
- (LCQuery *)followeeObjectsQuery;

/// New query for friend list.
- (LCQuery *)friendshipQuery;

/// New query for block list.
- (LCQuery *)friendshipBlockQuery;

/**
 *  通过ID来关注其他用户
 *  @warning 如果需要被关注者收到消息 需要手动给他发送一条LCStatus.
 *  @param userId 要关注的用户objectId
 *  @param callback 回调结果
 */
- (void)follow:(NSString *)userId andCallback:(LCBooleanResultBlock)callback;

/**
 *  通过ID来关注其他用户
 *  @warning 如果需要被关注者收到消息 需要手动给他发送一条LCStatus.
 *  @param userId 要关注的用户objectId
 *  @param dictionary 添加的自定义属性
 *  @param callback 回调结果
 */
- (void)follow:(NSString *)userId userDictionary:(nullable NSDictionary *)dictionary andCallback:(LCBooleanResultBlock)callback;

/**
 *  通过ID来取消关注其他用户
 *
 *  @param userId 要取消关注的用户objectId
 *  @param callback 回调结果
 *
 */
- (void)unfollow:(NSString *)userId andCallback:(LCBooleanResultBlock)callback;

/**
 *  获取当前用户粉丝的列表
 *
 *  @param callback 回调结果
 */
- (void)getFollowers:(LCArrayResultBlock)callback;

/**
 *  获取当前用户所关注的列表
 *
 *  @param callback 回调结果
 *
 */
- (void)getFollowees:(LCArrayResultBlock)callback;

/**
 *  同时获取当前用户的粉丝和关注列表
 *
 *  @param callback 回调结果, 列表字典包含`followers`数组和`followees`数组
 */
- (void)getFollowersAndFollowees:(LCDictionaryResultBlock)callback;

@end

NS_ASSUME_NONNULL_END
