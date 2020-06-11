//
//  AVIMTextMessage.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMTypedMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Text Message.
 */
@interface AVIMTextMessage : AVIMTypedMessage <AVIMTypedMessageSubclassing>

/// Create a text message.
/// @param text The string text.
/// @param attributes The custom attributes.
+ (instancetype)messageWithText:(NSString *)text
                     attributes:(NSDictionary * _Nullable)attributes;

@end

NS_ASSUME_NONNULL_END
