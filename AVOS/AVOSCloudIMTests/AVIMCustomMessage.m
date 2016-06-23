//
//  AVIMCustomMessage.m
//  AVOS
//
//  Created by lzw on 15/7/7.
//  Copyright (c) 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVIMCustomMessage.h"

@implementation AVIMCustomMessage

+ (void)load {
    [self registerSubclass];
}

+ (AVIMMessageMediaType)classMediaType {
    return kAVIMMessageMediaTypeCustom;
}

- (instancetype)init {
    if ((self = [super init])) {
        self.mediaType = [[self class] classMediaType];
    }
    return self;
}

+ (instancetype)messageWithAttributes:(NSDictionary *)attributes {
    AVIMCustomMessage *message = [[self alloc] init];
    message.attributes = attributes;
    return message;
}

@end
