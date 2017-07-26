//
//  AVIMReadReceiptMessage.m
//  AVOS
//
//  Created by Tang Tianyong on 20/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVIMReadReceiptMessage.h"
#import "AVIMTypedMessage_Internal.h"

const AVIMMessageMediaType kAVIMMessageMediaTypeReadReceipt = -101;

@implementation AVIMReadReceiptMessage

+ (void)load {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        [self registerSubclass];
    });
}

+ (AVIMMessageMediaType)classMediaType {
    return kAVIMMessageMediaTypeReadReceipt;
}

- (void)setTimestamp:(int64_t)timestamp {
    self.messageObject[@"timestamp"] = @(timestamp);
}

- (int64_t)timestamp {
    return [self.messageObject[@"timestamp"] unsignedIntegerValue];
}

@end
