//
//  AVSomethingWrong.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 15/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AVSomethingWrongCode) {
    AVSomethingWrongCodeNotFound = 9527
};

FOUNDATION_EXPORT NSErrorDomain const AVSomethingWrongDomain;

/**
 An AVSomethingWrong object represents an error which you should handle.
 The class name is selected deliberately to avoid confliction with AVError namespace.
 */
@interface AVSomethingWrong : NSError

@end

NS_ASSUME_NONNULL_END
