//
//  AVIMVideoMessage.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMVideoMessage.h"
#import "AVIMTypedMessage_Internal.h"

@implementation AVIMVideoMessage

+ (void)load
{
    [self registerSubclass];
}

+ (AVIMMessageMediaType)classMediaType
{
    return kAVIMMessageMediaTypeVideo;
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
