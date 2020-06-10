//
//  AVErrorUtils.h
//  LeanCloud
//
//  Created by Zhu Zeng on 3/23/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, AVErrorInternalErrorCode) {
    AVErrorInternalErrorCodeNotFound        = 9973,
    AVErrorInternalErrorCodeInvalidType     = 9974,
    AVErrorInternalErrorCodeMalformedData   = 9975,
    AVErrorInternalErrorCodeInconsistency   = 9976,
    AVErrorInternalErrorCodeUnderlyingError = 9977,
};

FOUNDATION_EXPORT NSError *LCError(NSInteger code, NSString *failureReason, NSDictionary *userInfo);
FOUNDATION_EXPORT NSError *LCErrorFromUnderlyingError(NSError *underlyingError);
FOUNDATION_EXPORT NSError *LCErrorInternal(NSString *failureReason);
