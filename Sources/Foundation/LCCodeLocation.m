//
//  LCCodeLocation.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 16/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCCodeLocation.h"

@implementation LCCodeLocation

- (instancetype)initWithFile:(NSString *)file
                    selector:(SEL)selector
                        line:(int)line
{
    self = [super init];

    if (self) {
        _file = [file copy];
        _selector = selector;
        _line = line;
    }

    return self;
}

@end
