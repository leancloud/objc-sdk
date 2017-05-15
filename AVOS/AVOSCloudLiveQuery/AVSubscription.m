//
//  AVSubscription.m
//  AVOS
//
//  Created by Tang Tianyong on 15/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVSubscription.h"

@implementation AVSubscription

- (instancetype)initWithQuery:(AVQuery *)query
                      options:(AVSubscriptionOptions *)options
{
    self = [super init];

    if (self) {
        _query = query;
        _options = options;
    }

    return self;
}

@end
