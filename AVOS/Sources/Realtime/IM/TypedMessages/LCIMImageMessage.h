//
//  LCIMImageMessage.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMTypedMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Image Message. Can be created by the image's file path.
 */
@interface LCIMImageMessage : LCIMTypedMessage <LCIMTypedMessageSubclassing>

/// Width of the image in pixels.
@property (nonatomic, readonly) double width;

/// Height of the image in pixels.
@property (nonatomic, readonly) double height;

/// File size in bytes.
@property (nonatomic, readonly) double size;

/// File URL string.
@property (nonatomic, readonly, nullable) NSString *url;

/// Image format, png, jpg, etc. Simply get it from the file extension.
@property (nonatomic, readonly, nullable) NSString *format;

@end

NS_ASSUME_NONNULL_END
