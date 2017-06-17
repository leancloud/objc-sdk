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

+ (instancetype)sharedInstance;

@end
