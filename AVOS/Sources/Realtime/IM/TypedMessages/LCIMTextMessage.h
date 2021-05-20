//
//  LCIMTextMessage.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMTypedMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Text Message.
 */
@interface LCIMTextMessage : LCIMTypedMessage <LCIMTypedMessageSubclassing>

/// Create a text message.
/// @param text The string text.
+ (instancetype)messageWithText:(NSString *)text;

/// Create a text message.
/// @param text The string text.
/// @param attributes The custom attributes.
+ (instancetype)messageWithText:(NSString *)text
                     attributes:(NSDictionary * _Nullable)attributes;

@end

NS_ASSUME_NONNULL_END
