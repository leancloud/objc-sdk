//
//  AVCaptcha.m
//  AVOS
//
//  Created by Tang Tianyong on 03/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVCaptcha.h"
#import "AVDynamicObject_Internal.h"
#import "NSDictionary+LeanCloud.h"
#import "AVPaasClient.h"
#import "AVUtils.h"

@implementation AVCaptchaDigest

@dynamic nonce;
@dynamic URLString;

@end

@implementation AVCaptchaRequestOptions

@dynamic width;
@dynamic height;

@end

@implementation AVCaptcha

+ (void)requestCaptchaWithOptions:(AVCaptchaRequestOptions *)options
                         callback:(AVCaptchaRequestCallback)callback
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    parameters[@"width"]  = options[@"width"];
    parameters[@"height"] = options[@"height"];

    [[AVPaasClient sharedInstance] getObject:@"requestCaptcha" withParameters:parameters block:^(id object, NSError *error) {
        if (error) {
            [AVUtils callIdResultBlock:callback object:nil error:error];
            return;
        }

        NSDictionary *dictionary = [object lc_selectEntriesWithKeyMappings:@{
            @"captcha_token" : @"nonce",
            @"captcha_url"   : @"URLString"
        }];

        AVCaptchaDigest *captchaDigest = [[AVCaptchaDigest alloc] initWithDictionary:dictionary];

        [AVUtils callIdResultBlock:callback object:captchaDigest error:nil];
    }];
}

+ (void)verifyCaptchaCode:(NSString *)captchaCode
         forCaptchaDigest:(AVCaptchaDigest *)captchaDigest
                 callback:(AVCaptchaVerificationCallback)callback
{
    NSParameterAssert(captchaCode);
    NSParameterAssert(captchaDigest);

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    parameters[@"captcha_code"]  = captchaCode;
    parameters[@"captcha_token"] = captchaDigest.nonce;

    [[AVPaasClient sharedInstance] postObject:@"verifyCaptcha" withParameters:parameters block:^(id object, NSError *error) {
        if (error) {
            [AVUtils callIdResultBlock:callback object:object error:error];
            return;
        }

        NSString *validationToken = object[@"validate_token"];

        [AVUtils callIdResultBlock:callback object:validationToken error:nil];
    }];
}

@end
