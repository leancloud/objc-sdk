//
//  LCIMImageMessage.m
//  LeanCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMImageMessage.h"
#import "LCIMTypedMessage_Internal.h"

@implementation LCIMImageMessage

+ (void)load
{
    [self registerSubclass];
}

+ (LCIMMessageMediaType)classMediaType
{
    return LCIMMessageMediaTypeImage;
}

- (double)width {
    return [self decodingWidth];
}

- (double)height {
    return [self decodingHeight];
}

- (double)size {
    return [self decodingSize];
}

- (NSString *)url {
    return [self decodingUrl];
}

- (NSString *)format {
    return [self decodingFormat];
}

@end
