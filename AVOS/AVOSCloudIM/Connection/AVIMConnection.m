//
//  AVIMConnection.m
//  AVOS
//
//  Created by Tang Tianyong on 09/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVIMConnection.h"

@interface AVIMConnection ()

@property (nonatomic, strong) NSHashTable *delegates;

@end

@implementation AVIMConnection

+ (instancetype)sharedInstance {
    static AVIMConnection *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        [self doInitialize];
    }

    return self;
}

- (void)doInitialize {
    _delegates = [NSHashTable weakObjectsHashTable];
}

- (void)addDelegate:(id<AVIMConnectionDelegate>)delegate {
    [_delegates addObject:delegate];
}

- (void)removeDelegate:(id<AVIMConnectionDelegate>)delegate {
    [_delegates removeObject:delegate];
}

@end
