//
//  LCErrorUtils.m
//  LeanCloud
//
//  Created by Zhu Zeng on 3/23/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import "LCErrorUtils.h"
#import "LCUtils.h"

NSString * const kLeanCloudErrorDomain = @"com.LeanCloud.ErrorDomain";
NSString * const kLeanCloudRESTAPIResponseError = @"com.leancloud.restapi.response.error";

NSInteger const kLCErrorInternalServer = 1;
NSInteger const kLCErrorConnectionFailed = 100;
NSInteger const kLCErrorObjectNotFound = 101;
NSInteger const kLCErrorInvalidQuery = 102;
NSInteger const kLCErrorInvalidClassName = 103;
NSInteger const kLCErrorMissingObjectId = 104;
NSInteger const kLCErrorInvalidKeyName = 105;
NSInteger const kLCErrorInvalidPointer = 106;
NSInteger const kLCErrorInvalidJSON = 107;
NSInteger const kLCErrorCommandUnavailable = 108;
NSInteger const kLCErrorIncorrectType = 111;
NSInteger const kLCErrorInvalidChannelName = 112;
NSInteger const kLCErrorInvalidDeviceToken = 114;
NSInteger const kLCErrorPushMisconfigured = 115;
NSInteger const kLCErrorObjectTooLarge = 116;
NSInteger const kLCErrorOperationForbidden = 119;
NSInteger const kLCErrorCacheMiss = 120;
/*! @abstract 121: Keys in NSDictionary values may not include '$' or '.'. */
NSInteger const kLCErrorInvalidNestedKey = 121;
/*! @abstract 122: Invalid file name. A file name contains only a-zA-Z0-9_. characters and is between 1 and 36 characters. */
NSInteger const kLCErrorInvalidFileName = 122;
/*! @abstract 123: Invalid ACL. An ACL with an invalid format was saved. This should not happen if you use LCACL. */
NSInteger const kLCErrorInvalidACL = 123;
/*! @abstract 124: The request timed out on the server. Typically this indicates the request is too expensive. */
NSInteger const kLCErrorTimeout = 124;
/*! @abstract 125: The email address was invalid. */
NSInteger const kLCErrorInvalidEmailAddress = 125;
/*! @abstract 127: The mobile phone number was invalid. */
NSInteger const kLCErrorInvalidMobilePhoneNumber = 127;

NSInteger const kLCErrorDuplicateValue = 137;


/*! @abstract 139: Role's name is invalid. */
NSInteger const kLCErrorInvalidRoleName = 139;
/*! @abstract 140: Exceeded an application quota.  Upgrade to resolve. */
NSInteger const kLCErrorExceededQuota = 140;
/*! @abstract 141: Cloud Code script had an error. */
NSInteger const kLCScriptError = 141;
/*! @abstract 142: Cloud Code validation failed. */
NSInteger const kLCValidationError = 142;
/*! @abstract 143: Product purchase receipt is missing */
NSInteger const kLCErrorReceiptMissing = 143;
/*! @abstract 144: Product purchase receipt is invalid */
NSInteger const kLCErrorInvalidPurchaseReceipt = 144;
/*! @abstract 145: Payment is disabled on this device */
NSInteger const kLCErrorPaymentDisabled = 145;
/*! @abstract 146: The product identifier is invalid */
NSInteger const kLCErrorInvalidProductIdentifier = 146;
/*! @abstract 147: The product is not found in the App Store */
NSInteger const kLCErrorProductNotFoundInAppStore = 147;
/*! @abstract 148: The Apple server response is not valid */
NSInteger const kLCErrorInvalidServerResponse = 148;
/*! @abstract 149: Product fails to download due to file system error */
NSInteger const kLCErrorProductDownloadFileSystemFailure = 149;
/*! @abstract 150: Fail to convert data to image. */
NSInteger const kLCErrorInvalidImageData = 150;
/*! @abstract 151: Unsaved file. */
NSInteger const kLCErrorUnsavedFile = 151;
/*! @abstract 153: Fail to delete file. */
NSInteger const kLCErrorFileDeleteFailure = 153;

