//
//  AVIMTypedMessageObject.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/8/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMTypedMessageObject.h"
#import "AVIMTypedMessage_Internal.h"

@implementation AVIMTypedMessageObject

LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (_lctype,  set_lctype, int8_t)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (_lctext,  set_lctext)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT         (_lcfile,  set_lcfile)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT         (_lcattrs, set_lcattrs)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT         (_lcloc,   set_lcloc)

- (BOOL)isValidTypedMessageObject {
    BOOL hasTypeKey = [self hasKey:@"_lctype"];
    if (!hasTypeKey) {
        return NO;
    }
    id type = [self objectForKey:@"_lctype"];
    if (![type isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    __block BOOL isSupportedThisVersion = NO;
    [_typeDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([key intValue] == [type intValue]) {
            isSupportedThisVersion = YES;
            *stop = YES;
            return;
        }
    }];
    BOOL isValidTypedMessageObject = hasTypeKey && isSupportedThisVersion;
    return isValidTypedMessageObject;
}

@end
