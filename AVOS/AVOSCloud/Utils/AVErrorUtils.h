//
//  AVErrorUtils.h
//  LeanCloud
//
//  Created by Zhu Zeng on 3/23/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSError * LCErrorInternal(NSString *failureReason);

FOUNDATION_EXPORT NSError * LCError(NSInteger code, NSString *failureReason, NSDictionary *userInfo);
