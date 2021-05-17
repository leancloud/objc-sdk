// LCConstants.h
// Copyright 2013 LeanCloud, Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import "LCAvailability.h"

@class LCObject;
@class LCUser;
@class LCFile;

#if LC_IOS_ONLY
#import <UIKit/UIKit.h>
#elif LC_OSX_ONLY
#import <Cocoa/Cocoa.h>
@compatibility_alias UIImage NSImage;
@compatibility_alias UIColor NSColor;
@compatibility_alias UIView NSView;
#endif

/// Cache policies
typedef NS_ENUM(int, LCCachePolicy) {
    /// Query from server and do not save result to the local cache.
    kLCCachePolicyIgnoreCache = 0,
    
    /// Only query from the local cache.
    kLCCachePolicyCacheOnly,
    
    /// Only query from server, and save result to the local cache.
    kLCCachePolicyNetworkOnly,
    
    /// Firstly query from the local cache, if fails, query from server.
    kLCCachePolicyCacheElseNetwork,
    
    /// Firstly query from server, if fails, query the local cache.
    kLCCachePolicyNetworkElseCache,
    
    /// Firstly query from the local cache, return result. Then query from server, return result. The callback will be called twice.
    kLCCachePolicyCacheThenNetwork,
} ;

// Errors

FOUNDATION_EXPORT NSString * _Nonnull const kLeanCloudErrorDomain;
FOUNDATION_EXPORT NSString * _Nonnull const kLeanCloudRESTAPIResponseError;

/*! @abstract 1: Internal server error. No information available. */
extern NSInteger const kLCErrorInternalServer;
/*! @abstract 100: The connection to the LeanCloud servers failed. */
extern NSInteger const kLCErrorConnectionFailed;
/*! @abstract 101: Object doesn't exist, or has an incorrect password. */
extern NSInteger const kLCErrorObjectNotFound;
/*! @abstract 102: You tried to find values matching a datatype that doesn't support exact database matching, like an array or a dictionary. */
extern NSInteger const kLCErrorInvalidQuery;
/*! @abstract 103: Missing or invalid classname. Classnames are case-sensitive. They must start with a letter, and a-zA-Z0-9_ are the only valid characters. */
extern NSInteger const kLCErrorInvalidClassName;
/*! @abstract 104: Missing object id. */
extern NSInteger const kLCErrorMissingObjectId;
/*! @abstract 105: Invalid key name. Keys are case-sensitive. They must start with a letter, and a-zA-Z0-9_ are the only valid characters. */
extern NSInteger const kLCErrorInvalidKeyName;
/*! @abstract 106: Malformed pointer. Pointers must be arrays of a classname and an object id. */
extern NSInteger const kLCErrorInvalidPointer;
/*! @abstract 107: Malformed json object. A json dictionary is expected. */
extern NSInteger const kLCErrorInvalidJSON;
/*! @abstract 108: Tried to access a feature only available internally. */
extern NSInteger const kLCErrorCommandUnavailable;
/*! @abstract 111: Field set to incorrect type. */
extern NSInteger const kLCErrorIncorrectType;
/*! @abstract 112: Invalid channel name. A channel name is either an empty string (the broadcast channel) or contains only a-zA-Z0-9_ characters and starts with a letter. */
extern NSInteger const kLCErrorInvalidChannelName;
/*! @abstract 114: Invalid device token. */
extern NSInteger const kLCErrorInvalidDeviceToken;
/*! @abstract 115: Push is misconfigured. See details to find out how. */
extern NSInteger const kLCErrorPushMisconfigured;
/*! @abstract 116: The object is too large. */
extern NSInteger const kLCErrorObjectTooLarge;
/*! @abstract 119: That operation isn't allowed for clients. */
extern NSInteger const kLCErrorOperationForbidden;
/*! @abstract 120: The results were not found in the cache. */
extern NSInteger const kLCErrorCacheMiss;
/*! @abstract 121: Keys in NSDictionary values may not include '$' or '.'. */
extern NSInteger const kLCErrorInvalidNestedKey;
/*! @abstract 122: Invalid file name. A file name contains only a-zA-Z0-9_. characters and is between 1 and 36 characters. */
extern NSInteger const kLCErrorInvalidFileName;
/*! @abstract 123: Invalid ACL. An ACL with an invalid format was saved. This should not happen if you use LCACL. */
extern NSInteger const kLCErrorInvalidACL;
/*! @abstract 124: The request timed out on the server. Typically this indicates the request is too expensive. */
extern NSInteger const kLCErrorTimeout;
/*! @abstract 125: The email address was invalid. */
extern NSInteger const kLCErrorInvalidEmailAddress;
/*! @abstract 137: A unique field was given a value that is already taken. */
extern NSInteger const kLCErrorDuplicateValue;
/*! @abstract 139: Role's name is invalid. */
extern NSInteger const kLCErrorInvalidRoleName;
/*! @abstract 140: Exceeded an application quota.  Upgrade to resolve. */
extern NSInteger const kLCErrorExceededQuota;
/*! @abstract 141: Cloud Code script had an error. */
extern NSInteger const kLCScriptError;
/*! @abstract 142: Cloud Code validation failed. */
extern NSInteger const kLCValidationError;
/*! @abstract 143: Product purchase receipt is missing */
extern NSInteger const kLCErrorReceiptMissing;
/*! @abstract 144: Product purchase receipt is invalid */
extern NSInteger const kLCErrorInvalidPurchaseReceipt;
/*! @abstract 145: Payment is disabled on this device */
extern NSInteger const kLCErrorPaymentDisabled;
/*! @abstract 146: The product identifier is invalid */
extern NSInteger const kLCErrorInvalidProductIdentifier;
/*! @abstract 147: The product is not found in the App Store */
extern NSInteger const kLCErrorProductNotFoundInAppStore;
/*! @abstract 148: The Apple server response is not valid */
extern NSInteger const kLCErrorInvalidServerResponse;
/*! @abstract 149: Product fails to download due to file system error */
extern NSInteger const kLCErrorProductDownloadFileSystemFailure;
/*! @abstract 150: Fail to convert data to image. */
extern NSInteger const kLCErrorInvalidImageData;
/*! @abstract 151: Unsaved file. */
extern NSInteger const kLCErrorUnsavedFile;
/*! @abstract 153: Fail to delete file. */
extern NSInteger const kLCErrorFileDeleteFailure;
/*! @abstract 200: Username is missing or empty */
extern NSInteger const kLCErrorUsernameMissing;
/*! @abstract 201: Password is missing or empty */
extern NSInteger const kLCErrorUserPasswordMissing;
/*! @abstract 202: Username has already been taken */
extern NSInteger const kLCErrorUsernameTaken;
/*! @abstract 203: Email has already been taken */
extern NSInteger const kLCErrorUserEmailTaken;
/*! @abstract 204: The email is missing, and must be specified */
extern NSInteger const kLCErrorUserEmailMissing;
/*! @abstract 205: A user with the specified email was not found */
extern NSInteger const kLCErrorUserWithEmailNotFound;
/*! @abstract 206: The user cannot be altered by a client without the session. */
extern NSInteger const kLCErrorUserCannotBeAlteredWithoutSession;
/*! @abstract 207: Users can only be created through sign up */
extern NSInteger const kLCErrorUserCanOnlyBeCreatedThroughSignUp;
/*! @abstract 208: An existing account already linked to another user. */
extern NSInteger const kLCErrorAccountAlreadyLinked;
/*! @abstract 209: User ID mismatch */
extern NSInteger const kLCErrorUserIdMismatch;
/*! @abstract 210: The username and password mismatch. */
extern NSInteger const kLCErrorUsernamePasswordMismatch;
/*! @abstract 211: Could not find user. */
extern NSInteger const kLCErrorUserNotFound;
/*! @abstract 212: The mobile phone number is missing, and must be specified. */
extern NSInteger const kLCErrorUserMobilePhoneMissing;
/*! @abstract 213: An user with the specified mobile phone number was not found. */
extern NSInteger const kLCErrorUserWithMobilePhoneNotFound;
/*! @abstract 214: Mobile phone number has already been taken. */
extern NSInteger const kLCErrorUserMobilePhoneNumberTaken;
/*! @abstract 215: Mobile phone number isn't verified. */
extern NSInteger const kLCErrorUserMobilePhoneNotVerified;
/*! @abstract 216: SNS Auth Data's format is invalid. */
extern NSInteger const kLCErrorUserSNSAuthDataInvalid;
/*! @abstract 250: Linked id missing from request */
extern NSInteger const kLCErrorLinkedIdMissing;
/*! @abstract 251: Invalid linked session */
extern NSInteger const kLCErrorInvalidLinkedSession;

