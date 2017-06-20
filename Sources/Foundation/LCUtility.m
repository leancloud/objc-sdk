//
//  LCUtility.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 20/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCUtility.h"
#import <CommonCrypto/CommonDigest.h>

@implementation LCUtility

+ (NSString *)MD5ForString:(NSString *)string {
    if (!string)
        return nil;

    unsigned char result[16];
    const char *cstring = [string UTF8String];
    CC_MD5(cstring, (CC_LONG)strlen(cstring), result);

    NSString *MD5 = [NSString stringWithFormat:
                     @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
                     result[0], result[1], result[2], result[3],
                     result[4], result[5], result[6], result[7],
                     result[8], result[9], result[10], result[11],
                     result[12], result[13], result[14], result[15]
                     ];

    return MD5;
}

@end
