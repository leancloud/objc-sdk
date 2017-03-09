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

- (int8_t)_lctype {
    NSString *key = NSStringFromSelector(@selector(_lctype));
    return [self[key] charValue];
}

- (void)set_lctype:(int8_t)_lctype {
    NSString *key = NSStringFromSelector(@selector(_lctype));
    self[key] = [NSNumber numberWithChar:_lctype];
}

- (NSString *)_lctext {
    NSString *key = NSStringFromSelector(@selector(_lctext));
    return self[key];
}

- (void)set_lctext:(NSString *)_lctext {
    NSString *key = NSStringFromSelector(@selector(_lctext));
    self[key] = [_lctext copy];
}

- (NSDictionary *)_lcfile {
    NSString *key = NSStringFromSelector(@selector(_lcfile));
    return self[key];
}

- (void)set_lcfile:(NSDictionary *)_lcfile {
    NSString *key = NSStringFromSelector(@selector(_lcfile));
    self[key] = _lcfile;
}

- (NSDictionary *)_lcloc {
    NSString *key = NSStringFromSelector(@selector(_lcloc));
    return self[key];
}

- (void)set_lcloc:(NSDictionary *)_lcloc {
    NSString *key = NSStringFromSelector(@selector(_lcloc));
    self[key] = _lcloc;
}

- (NSDictionary *)_lcattrs {
    NSString *key = NSStringFromSelector(@selector(_lcattrs));
    return self[key];
}

- (void)set_lcattrs:(NSDictionary *)_lcattrs {
    NSString *key = NSStringFromSelector(@selector(_lcattrs));
    self[key] = _lcattrs;
}

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
