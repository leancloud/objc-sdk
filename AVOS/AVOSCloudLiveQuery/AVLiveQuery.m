//
//  AVLiveQuery.m
//  AVOS
//
//  Created by Tang Tianyong on 15/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVLiveQuery.h"

@implementation AVLiveQuery

- (instancetype)initWithQuery:(AVQuery *)query
                      options:(AVLiveQueryOptions *)options
{
    self = [super init];

    if (self) {
        _query = query;
        _options = options;
    }

    return self;
}

- (void)subscribeWithCallback:(AVBooleanResultBlock)callback {
    /* TODO */
}

- (void)unsubscribeWithCallback:(AVBooleanResultBlock)callback {
    /* TODO */
}

@end
