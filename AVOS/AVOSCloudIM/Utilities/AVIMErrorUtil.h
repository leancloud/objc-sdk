//
//  AVIMErrorUtil.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/20/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kLeanCloudIMErrorDomain;

typedef NS_ENUM(NSInteger, LeanCloudIMErrorCode) {
    
    /*
     IM Module Error Code Number's Style is '-2XXXX'
     */
    
    /*
     IM Command Timeout
     */
    LeanCloudIMErrorCode_CommandTimeout = -20000,
};

@interface AVIMErrorUtil : NSObject
+ (NSError *)errorWithCode:(NSInteger)code reason:(NSString *)reason;
@end