typedef void (^LCBooleanResultBlock)(BOOL succeeded,  NSError * _Nullable error);
typedef void (^LCIntegerResultBlock)(NSInteger number, NSError * _Nullable error);
typedef void (^LCArrayResultBlock)(NSArray * _Nullable objects, NSError * _Nullable error);
typedef void (^LCObjectResultBlock)(LCObject * _Nullable object, NSError * _Nullable error);
typedef void (^LCSetResultBlock)(NSSet * _Nullable channels, NSError * _Nullable error);
typedef void (^LCUserResultBlock)(LCUser * _Nullable user, NSError * _Nullable error);
typedef void (^LCDataResultBlock)(NSData * _Nullable data, NSError * _Nullable error);
#if LC_TARGET_OS_OSX
typedef void (^LCImageResultBlock)(NSImage * _Nullable image, NSError * _Nullable error);
#else
typedef void (^LCImageResultBlock)(UIImage * _Nullable image, NSError * _Nullable error);
#endif
typedef void (^LCDataStreamResultBlock)(NSInputStream * _Nullable stream, NSError * _Nullable error);
typedef void (^LCStringResultBlock)(NSString * _Nullable string, NSError * _Nullable error);
typedef void (^LCIdResultBlock)(id _Nullable object, NSError * _Nullable error);
typedef void (^LCProgressBlock)(NSInteger percentDone);
typedef void (^LCFileResultBlock)(LCFile * _Nullable file, NSError * _Nullable error);
typedef void (^LCDictionaryResultBlock)(NSDictionary * _Nullable dict, NSError * _Nullable error);

#define LC_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
