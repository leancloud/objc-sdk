//
//  AVIMImageMessage.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMImageMessage.h"
#import "AVIMTypedMessage_Internal.h"

@implementation AVIMImageMessage

+ (void)load
{
    [self registerSubclass];
}

+ (AVIMMessageMediaType)classMediaType
{
    return kAVIMMessageMediaTypeImage;
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
