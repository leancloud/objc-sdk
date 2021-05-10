//
//  LCIMLocationMessage.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMTypedMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Location Message.
 */
@interface LCIMLocationMessage : LCIMTypedMessage <LCIMTypedMessageSubclassing>

/**
 *  Latitude. Should be 0~90.
 */
@property (nonatomic, readonly) double latitude;

/**
 *  Longitude, Should be 0~360.
 */
@property (nonatomic, readonly) double longitude;

/// Create a location message.
/// @param text The string text.
/// @param latitude The latitude of GeoPoint.
/// @param longitude The longitude of GeoPoint.
/// @param attributes The custom attributes.
+ (instancetype)messageWithText:(NSString * _Nullable)text
                       latitude:(double)latitude
                      longitude:(double)longitude
                     attributes:(NSDictionary * _Nullable)attributes;

@end

NS_ASSUME_NONNULL_END
