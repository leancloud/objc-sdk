//
//  CDPopMenuItem.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/30/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDPopMenuItem.h"

@implementation CDPopMenuItem

- (instancetype)initWithImage:(UIImage *)image title:(NSString *)title {
    self = [super init];
    if (self) {
        self.image = image;
        self.title = title;
    }
    return self;
}

@end
