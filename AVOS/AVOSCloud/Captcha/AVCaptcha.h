//
//  AVCaptcha.h
//  AVOS
//
//  Created by Tang Tianyong on 03/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVDynamicObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface AVCaptchaInformation : AVDynamicObject

/**
 Token used to verify captcha.
 */
@property (nonatomic, copy, readonly) NSString *token;

/**
 URL string of captcha image.
 */
@property (nonatomic, copy, readonly) NSString *URLString;

@end

@interface AVCaptchaRequestOptions : AVDynamicObject

/**
 Time to live of captcha, in seconds.

 Defaults to 60 seconds. Minimum is 10, maximum is 180.
 */
@property (nonatomic, assign) NSInteger TTL;

/**
 Count of characters in catpcha image.

 Defaults to 4. Minimum is 3, maximum is 6.
 */
@property (nonatomic, assign) NSInteger size;

/**
 Width of captcha image, in pixels.

 Defaults to 85. Minimum is 85, maximum is 200.
 */
@property (nonatomic, assign) NSInteger width;

/**
 Height of captcha image, in pixels.

 Defaults to 30. Minimum is 30, maximum is 100.
 */
@property (nonatomic, assign) NSInteger height;

@end

typedef void(^AVCaptchaRequestCallback)(AVCaptchaInformation * _Nullable captchaInformation, NSError * _Nullable error);

@interface AVCaptcha : NSObject

/**
 Request a captcha.

 @param options  The options that configure the captcha.
 @param callback The callback of request.
 */
+ (void)requestCaptchaWithOptions:(nullable AVCaptchaRequestOptions *)options
                         callback:(AVCaptchaRequestCallback)callback;

@end

NS_ASSUME_NONNULL_END
