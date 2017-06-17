//
//  AVRESTClient.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 17/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const AVHTTPHeaderFieldNameId;
FOUNDATION_EXPORT NSString *const AVHTTPHeaderFieldNameKey;
FOUNDATION_EXPORT NSString *const AVHTTPHeaderFieldNameSignature;

@protocol AVRESTClientConfiguration <NSObject, NSCopying>

@end

@interface AVRESTClient : NSObject

- (instancetype)initWithConfiguration:(id<AVRESTClientConfiguration>)configuration;

- (NSURLSessionDataTask *)sessionDataTaskWithMethod:(NSString *)method
                                           endpoint:(NSString *)endpoint
                                         parameters:(NSDictionary *)parameters
                       constructingRequestWithBlock:(void (^)(NSMutableURLRequest *request))requestConstructor
                                            success:(void (^)(NSHTTPURLResponse *response, id responseObject))successCallback
                                            failure:(void (^)(NSHTTPURLResponse *response, id responseObject, NSError *error))successCallback;

@end
