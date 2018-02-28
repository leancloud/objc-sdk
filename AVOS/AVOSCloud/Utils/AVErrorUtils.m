//
//  AVErrorUtils.m
//  LeanCloud
//
//  Created by Zhu Zeng on 3/23/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "AVErrorUtils.h"
#import "AVUtils.h"
NSString * const kAVErrorDomain = @"AVOS Cloud Error Domain";
NSString * const kAVErrorUnknownText = @"Error Infomation Unknown";
NSInteger const kAVErrorUnknownErrorCode = NSIntegerMax;
NSInteger const kAVErrorInternalServer = 1;
NSInteger const kAVErrorConnectionFailed = 100;
NSInteger const kAVErrorObjectNotFound = 101;
NSInteger const kAVErrorInvalidQuery = 102;
NSInteger const kAVErrorInvalidClassName = 103;
NSInteger const kAVErrorMissingObjectId = 104;
NSInteger const kAVErrorInvalidKeyName = 105;
NSInteger const kAVErrorInvalidPointer = 106;
NSInteger const kAVErrorInvalidJSON = 107;
NSInteger const kAVErrorCommandUnavailable = 108;
NSInteger const kAVErrorIncorrectType = 111;
NSInteger const kAVErrorInvalidChannelName = 112;
NSInteger const kAVErrorInvalidDeviceToken = 114;
NSInteger const kAVErrorPushMisconfigured = 115;
NSInteger const kAVErrorObjectTooLarge = 116;
NSInteger const kAVErrorOperationForbidden = 119;
NSInteger const kAVErrorCacheMiss = 120;
/*! @abstract 121: Keys in NSDictionary values may not include '$' or '.'. */
NSInteger const kAVErrorInvalidNestedKey = 121;
/*! @abstract 122: Invalid file name. A file name contains only a-zA-Z0-9_. characters and is between 1 and 36 characters. */
NSInteger const kAVErrorInvalidFileName = 122;
/*! @abstract 123: Invalid ACL. An ACL with an invalid format was saved. This should not happen if you use AVACL. */
NSInteger const kAVErrorInvalidACL = 123;
/*! @abstract 124: The request timed out on the server. Typically this indicates the request is too expensive. */
NSInteger const kAVErrorTimeout = 124;
/*! @abstract 125: The email address was invalid. */
NSInteger const kAVErrorInvalidEmailAddress = 125;
/*! @abstract 127: The mobile phone number was invalid. */
NSInteger const kAVErrorInvalidMobilePhoneNumber = 127;

NSInteger const kAVErrorDuplicateValue = 137;


/*! @abstract 139: Role's name is invalid. */
NSInteger const kAVErrorInvalidRoleName = 139;
/*! @abstract 140: Exceeded an application quota.  Upgrade to resolve. */
NSInteger const kAVErrorExceededQuota = 140;
/*! @abstract 141: Cloud Code script had an error. */
NSInteger const kAVScriptError = 141;
/*! @abstract 142: Cloud Code validation failed. */
NSInteger const kAVValidationError = 142;
/*! @abstract 143: Product purchase receipt is missing */
NSInteger const kAVErrorReceiptMissing = 143;
/*! @abstract 144: Product purchase receipt is invalid */
NSInteger const kAVErrorInvalidPurchaseReceipt = 144;
/*! @abstract 145: Payment is disabled on this device */
NSInteger const kAVErrorPaymentDisabled = 145;
/*! @abstract 146: The product identifier is invalid */
NSInteger const kAVErrorInvalidProductIdentifier = 146;
/*! @abstract 147: The product is not found in the App Store */
NSInteger const kAVErrorProductNotFoundInAppStore = 147;
/*! @abstract 148: The Apple server response is not valid */
NSInteger const kAVErrorInvalidServerResponse = 148;
/*! @abstract 149: Product fails to download due to file system error */
NSInteger const kAVErrorProductDownloadFileSystemFailure = 149;
/*! @abstract 150: Fail to convert data to image. */
NSInteger const kAVErrorInvalidImageData = 150;
/*! @abstract 151: Unsaved file. */
NSInteger const kAVErrorUnsavedFile = 151;
/*! @abstract 153: Fail to delete file. */
NSInteger const kAVErrorFileDeleteFailure = 153;

/*! @abstract 200: Username is missing or empty */
NSInteger const kAVErrorUsernameMissing = 200;
/*! @abstract 201: Password is missing or empty */
NSInteger const kAVErrorUserPasswordMissing = 201;
/*! @abstract 202: Username has already been taken */
NSInteger const kAVErrorUsernameTaken = 202;
/*! @abstract 203: Email has already been taken */
NSInteger const kAVErrorUserEmailTaken = 203;
/*! @abstract 204: The email is missing, and must be specified */
NSInteger const kAVErrorUserEmailMissing = 204;
/*! @abstract 205: A user with the specified email was not found */
NSInteger const kAVErrorUserWithEmailNotFound = 205;
/*! @abstract 206: The user cannot be altered by a client without the session. */
NSInteger const kAVErrorUserCannotBeAlteredWithoutSession = 206;
/*! @abstract 207: Users can only be created through sign up */
NSInteger const kAVErrorUserCanOnlyBeCreatedThroughSignUp = 207;
/*! @abstract 208: An existing account already linked to another user. */
NSInteger const kAVErrorAccountAlreadyLinked = 208;
/*! @abstract 209: User ID mismatch */
NSInteger const kAVErrorUserIdMismatch = 209;
/*! @abstract 210: The username and password mismatch. */
NSInteger const kAVErrorUsernamePasswordMismatch = 210;
/*! @abstract 211: Could not find user. */
NSInteger const kAVErrorUserNotFound = 211;
/*! @abstract 212: The mobile phone number is missing, and must be specified. */
NSInteger const kAVErrorUserMobilePhoneMissing = 212;
/*! @abstract 213: An user with the specified mobile phone number was not found. */
NSInteger const kAVErrorUserWithMobilePhoneNotFound = 213;
/*! @abstract 214: Mobile phone number has already been taken. */
NSInteger const kAVErrorUserMobilePhoneNumberTaken = 214;
/*! @abstract 215: Mobile phone number isn't verified. */
NSInteger const kAVErrorUserMobilePhoneNotVerified = 215;
/*! @abstract 216: SNS Auth Data's format is invalid. */
NSInteger const kAVErrorUserSNSAuthDataInvalid = 216;

/*! @abstract 250: Linked id missing from request */
NSInteger const kAVErrorLinkedIdMissing = 250;
/*! @abstract 251: Invalid linked session */
NSInteger const kAVErrorInvalidLinkedSession = 251;

/*! Local file not found */
NSInteger const kAVErrorFileNotFound = 400;

/*! File Data not available */
NSInteger const kAVErrorFileDataNotAvailable = 401;

@implementation AVErrorUtils

+ (NSError *)errorWithCode:(NSInteger)code
{
    return [NSError errorWithDomain:kAVErrorDomain
                               code:code
                           userInfo:nil];
}

+ (NSError *)errorWithText:(NSString *)text
{
    return [self errorWithCode:0
                     errorText:text];
}

+ (NSError *)errorWithCode:(NSInteger)code
                 errorText:(NSString *)text
{
    NSDictionary *errorInfo = @{
                                @"code" : @(code),
                                @"error" : text
                                };
    
    NSError *err = [NSError errorWithDomain:kAVErrorDomain
                                       code:code
                                   userInfo:errorInfo];
    
    return err;
}

+ (NSError *)internalServerError
{
    return [NSError errorWithDomain:kAVErrorDomain
                               code:kAVErrorInternalServer
                           userInfo:nil];
}

@end
