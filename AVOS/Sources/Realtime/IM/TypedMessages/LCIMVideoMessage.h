//
//  LCIMVideoMessage.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMTypedMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Video Message.
 */
@interface LCIMVideoMessage : LCIMTypedMessage <LCIMTypedMessageSubclassing>

/// File size in bytes.
@property (nonatomic, readonly) double size;

/// Duration of the video in seconds.
@property (nonatomic, readonly) double duration;

/// File URL string.
@property (nonatomic, readonly, nullable) NSString *url;

/// Video format, mp4, m4v, etc. Simply get it from the file extension.
@property (nonatomic, readonly, nullable) NSString *format;

@end

NS_ASSUME_NONNULL_END
