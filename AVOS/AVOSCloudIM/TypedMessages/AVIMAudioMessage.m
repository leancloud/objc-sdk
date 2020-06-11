//
//  AVIMAudioMessage.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMAudioMessage.h"
#import "AVIMTypedMessage_Internal.h"

@implementation AVIMAudioMessage

+ (void)load
{
    [self registerSubclass];
}

+ (AVIMMessageMediaType)classMediaType
{
    return kAVIMMessageMediaTypeAudio;
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
