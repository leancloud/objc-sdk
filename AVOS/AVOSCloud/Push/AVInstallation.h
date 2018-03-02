//
//  AVInstallation.h
//  LeanCloud
//

#import <Foundation/Foundation.h>
#import "AVObject.h"
#import "AVQuery.h"

NS_ASSUME_NONNULL_BEGIN

/*!
 A LeanCloud Framework Installation Object that is a local representation of an
 installation persisted to the LeanCloud. This class is a subclass of a
 AVObject, and retains the same functionality of a AVObject, but also extends
 it with installation-specific fields and related immutability and validity
 checks.
 
 A valid AVInstallation can only be instantiated via
 [AVInstallation defaultInstallation] because the required identifier fields
 are readonly. The timeZone and badge fields are also readonly properties which
 are automatically updated to match the device's time zone and application badge
 when the AVInstallation is saved, thus these fields might not reflect the
 latest device state if the installation has not recently been saved.

 AVInstallation objects which have a valid deviceToken and are saved to
 the LeanCloud can be used to target push notifications.

 This class is currently for iOS only. There is no AVInstallation for LeanCloud
 applications running on OS X, because they cannot receive push notifications.
 */

@interface AVInstallation : AVObject

/** @name Targeting Installations */

/*!
 Creates a query for AVInstallation objects. The resulting query can only
 be used for targeting a AVPush. Calling find methods on the resulting query
 will raise an exception.
 */
+ (AVQuery *)query;

/** @name Accessing the Current Installation */

/**
 Default Singleton Installation.

 @return Default Singleton Instance.
 */
+ (AVInstallation *)defaultInstallation;

// Deprecated
+ (AVInstallation *)currentInstallation
__deprecated_msg("use +[defaultInstallation] instead.");

/** @name Properties */

/// The device type for the AVInstallation.
@property (nonatomic, copy, readonly) NSString *deviceType;

/// The installationId for the AVInstallation.
@property (nonatomic, copy, readonly, nullable) NSString *installationId;

/// The device token for the AVInstallation.
@property (nonatomic, copy, nullable) NSString *deviceToken;

/// The device profile for the AVInstallation.
@property (nonatomic, copy, nullable) NSString *deviceProfile;

/// The badge for the AVInstallation.
@property (nonatomic, assign) NSInteger badge;

/// The timeZone for the AVInstallation.
@property (nonatomic, copy, readonly) NSString *timeZone;

/// The channels for the AVInstallation.
@property (nonatomic, strong, nullable) NSArray *channels;

/// The apns topic for universal push notification.
@property (nonatomic, copy, nullable) NSString *apnsTopic;

/// The apns teamId for universal push notification.
@property (nonatomic, copy, nullable) NSString *apnsTeamId;

/*!
 Sets the device token string property from an NSData-encoded token.
 
 @param deviceTokenData NSData-encoded device token.
 */
- (void)setDeviceTokenFromData:(NSData *)deviceTokenData;

/**
 Sets the device token string property from an NSData-encoded token, with a team ID.
 
 @param deviceTokenData NSData-encoded device token
 @param teamId Team ID
 */
- (void)setDeviceTokenFromData:(NSData *)deviceTokenData
                        teamId:(NSString * _Nullable)teamId;

@end

NS_ASSUME_NONNULL_END
