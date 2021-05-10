//
//  LCErrorUtils.h
//  LeanCloud
//
//  Created by Zhu Zeng on 3/23/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LCErrorInternalErrorCode) {
    LCErrorInternalErrorCodeNotFound        = 9973,
    LCErrorInternalErrorCodeInvalidType     = 9974,
    LCErrorInternalErrorCodeMalformedData   = 9975,
    LCErrorInternalErrorCodeInconsistency   = 9976,
    LCErrorInternalErrorCodeUnderlyingError = 9977,
};

FOUNDATION_EXPORT NSError *LCError(NSInteger code, NSString *failureReason, NSDictionary *userInfo);
FOUNDATION_EXPORT NSError *LCErrorFromUnderlyingError(NSError *underlyingError);
FOUNDATION_EXPORT NSError *LCErrorInternal(NSString *failureReason);
