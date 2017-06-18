//
//  AVApplication.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 18/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVApplication.h"
#import "AVApplication+Internal.h"

@implementation AVApplication

- (instancetype)init {
    self = [super init];

    if (self) {
        [self doInitialize];
    }

    return self;
}

- (instancetype)initWithID:(NSString *)ID key:(NSString *)key {
    self = [self init];

    if (self) {
        _ID = [ID copy];
        _key = [key copy];
    }

    return self;
}

- (void)doInitialize {
    _environment = @"production";
}

@end
