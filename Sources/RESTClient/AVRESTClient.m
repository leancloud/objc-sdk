//
//  AVRESTClient.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 17/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVRESTClient.h"

NSString *const AVHTTPHeaderFieldId         = @"X-LC-Id";
NSString *const AVHTTPHeaderFieldKey        = @"X-LC-Key";
NSString *const AVHTTPHeaderFieldSign       = @"X-LC-Sign";
NSString *const AVHTTPHeaderFieldSession    = @"X-LC-Session";
NSString *const AVHTTPHeaderFieldProduction = @"X-LC-Prod";

@implementation AVRESTClient

+ (instancetype)sharedInstance {
    static AVRESTClient *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

@end
