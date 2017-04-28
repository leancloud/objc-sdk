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

@interface AVShortMessageRequestOptions : AVDynamicObject

/// Time to live of short message, in minutes.
@property (nonatomic, assign) NSInteger TTL;

/// Type of short message. Currently support two types: "voice" and "sms", defaults to "sms".
@property (nonatomic, copy) NSString *type;

/// Template of short message.
@property (nonatomic, copy) NSString *template;

/// Signature of short message template.
@property (nonatomic, copy) NSString *signature;

/// Application name displayed in short message. If not given, the application name in console will be used.
@property (nonatomic, copy) NSString *applicationName;

/// Operation name of short message.
@property (nonatomic, copy) NSString *operationName;

@end


@interface AVSMS : NSObject

/**
 Request a short message for a phone number.

 @param phoneNumber The phone number which the short message will sent to.
 @param options     The options that configure short message.
 @param callback    The callback of request.
 */
+ (void)requestShortMessageForPhoneNumber:(NSString *)phoneNumber
                                  options:(AVShortMessageRequestOptions *)options
                                 callback:(AVBooleanResultBlock)callback;

@end
