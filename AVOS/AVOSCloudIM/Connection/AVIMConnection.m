//
//  AVIMConnection.m
//  AVOS
//
//  Created by Tang Tianyong on 09/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVIMConnection.h"
#import "AVMethodDispatcher.h"

@implementation AVIMConnectionConfiguration

@end

@interface AVIMConnection ()

@property (nonatomic,   copy) AVIMConnectionConfiguration *configuration;
@property (nonatomic, strong) NSHashTable *delegates;

@end

@implementation AVIMConnection

- (instancetype)init {
    self = [super init];

    if (self) {
        [self doInitialize];
    }

    return self;
}

- (instancetype)initWithConfiguration:(AVIMConnectionConfiguration *)configuration {
    self = [self init];

    if (self) {
        _configuration = [configuration copy];
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

- (void)callDelegateMethod:(SEL)selector
             withArguments:(id)argument1, ...
{
    /* NOTE: We convert the hash table to an array
             to avoid some quirks of hash table. */
    NSArray *delegates = [self.delegates allObjects];

    if (!delegates.count)
        return;

    va_list args;
    va_start(args, argument1);

    for (id delegate in delegates) {
        AVMethodDispatcher *dispatcher = [[AVMethodDispatcher alloc] initWithTarget:delegate selector:selector];
        [dispatcher callWithArgument:argument1 vaList:args];
    }

    va_end(args);
}

@end
