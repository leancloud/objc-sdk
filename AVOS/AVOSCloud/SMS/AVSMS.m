//
//  AVSMS.m
//  AVOS
//
//  Created by Tang Tianyong on 27/04/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVSMS.h"
#import "AVPaasClient.h"
#import "AVUtils.h"

@implementation AVShortMessageRequestOptions

@dynamic TTL;
@dynamic type;
@dynamic template;
@dynamic signature;
@dynamic applicationName;
@dynamic operationName;

@end

@implementation AVSMS

+ (void)requestShortMessageForPhoneNumber:(NSString *)phoneNumber
                                  options:(AVShortMessageRequestOptions *)options
                                 callback:(AVBooleanResultBlock)callback
{
    NSParameterAssert(phoneNumber);

    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];

    parameters[@"mobilePhoneNumber"] = phoneNumber;
    parameters[@"ttl"]               = @(options.TTL);
    parameters[@"smsType"]           = options.type;
    parameters[@"template"]          = options.template;
    parameters[@"sign"]              = options.signature;
    parameters[@"name"]              = options.applicationName;
    parameters[@"op"]                = options.operationName;

    [[AVPaasClient sharedInstance] postObject:@"requestSmsCode" withParameters:parameters block:^(id object, NSError *error) {
        [AVUtils callBooleanResultBlock:callback error:error];
    }];
}

@end
