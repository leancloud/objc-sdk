//
//  LCIMVideoMessage.m
//  LeanCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMVideoMessage.h"
#import "LCIMTypedMessage_Internal.h"

@implementation LCIMVideoMessage

+ (void)load
{
    [self registerSubclass];
}

+ (LCIMMessageMediaType)classMediaType
{
    return kLCIMMessageMediaTypeVideo;
}

- (double)size {
    return [self decodingSize];
}

- (double)duration {
    return [self decodingDuration];
}

- (NSString *)url {
    return [self decodingUrl];
}

- (NSString *)format {
    return [self decodingFormat];
}

@end
