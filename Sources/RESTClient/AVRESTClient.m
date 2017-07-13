//
//  AVRESTClient.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 17/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVRESTClient.h"
#import "AVRESTClient+Internal.h"
#import "AVApplication+RESTClient.h"
#import "AVSDK+RESTClient.h"
#import "LCRouter.h"
#import "AFURLSessionManager.h"
#import "LCFoundation.h"

NSString *const AVHTTPHeaderFieldNameId         = @"X-LC-Id";
NSString *const AVHTTPHeaderFieldNameKey        = @"X-LC-Key";
NSString *const AVHTTPHeaderFieldNameSignature  = @"X-LC-Sign";

@interface AVRESTClient ()

@property (nonatomic, copy) AVApplication *application;
@property (nonatomic, copy) id<AVRESTClientConfigurable> configuration;

#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong) dispatch_queue_t completionQueue;
#else
@property (nonatomic, assign) dispatch_queue_t completionQueue;
#endif

@property (nonatomic, strong) AFURLSessionManager *sessionManager;

@end

@implementation AVRESTClient

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
    _router = [[LCRouter alloc] initWithRESTClient:self];

    _completionQueue = dispatch_queue_create("cn.leancloud.REST-client", DISPATCH_QUEUE_CONCURRENT);

    _sessionManager = ({
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        AFURLSessionManager *sessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
        sessionManager.completionQueue = _completionQueue;

        /* Remove all null value of result. */
        AFJSONResponseSerializer *responseSerializer = (AFJSONResponseSerializer *)sessionManager.responseSerializer;
        responseSerializer.removesKeysWithNullValues = YES;

        sessionManager;
    });
}

- (NSMutableURLRequest *)requestWithPath:(NSString *)path
                                  method:(NSString *)method
                              parameters:(NSDictionary *)parameters
{
    NSURL *URL = [NSURL URLWithString:path];

    if (!URL.scheme.length) {
        NSString *URLString = [self.router URLStringForPath:path];
        URL = [NSURL URLWithString:URLString];
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    NSDictionary *authorizationHTTPHeaders = self.application.authorizationHTTPHeaders;

    [request setAllHTTPHeaderFields:authorizationHTTPHeaders];
    [request setValue:[AVSDK current].HTTPUserAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];

    NSError *error = nil;
    AFJSONRequestSerializer *serializer = [[AFJSONRequestSerializer alloc] init];
    request = [[serializer requestBySerializingRequest:request withParameters:parameters error:&error] mutableCopy];

    return request;
}

- (NSURLSessionDataTask *)sessionDataTaskWithMethod:(NSString *)method
                                           endpoint:(NSString *)endpoint
                                         parameters:(NSDictionary *)parameters
                       constructingRequestWithBlock:(void (^)(NSMutableURLRequest *request))requestConstructor
                                            success:(void (^)(NSHTTPURLResponse *response, id responseObject))successCallback
                                            failure:(void (^)(NSHTTPURLResponse *response, id responseObject, NSError *error))failureCallback
{
    NSMutableURLRequest *request = [self requestWithPath:endpoint method:method parameters:parameters];

    if (requestConstructor) {
        requestConstructor(request);
    }

    NSURLSessionDataTask *dataTask = [self.sessionManager dataTaskWithRequest:request
                                                            completionHandler:^(NSURLResponse *response, id responseObject, NSError *error)
    {
        /* As Apple say:
         > Whenever you make an HTTP request,
         > the NSURLResponse object you get back is actually an instance of the NSHTTPURLResponse class.
         */
        NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;

        if (error) {
            if (failureCallback) {
                failureCallback(HTTPResponse, responseObject, error);
            }
        } else {
            if (successCallback) {
                successCallback(HTTPResponse, responseObject);
            }
        }
    }];

    return dataTask;
}

@end
