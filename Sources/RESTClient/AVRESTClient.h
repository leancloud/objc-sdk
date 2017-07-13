//
//  AVRESTClient.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 17/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVApplication.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const AVHTTPHeaderFieldNameId;
FOUNDATION_EXPORT NSString *const AVHTTPHeaderFieldNameKey;
FOUNDATION_EXPORT NSString *const AVHTTPHeaderFieldNameSignature;

@protocol AVRESTClientConfigurable <NSObject, NSCopying>

@end

@interface AVRESTClient : NSObject

@property (nonatomic, readonly, copy) AVApplication *application;
@property (nonatomic, readonly, copy, nullable) id<AVRESTClientConfigurable> configuration;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithApplication:(AVApplication *)application
                      configuration:(nullable id<AVRESTClientConfigurable>)configuration;

- (NSURLSessionDataTask *)sessionDataTaskWithMethod:(NSString *)method
                                           endpoint:(NSString *)endpoint
                                         parameters:(nullable NSDictionary *)parameters
                       constructingRequestWithBlock:(nullable void (^)(NSMutableURLRequest *request))requestConstructor
                                            success:(void (^)(NSHTTPURLResponse *response, id responseObject))successCallback
                                            failure:(void (^)(NSHTTPURLResponse *response, id responseObject, NSError *error))failureCallback;

@end

NS_ASSUME_NONNULL_END
