//
//  LCHelpers.h
//  paas
//
//  Created by Travis on 13-12-17.
//  Copyright (c) 2013年 LeanCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (LCBase64)

+ (NSData *)LCdataFromBase64String:(NSString *)aString;

- (NSString *)LCbase64EncodedString;

@end

@interface NSString (LCMD5)

- (NSString *)LCMD5String;

@end


@interface NSURLRequest (LCCurl)

- (NSString *)cURLCommand;

@end
