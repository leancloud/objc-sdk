//
//  LCHelpers.h
//  paas
//
//  Created by Travis on 13-12-17.
//  Copyright (c) 2013年 LeanCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (LCBase64)

+ (NSData *)_lc_dataFromBase64String:(NSString *)string;
- (NSString *)_lc_base64EncodedString;

@end

@interface NSString (LCMD5)

- (NSString *)_lc_MD5String;

@end
