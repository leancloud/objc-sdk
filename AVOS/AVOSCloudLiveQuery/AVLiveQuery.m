//
//  AVLiveQuery.m
//  AVOS
//
//  Created by Tang Tianyong on 15/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVLiveQuery.h"
#import "AVSubscriber.h"

#import "AVUser.h"
#import "AVQuery.h"

@implementation AVLiveQuery

- (instancetype)initWithQuery:(AVQuery *)query {
    self = [super init];

    if (self) {
        _query = query;
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
