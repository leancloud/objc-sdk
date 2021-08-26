//
//  LCErrorUtils.h
//  LeanCloud
//
//  Created by Zhu Zeng on 3/23/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

/*! @abstract 1: Internal server error. No information available. */
FOUNDATION_EXPORT NSInteger const kLCErrorInternalServer;
/*! @abstract 100: The connection to the LeanCloud servers failed. */
FOUNDATION_EXPORT NSInteger const kLCErrorConnectionFailed;
/*! @abstract 101: Object doesn't exist, or has an incorrect password. */
FOUNDATION_EXPORT NSInteger const kLCErrorObjectNotFound;
/*! @abstract 102: You tried to find values matching a datatype that doesn't support exact database matching, like an array or a dictionary. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidQuery;
/*! @abstract 103: Missing or invalid classname. Classnames are case-sensitive. They must start with a letter, and a-zA-Z0-9_ are the only valid characters. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidClassName;
/*! @abstract 104: Missing object id. */
FOUNDATION_EXPORT NSInteger const kLCErrorMissingObjectId;
/*! @abstract 105: Invalid key name. Keys are case-sensitive. They must start with a letter, and a-zA-Z0-9_ are the only valid characters. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidKeyName;
/*! @abstract 106: Malformed pointer. Pointers must be arrays of a classname and an object id. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidPointer;
/*! @abstract 107: Malformed json object. A json dictionary is expected. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidJSON;
/*! @abstract 108: Tried to access a feature only available internally. */
FOUNDATION_EXPORT NSInteger const kLCErrorCommandUnavailable;
/*! @abstract 111: Field set to incorrect type. */
FOUNDATION_EXPORT NSInteger const kLCErrorIncorrectType;
/*! @abstract 112: Invalid channel name. A channel name is either an empty string (the broadcast channel) or contains only a-zA-Z0-9_ characters and starts with a letter. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidChannelName;
/*! @abstract 114: Invalid device token. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidDeviceToken;
/*! @abstract 115: Push is misconfigured. See details to find out how. */
FOUNDATION_EXPORT NSInteger const kLCErrorPushMisconfigured;
/*! @abstract 116: The object is too large. */
FOUNDATION_EXPORT NSInteger const kLCErrorObjectTooLarge;
/*! @abstract 119: That operation isn't allowed for clients. */
FOUNDATION_EXPORT NSInteger const kLCErrorOperationForbidden;
/*! @abstract 120: The results were not found in the cache. */
FOUNDATION_EXPORT NSInteger const kLCErrorCacheMiss;
/*! @abstract 121: Keys in NSDictionary values may not include '$' or '.'. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidNestedKey;
/*! @abstract 122: Invalid file name. A file name contains only a-zA-Z0-9_. characters and is between 1 and 36 characters. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidFileName;
/*! @abstract 123: Invalid ACL. An ACL with an invalid format was saved. This should not happen if you use LCACL. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidACL;
/*! @abstract 124: The request timed out on the server. Typically this indicates the request is too expensive. */
FOUNDATION_EXPORT NSInteger const kLCErrorTimeout;
/*! @abstract 125: The email address was invalid. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidEmailAddress;
/*! @abstract 137: A unique field was given a value that is already taken. */
FOUNDATION_EXPORT NSInteger const kLCErrorDuplicateValue;
/*! @abstract 139: Role's name is invalid. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidRoleName;
/*! @abstract 140: Exceeded an application quota.  Upgrade to resolve. */
FOUNDATION_EXPORT NSInteger const kLCErrorExceededQuota;
/*! @abstract 141: Cloud Code script had an error. */
FOUNDATION_EXPORT NSInteger const kLCScriptError;
/*! @abstract 142: Cloud Code validation failed. */
FOUNDATION_EXPORT NSInteger const kLCValidationError;
/*! @abstract 143: Product purchase receipt is missing */
FOUNDATION_EXPORT NSInteger const kLCErrorReceiptMissing;
/*! @abstract 144: Product purchase receipt is invalid */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidPurchaseReceipt;
/*! @abstract 145: Payment is disabled on this device */
FOUNDATION_EXPORT NSInteger const kLCErrorPaymentDisabled;
/*! @abstract 146: The product identifier is invalid */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidProductIdentifier;
/*! @abstract 147: The product is not found in the App Store */
FOUNDATION_EXPORT NSInteger const kLCErrorProductNotFoundInAppStore;
/*! @abstract 148: The Apple server response is not valid */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidServerResponse;
/*! @abstract 149: Product fails to download due to file system error */
FOUNDATION_EXPORT NSInteger const kLCErrorProductDownloadFileSystemFailure;
/*! @abstract 150: Fail to convert data to image. */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidImageData;
/*! @abstract 151: Unsaved file. */
FOUNDATION_EXPORT NSInteger const kLCErrorUnsavedFile;
/*! @abstract 153: Fail to delete file. */
FOUNDATION_EXPORT NSInteger const kLCErrorFileDeleteFailure;
/*! @abstract 200: Username is missing or empty */
FOUNDATION_EXPORT NSInteger const kLCErrorUsernameMissing;
/*! @abstract 201: Password is missing or empty */
FOUNDATION_EXPORT NSInteger const kLCErrorUserPasswordMissing;
/*! @abstract 202: Username has already been taken */
FOUNDATION_EXPORT NSInteger const kLCErrorUsernameTaken;
/*! @abstract 203: Email has already been taken */
FOUNDATION_EXPORT NSInteger const kLCErrorUserEmailTaken;
/*! @abstract 204: The email is missing, and must be specified */
FOUNDATION_EXPORT NSInteger const kLCErrorUserEmailMissing;
/*! @abstract 205: A user with the specified email was not found */
FOUNDATION_EXPORT NSInteger const kLCErrorUserWithEmailNotFound;
/*! @abstract 206: The user cannot be altered by a client without the session. */
FOUNDATION_EXPORT NSInteger const kLCErrorUserCannotBeAlteredWithoutSession;
/*! @abstract 207: Users can only be created through sign up */
FOUNDATION_EXPORT NSInteger const kLCErrorUserCanOnlyBeCreatedThroughSignUp;
/*! @abstract 208: An existing account already linked to another user. */
FOUNDATION_EXPORT NSInteger const kLCErrorAccountAlreadyLinked;
/*! @abstract 209: User ID mismatch */
FOUNDATION_EXPORT NSInteger const kLCErrorUserIdMismatch;
/*! @abstract 210: The username and password mismatch. */
FOUNDATION_EXPORT NSInteger const kLCErrorUsernamePasswordMismatch;
/*! @abstract 211: Could not find user. */
FOUNDATION_EXPORT NSInteger const kLCErrorUserNotFound;
/*! @abstract 212: The mobile phone number is missing, and must be specified. */
FOUNDATION_EXPORT NSInteger const kLCErrorUserMobilePhoneMissing;
/*! @abstract 213: An user with the specified mobile phone number was not found. */
FOUNDATION_EXPORT NSInteger const kLCErrorUserWithMobilePhoneNotFound;
/*! @abstract 214: Mobile phone number has already been taken. */
FOUNDATION_EXPORT NSInteger const kLCErrorUserMobilePhoneNumberTaken;
/*! @abstract 215: Mobile phone number isn't verified. */
FOUNDATION_EXPORT NSInteger const kLCErrorUserMobilePhoneNotVerified;
/*! @abstract 216: SNS Auth Data's format is invalid. */
FOUNDATION_EXPORT NSInteger const kLCErrorUserSNSAuthDataInvalid;
/*! @abstract 250: Linked id missing from request */
FOUNDATION_EXPORT NSInteger const kLCErrorLinkedIdMissing;
/*! @abstract 251: Invalid linked session */
FOUNDATION_EXPORT NSInteger const kLCErrorInvalidLinkedSession;

/// Internal error code for client.
typedef NS_ENUM(NSInteger, LCErrorInternalErrorCode) {
    /// Generic not found.
    LCErrorInternalErrorCodeNotFound        = 9973,
    /// Data type invalid.
    LCErrorInternalErrorCodeInvalidType     = 9974,
    /// Data format invalid.
    LCErrorInternalErrorCodeMalformedData   = 9975,
    /// Internal inconsistency exception.
    LCErrorInternalErrorCodeInconsistency   = 9976,
    /// Has one underlying error.
    LCErrorInternalErrorCodeUnderlyingError = 9977,
};

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const kLeanCloudErrorDomain;
FOUNDATION_EXPORT NSString * const kLeanCloudRESTAPIResponseError;

FOUNDATION_EXPORT NSError *LCError(NSInteger code, NSString * _Nullable failureReason, NSDictionary * _Nullable userInfo);
FOUNDATION_EXPORT NSError *LCErrorInconsistency(NSString * _Nullable failureReason);
FOUNDATION_EXPORT NSError *LCErrorFromUnderlyingError(NSError *underlyingError);
FOUNDATION_EXPORT NSError *LCErrorInternalServer(NSString * _Nullable failureReason);

NS_ASSUME_NONNULL_END
