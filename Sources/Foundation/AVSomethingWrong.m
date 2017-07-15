//
//  AVSomethingWrong.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 15/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVSomethingWrong.h"
#import "AVSomethingWrong+Internal.h"

NSErrorDomain const AVSomethingWrongDomain = @"AVSomethingWrongDomain";

@implementation AVSomethingWrong

- (instancetype)initWithCode:(AVSomethingWrongCode)code
        localizedDescription:(NSString *)localizedDescription
             underlyingError:(NSError *)underlyingError
                codeLocation:(LCCodeLocation *)codeLocation
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];

    if (underlyingError)
        userInfo[NSUnderlyingErrorKey] = underlyingError;
    if (localizedDescription)
        userInfo[NSLocalizedDescriptionKey] = localizedDescription;

    self = [self initWithDomain:AVSomethingWrongDomain code:code userInfo:userInfo];

    if (self) {
        _codeLocation = codeLocation;
    }

    return self;
}

@end
