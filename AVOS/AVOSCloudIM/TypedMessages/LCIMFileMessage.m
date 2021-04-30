//
//  LCIMFileMessage.m
//  AVOS
//
//  Created by Tang Tianyong on 7/30/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMFileMessage.h"
#import "LCIMTypedMessage_Internal.h"

@implementation LCIMFileMessage

+ (void)load
{
    [self registerSubclass];
}

+ (LCIMMessageMediaType)classMediaType
{
    return kLCIMMessageMediaTypeFile;
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
