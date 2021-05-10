//
//  LCGeoPoint.h
//  LeanCloud
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 Object which may be used to embed a latitude / longitude point as the value for a key in a LCObject.
 LCObjects with a LCGeoPoint field may be queried in a geospatial manner using LCQuery's whereKey:nearGeoPoint:.
 
 This is also used as a point specifier for whereKey:nearGeoPoint: queries.
 
 Currently, object classes may only have one key associated with a GeoPoint type.
 */

@interface LCGeoPoint : NSObject<NSCopying>

/** @name Creating a LCGeoPoint */
/*!
 Create a LCGeoPoint object.  Latitude and longitude are set to 0.0.
 @return a new LCGeoPoint.
 */
+ (instancetype)geoPoint;

/*!
 Creates a new LCGeoPoint object with the specified latitude and longitude.
 @param latitude Latitude of point in degrees.
 @param longitude Longitude of point in degrees.
 @return New point object with specified latitude and longitude.
 */
+ (instancetype)geoPointWithLatitude:(double)latitude longitude:(double)longitude;

/** @name Controlling Position */

/// Latitude of point in degrees.  Valid range (-90.0, 90.0).
@property (nonatomic) double latitude;
/// Longitude of point in degrees.  Valid range (-180.0, 180.0).
@property (nonatomic) double longitude;

@end

NS_ASSUME_NONNULL_END
