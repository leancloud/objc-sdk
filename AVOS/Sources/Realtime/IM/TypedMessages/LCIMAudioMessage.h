//
//  LCIMAudioMessage.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMTypedMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Audio Message. Can be created by the audio's file path.
 */
@interface LCIMAudioMessage : LCIMTypedMessage <LCIMTypedMessageSubclassing>

/// File size in bytes.
@property (nonatomic, readonly) double size;

/// Audio's duration in seconds.
@property (nonatomic, readonly) double duration;

/// File URL string.
@property (nonatomic, readonly, nullable) NSString *url;

/// Audio format, mp3, aac, etc. Simply get it by the file extension.
@property (nonatomic, readonly, nullable) NSString *format;

@end

NS_ASSUME_NONNULL_END
