//
//  AVRESTClient.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 17/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVRESTClient.h"

NSString *const AVHTTPHeaderFieldNameId         = @"X-LC-Id";
NSString *const AVHTTPHeaderFieldNameKey        = @"X-LC-Key";
NSString *const AVHTTPHeaderFieldNameSignature  = @"X-LC-Sign";

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
