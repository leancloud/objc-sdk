//
//  LCIMLocationMessage.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMLocationMessage.h"
#import "LCGeoPoint_Internal.h"
#import "LCIMTypedMessage_Internal.h"

@implementation LCIMLocationMessage

+ (void)load
{
    [self registerSubclass];
}

+ (LCIMMessageMediaType)classMediaType
{
    return kLCIMMessageMediaTypeLocation;
}

+ (instancetype)messageWithText:(NSString *)text
                       latitude:(double)latitude
                      longitude:(double)longitude
                     attributes:(NSDictionary *)attributes
{
    LCIMLocationMessage *message = [[self alloc] init];
    if (text) {
        message.text = text;
    }
    if (attributes) {
        message.attributes = attributes;
    }
    LCGeoPoint *location = [LCGeoPoint geoPointWithLatitude:latitude
                                                  longitude:longitude];
    message.location = location;
    return message;
}

- (double)longitude {
    return self.location.longitude;
}

- (double)latitude {
    return self.location.latitude;
}

@end
