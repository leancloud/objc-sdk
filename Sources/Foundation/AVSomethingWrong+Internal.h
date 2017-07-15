//
//  AVSomethingWrong+Internal.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 15/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVSomethingWrong.h"
#import "LCCodeLocation.h"

@interface AVSomethingWrong ()

@property (nonatomic, strong) LCCodeLocation *codeLocation;

/**
 Initialize error with code, description, and an optional underlying error.
 */
- (instancetype)initWithCode:(AVSomethingWrongCode)code
        localizedDescription:(NSString *)localizedDescription
             underlyingError:(NSError *)underlyingError
                codeLocation:(LCCodeLocation *)codeLocation;

@end

@interface AVSomethingWrong (Internal)

@end

#define LC_ERROR(code, localizedDescription, ...) \
    _LC_MACRO_DISPATCH(_LC_ERROR, __VA_ARGS__)(code, localizedDescription, ## __VA_ARGS__)

#define _LC_ERROR1(code_, localizedDescription_, underlyingError_)  ({              \
    NSString *filename = [@(__FILE__) lastPathComponent];                           \
    LCCodeLocation *codeLocation = [[LCCodeLocation alloc] initWithFile:filename    \
                                                               selector:_cmd        \
                                                                   line:__LINE__];  \
    [[AVSomethingWrong alloc] initWithCode:(code_)                                  \
                      localizedDescription:(localizedDescription_)                  \
                           underlyingError:(underlyingError_)                       \
                              codeLocation:codeLocation];                           \
})

#define _LC_ERROR0(code, localizedDescription)    \
    _LC_ERROR1(code, localizedDescription, nil)
