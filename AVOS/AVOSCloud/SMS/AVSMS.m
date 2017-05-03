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
@dynamic templateName;
@dynamic templateVariables;
@dynamic signatureName;
@dynamic applicationName;
@dynamic operation;

@end

@implementation AVSMS

+ (NSString *)shortMessageTypeString:(AVShortMessageType)type {
    switch (type) {
    case AVShortMessageTypeText:
        return @"sms";
    case AVShortMessageTypeVoice:
        return @"voice";
    }

    return nil;
}

+ (void)requestShortMessageForPhoneNumber:(NSString *)phoneNumber
                                  options:(AVShortMessageRequestOptions *)options
                                 callback:(AVBooleanResultBlock)callback
{
    NSParameterAssert(phoneNumber);

    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];

    NSDictionary *templateVariables = options.templateVariables;

    if (templateVariables) {
        /* Template variables and message options are twisted together.
           It's a deficiency of REST API, and it should be improved in future. */
        [parameters addEntriesFromDictionary:templateVariables];
    }

    parameters[@"mobilePhoneNumber"] = phoneNumber;
    parameters[@"ttl"]               = @(options.TTL);
    parameters[@"smsType"]           = [self shortMessageTypeString:options.type];
    parameters[@"template"]          = options.templateName;
    parameters[@"sign"]              = options.signatureName;
    parameters[@"name"]              = options.applicationName;
    parameters[@"op"]                = options.operation;

    [[AVPaasClient sharedInstance] postObject:@"requestSmsCode" withParameters:parameters block:^(id object, NSError *error) {
        [AVUtils callBooleanResultBlock:callback error:error];
    }];
}

@end
