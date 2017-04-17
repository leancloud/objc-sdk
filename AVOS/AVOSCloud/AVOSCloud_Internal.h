//
//  AVOSCloud_Internal.h
//  paas
//
//  Created by Travis on 14-2-11.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//


#import <AVOSCloud/AVOSCloud.h>

FOUNDATION_EXPORT NSString *const LCRootDomain;
FOUNDATION_EXPORT NSString *const LCRootCertificate;

@protocol AVOSCloudModule <NSObject>

+ (void)AVOSCloudDidInitializeWithApplicationId:(NSString *)applicationId clientKey:(NSString *)clientKey;

@end

@interface AVOSCloud ()

+ (void)enableAVOSCloudModule:(Class<AVOSCloudModule>)cls;

@end
