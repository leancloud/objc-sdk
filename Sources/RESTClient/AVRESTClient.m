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

@interface AVRESTClient ()

@property (nonatomic, strong) id<AVRESTClientConfiguration> configuration;

@end

@implementation AVRESTClient

- (instancetype)init {
    self = [super init];

    if (self) {
        [self doInitialize];
    }

    return self;
}

- (instancetype)initWithConfiguration:(id<AVRESTClientConfiguration>)configuration {
    self = [self init];

    if (self) {
        _configuration = [configuration copyWithZone:nil];
    }

    return self;
}

- (void)doInitialize {
    /* TODO */
}

+ (instancetype)sharedInstance {
    static AVRESTClient *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

@end
