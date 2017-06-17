//
//  AVRESTClient.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 17/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const AVHTTPHeaderFieldId;
FOUNDATION_EXPORT NSString *const AVHTTPHeaderFieldKey;
FOUNDATION_EXPORT NSString *const AVHTTPHeaderFieldSign;
FOUNDATION_EXPORT NSString *const AVHTTPHeaderFieldSession;
FOUNDATION_EXPORT NSString *const AVHTTPHeaderFieldProduction;

@interface AVRESTClient : NSObject

+ (instancetype)sharedInstance;

@end