/*! @abstract 200: Username is missing or empty */
NSInteger const kLCErrorUsernameMissing = 200;
/*! @abstract 201: Password is missing or empty */
NSInteger const kLCErrorUserPasswordMissing = 201;
/*! @abstract 202: Username has already been taken */
NSInteger const kLCErrorUsernameTaken = 202;
/*! @abstract 203: Email has already been taken */
NSInteger const kLCErrorUserEmailTaken = 203;
/*! @abstract 204: The email is missing, and must be specified */
NSInteger const kLCErrorUserEmailMissing = 204;
/*! @abstract 205: A user with the specified email was not found */
NSInteger const kLCErrorUserWithEmailNotFound = 205;
/*! @abstract 206: The user cannot be altered by a client without the session. */
NSInteger const kLCErrorUserCannotBeAlteredWithoutSession = 206;
/*! @abstract 207: Users can only be created through sign up */
NSInteger const kLCErrorUserCanOnlyBeCreatedThroughSignUp = 207;
/*! @abstract 208: An existing account already linked to another user. */
NSInteger const kLCErrorAccountAlreadyLinked = 208;
/*! @abstract 209: User ID mismatch */
NSInteger const kLCErrorUserIdMismatch = 209;
/*! @abstract 210: The username and password mismatch. */
NSInteger const kLCErrorUsernamePasswordMismatch = 210;
/*! @abstract 211: Could not find user. */
NSInteger const kLCErrorUserNotFound = 211;
/*! @abstract 212: The mobile phone number is missing, and must be specified. */
NSInteger const kLCErrorUserMobilePhoneMissing = 212;
/*! @abstract 213: An user with the specified mobile phone number was not found. */
NSInteger const kLCErrorUserWithMobilePhoneNotFound = 213;
/*! @abstract 214: Mobile phone number has already been taken. */
NSInteger const kLCErrorUserMobilePhoneNumberTaken = 214;
/*! @abstract 215: Mobile phone number isn't verified. */
NSInteger const kLCErrorUserMobilePhoneNotVerified = 215;
/*! @abstract 216: SNS Auth Data's format is invalid. */
NSInteger const kLCErrorUserSNSAuthDataInvalid = 216;

/*! @abstract 250: Linked id missing from request */
NSInteger const kLCErrorLinkedIdMissing = 250;
/*! @abstract 251: Invalid linked session */
NSInteger const kLCErrorInvalidLinkedSession = 251;

/*! Local file not found */
NSInteger const kLCErrorFileNotFound = 400;

/*! File Data not available */
NSInteger const kLCErrorFileDataNotAvailable = 401;

NSError *LCError(NSInteger code, NSString *failureReason, NSDictionary *userInfo)
{
    NSMutableDictionary *mutableDictionary;
    if (userInfo) {
        mutableDictionary = [NSMutableDictionary dictionaryWithDictionary:userInfo];
    } else {
        mutableDictionary = [NSMutableDictionary dictionary];
    }
    if (failureReason) {
        mutableDictionary[NSLocalizedFailureReasonErrorKey] = failureReason;
    }
    return [NSError errorWithDomain:kLeanCloudErrorDomain
                               code:code
                           userInfo:mutableDictionary];
}

NSError *LCErrorFromUnderlyingError(NSError *underlyingError)
{
    if ([underlyingError.domain isEqualToString:kLeanCloudErrorDomain]) {
        return underlyingError;
    } else {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        if (underlyingError) {
            userInfo[NSUnderlyingErrorKey] = underlyingError;
        }
        return LCError(LCErrorInternalErrorCodeUnderlyingError,
                       @"Underlying Error",
                       userInfo);
    }
}

NSError *LCErrorInternal(NSString *failureReason)
{
    return LCError(kLCErrorInternalServer, failureReason, nil);
}
