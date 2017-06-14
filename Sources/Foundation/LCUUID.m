//
//  LCUUID.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 14/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCUUID.h"

@implementation LCUUID

+ (NSString *)createUUID {
    CFUUIDRef UUIDRef = CFUUIDCreate(NULL);
    NSString *UUID = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, UUIDRef);

    CFRelease(UUIDRef);

    UUID = [UUID lowercaseString];
    return UUID;
}

@end
