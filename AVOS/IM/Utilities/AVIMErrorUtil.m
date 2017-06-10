//
//  AVIMErrorUtil.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/20/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMErrorUtil.h"
#import "AVIMCommon.h"

NSString *AVOSCloudIMErrorDomain = @"AVOSCloudIMErrorDomain";

@implementation AVIMErrorUtil
+ (NSError *)errorWithCode:(NSInteger)code reason:(NSString *)reason {
    NSMutableDictionary *dict = nil;
    if (reason) {
        dict = [[NSMutableDictionary alloc] init];
        [dict setObject:reason forKey:@"reason"];
        [dict setObject:NSLocalizedString(reason, nil) forKey:NSLocalizedFailureReasonErrorKey];
    }
    NSError *error = [NSError errorWithDomain:AVOSCloudIMErrorDomain
                                         code:code
                                     userInfo:dict];
    return error;
}
@end
