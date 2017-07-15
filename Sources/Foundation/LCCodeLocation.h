//
//  LCCodeLocation.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 16/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 LCCodeLocation represents a location in source code.
 */
@interface LCCodeLocation : NSObject

@property (nonatomic,   copy, readonly) NSString *file;
@property (nonatomic, assign, readonly) SEL selector;
@property (nonatomic, assign, readonly) int line;

- (instancetype)initWithFile:(NSString *)file
                    selector:(SEL)selector
                        line:(int)line;

@end
