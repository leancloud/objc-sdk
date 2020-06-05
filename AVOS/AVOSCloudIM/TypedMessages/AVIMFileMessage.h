//
//  AVIMFileMessage.h
//  AVOS
//
//  Created by Tang Tianyong on 7/30/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMTypedMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  File Message.
 */
@interface AVIMFileMessage : AVIMTypedMessage <AVIMTypedMessageSubclassing>

/// File size in bytes.
@property (nonatomic, readonly) double size;

/// File URL string.
@property (nonatomic, readonly, nullable) NSString *url;

/// Audio format, mp3, aac, etc. Simply get it by the file extension.
@property (nonatomic, readonly, nullable) NSString *format;

@end

NS_ASSUME_NONNULL_END
