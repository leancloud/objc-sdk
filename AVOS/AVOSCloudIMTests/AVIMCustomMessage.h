//
//  AVIMCustomMessage.h
//  AVOS
//
//  Created by lzw on 15/7/7.
//  Copyright (c) 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVIMTestBase.h"

static NSInteger const kAVIMMessageMediaTypeCustom = 1;

@interface AVIMCustomMessage : AVIMTypedMessage<AVIMTypedMessageSubclassing>

+ (instancetype)messageWithAttributes:(NSDictionary *)attributes;

@end
