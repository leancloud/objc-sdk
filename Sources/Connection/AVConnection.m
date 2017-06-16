//
//  AVConnection.m
//  AVOS
//
//  Created by Tang Tianyong on 09/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVConnection.h"
#import "AVMethodDispatcher.h"
#import "SRWebSocket.h"

@interface AVConnection ()

@property (nonatomic, strong) SRWebSocket *webSocket;
@property (nonatomic,   copy) id<AVConnectionConfigurable> configuration;
@property (nonatomic, strong) NSHashTable *delegates;

@end

@implementation AVConnection

- (instancetype)init {
    self = [super init];

    if (self) {
        [self doInitialize];
    }

    return self;
}

- (instancetype)initWithConfiguration:(id<AVConnectionConfigurable>)configuration {
    self = [self init];

    if (self) {
        _configuration = [configuration copyWithZone:nil];
    }

    return self;
}

- (void)doInitialize {
    _delegates = [NSHashTable weakObjectsHashTable];
}

- (void)addDelegate:(id<AVConnectionDelegate>)delegate {
    @synchronized(_delegates) {
        [_delegates addObject:delegate];
    }
}

- (void)removeDelegate:(id<AVConnectionDelegate>)delegate {
    @synchronized(_delegates) {
        [_delegates removeObject:delegate];
    }
}

- (void)callDelegateMethod:(SEL)selector
             withArguments:(id)argument1, ...
{
    NSArray *delegates = nil;

    /* NOTE: We convert the hash table to an array
             to avoid some quirks of hash table. */
    @synchronized(_delegates) {
        delegates = [_delegates allObjects];
    }

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

- (void)keepAlive {
    /* TODO */
}

- (void)sendFrame:(id<AVConnectionFrame>)frame {
    /* TODO */
}

- (void)close {
    /* TODO */
}

@end
