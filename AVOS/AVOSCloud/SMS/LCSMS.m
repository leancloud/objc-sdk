//
//  LCSMS.m
//  AVOS
//
//  Created by Tang Tianyong on 27/04/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCSMS.h"
#import "LCPaasClient.h"
#import "AVUtils.h"
#import "AVDynamicObject_Internal.h"

@interface LCShortMessageRequestOptions ()

@property (nonatomic, copy, readonly) NSString *typeDescription;

@end

@implementation LCShortMessageRequestOptions

@dynamic TTL;
@dynamic type;
@dynamic templateName;
@dynamic templateVariables;
@dynamic signatureName;
@dynamic applicationName;
@dynamic operation;

- (NSString *)typeDescription {
    switch (self.type) {
        case LCShortMessageTypeText:
        return @"sms";
        case LCShortMessageTypeVoice:
        return @"voice";
    }

    return nil;
}

@end

@implementation LCSMS

+ (void)requestShortMessageForPhoneNumber:(NSString *)phoneNumber
                                  options:(LCShortMessageRequestOptions *)options
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
    parameters[@"ttl"]               = options[@"TTL"];
    parameters[@"smsType"]           = options.typeDescription;
    parameters[@"validate_token"]    = options.validationToken;
    parameters[@"template"]          = options.templateName;
    parameters[@"sign"]              = options.signatureName;
    parameters[@"name"]              = options.applicationName;
    parameters[@"op"]                = options.operation;

    [[LCPaasClient sharedInstance] postObject:@"requestSmsCode" withParameters:parameters block:^(id object, NSError *error) {
        [AVUtils callBooleanResultBlock:callback error:error];
    }];
}

@end
