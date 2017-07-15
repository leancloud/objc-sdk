//
//  AVSomethingWrong+Internal.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 15/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVSomethingWrong.h"

@interface AVSomethingWrong (Internal)

/**
 Initialize error with code, description, and an optional underlying error.
 */
- (instancetype)initWithCode:(AVSomethingWrongCode)code
        localizedDescription:(NSString *)localizedDescription
             underlyingError:(NSError *)underlyingError;

@end
