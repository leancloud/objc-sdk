//
//  LCIMAudioMessage.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMAudioMessage.h"
#import "LCIMTypedMessage_Internal.h"

@implementation LCIMAudioMessage

+ (void)load
{
    [self registerSubclass];
}

+ (LCIMMessageMediaType)classMediaType
{
    return kLCIMMessageMediaTypeAudio;
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
