//
//  AVSMS.h
//  AVOS
//
//  Created by Tang Tianyong on 27/04/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVDynamicObject.h"
#import "AVConstants.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Enumeration of short message types.
 */
typedef NS_ENUM(NSInteger, AVShortMessageType) {
    AVShortMessageTypeText = 0,
    AVShortMessageTypeVoice
};

@interface AVShortMessageRequestOptions : AVDynamicObject

/**
 Time to live of validation information, in minutes. Defaults to 10 minutes.
 */
@property (nonatomic, assign) NSInteger TTL;

/**
 The representation or form of short message.
 */
@property (nonatomic, assign) AVShortMessageType type;

/**
 Token used to validate short message request.
 */
@property (nonatomic, copy, nullable) NSString *validationToken;

/**
 Template name of text short message.

 @note If not specified, the default validation message will be requested.
 */
@property (nonatomic, copy, nullable) NSString *templateName;

/**
 A set of key value pairs that will fill in template placeholders.

 @note You should not use the placeholders listed here in your template:
 `mobilePhoneNumber`, `ttl`, `smsType`, `template` and `sign`.
 */
@property (nonatomic, strong, nullable) NSDictionary *templateVariables;

/**
 Signature name of text short message.

 It will be placed ahead of text short message.
 */
@property (nonatomic, copy, nullable) NSString *signatureName;

/**
 Application name showed in validation message.

 It fills the placeholder <code>{{name}}</code> in default validation message template.
 If not given, the application name in LeanCloud console will be used.
 */
@property (nonatomic, copy, nullable) NSString *applicationName;

/**
 The operation description showed in validation message.

 It fills the placeholder <code>{{op}}</code> in default validation message template.
 */
@property (nonatomic, copy, nullable) NSString *operation;

@end


@interface AVSMS : NSObject

/**
 Request a short message for a phone number.

 @param phoneNumber The phone number which the short message will sent to.
 @param options     The options that configure short message.
 @param callback    The callback of request.
 */
+ (void)requestShortMessageForPhoneNumber:(NSString *)phoneNumber
                                  options:(nullable AVShortMessageRequestOptions *)options
                                 callback:(AVBooleanResultBlock)callback;

@end

NS_ASSUME_NONNULL_END
