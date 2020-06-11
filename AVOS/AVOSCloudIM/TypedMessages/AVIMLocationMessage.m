//
//  AVIMLocationMessage.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMLocationMessage.h"
#import "AVGeoPoint_Internal.h"
#import "AVIMTypedMessage_Internal.h"

@implementation AVIMLocationMessage

+ (void)load
{
    [self registerSubclass];
}

+ (AVIMMessageMediaType)classMediaType
{
    return kAVIMMessageMediaTypeLocation;
}

+ (instancetype)messageWithText:(NSString *)text
                       latitude:(double)latitude
                      longitude:(double)longitude
                     attributes:(NSDictionary *)attributes
{
    AVIMLocationMessage *message = [[self alloc] init];
    if (text) {
        message.text = text;
    }
    if (attributes) {
        message.attributes = attributes;
    }
    AVGeoPoint *location = [AVGeoPoint geoPointWithLatitude:latitude
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
