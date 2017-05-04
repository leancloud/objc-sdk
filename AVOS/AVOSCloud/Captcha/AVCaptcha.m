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

@implementation AVCaptchaInformation

@dynamic token;
@dynamic URLString;

@end

@implementation AVCaptchaRequestOptions

@dynamic TTL;
@dynamic size;
@dynamic width;
@dynamic height;

@end

@implementation AVCaptcha

+ (void)requestCaptchaWithOptions:(AVCaptchaRequestOptions *)options
                         callback:(AVCaptchaRequestCallback)callback
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    parameters[@"ttl"]    = options[@"TTL"];
    parameters[@"size"]   = options[@"size"];
    parameters[@"width"]  = options[@"width"];
    parameters[@"height"] = options[@"height"];

    [[AVPaasClient sharedInstance] getObject:@"requestCaptcha" withParameters:parameters block:^(id object, NSError *error) {
        if (error) {
            [AVUtils callIdResultBlock:callback object:nil error:error];
            return;
        }

        NSDictionary *dictionary = [object lc_selectEntriesWithKeyMappings:@{
            @"captcha_token" : @"token",
            @"captcha_url"   : @"URLString"
        }];

        AVCaptchaInformation *captchaInformation = [[AVCaptchaInformation alloc] initWithDictionary:dictionary];

        [AVUtils callIdResultBlock:callback object:captchaInformation error:nil];
    }];
}

+ (void)verifyCaptchaCode:(NSString *)captchaCode
          forCaptchaToken:(NSString *)captchaToken
                 callback:(AVCaptchaVerificationCallback)callback
{
    NSParameterAssert(captchaCode);
    NSParameterAssert(captchaToken);

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    parameters[@"captcha_code"]  = captchaCode;
    parameters[@"captcha_token"] = captchaToken;

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
