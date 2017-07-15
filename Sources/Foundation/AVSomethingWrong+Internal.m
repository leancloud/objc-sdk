//
//  AVSomethingWrong+Internal.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 15/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVSomethingWrong+Internal.h"

@implementation AVSomethingWrong (Internal)

- (instancetype)initWithCode:(AVSomethingWrongCode)code
        localizedDescription:(NSString *)localizedDescription
             underlyingError:(NSError *)underlyingError
{
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: localizedDescription
        NSUnderlyingErrorKey: underlyingError
    };

    AVSomethingWrong *error = [self initWithDomain:AVSomethingWrongDomain
                                              code:code
                                          userInfo:userInfo];

    return error;
}

@end
