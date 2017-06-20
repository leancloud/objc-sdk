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

@property (nonatomic, copy) AVApplication *application;
@property (nonatomic, copy) id<AVRESTClientConfigurable> configuration;

@end

@implementation AVRESTClient

- (instancetype)init {
    return [self initWithApplication:nil configuration:nil];
}

- (instancetype)initWithApplication:(AVApplication *)application
                      configuration:(id<AVRESTClientConfigurable>)configuration
{
    self = [super init];

    if (self) {
        _application = [application copy];
        _configuration = [configuration copyWithZone:nil];

        [self doInitialize];
    }

    return self;
}

- (void)doInitialize {
    /* TODO */
}

- (NSMutableURLRequest *)requestWithPath:(NSString *)path
                                  method:(NSString *)method
                              parameters:(NSDictionary *)parameters
{
    /* TODO */
}

- (NSURLSessionDataTask *)sessionDataTaskWithMethod:(NSString *)method
                                           endpoint:(NSString *)endpoint
                                         parameters:(NSDictionary *)parameters
                       constructingRequestWithBlock:(void (^)(NSMutableURLRequest *request))requestConstructor
                                            success:(void (^)(NSHTTPURLResponse *response, id responseObject))successCallback
                                            failure:(void (^)(NSHTTPURLResponse *response, id responseObject, NSError *error))successCallback
{
    /* TODO */
}

@end
