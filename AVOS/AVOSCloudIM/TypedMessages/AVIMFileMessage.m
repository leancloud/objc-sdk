//
//  AVIMFileMessage.m
//  AVOS
//
//  Created by Tang Tianyong on 7/30/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMFileMessage.h"
#import "AVIMTypedMessage_Internal.h"

@implementation AVIMFileMessage

+ (void)load
{
    [self registerSubclass];
}

+ (AVIMMessageMediaType)classMediaType
{
    return kAVIMMessageMediaTypeFile;
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
