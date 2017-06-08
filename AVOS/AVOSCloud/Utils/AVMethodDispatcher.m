//
//  AVMethodDispatcher.m
//  AVOS
//
//  Created by Tang Tianyong on 08/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVMethodDispatcher.h"

@implementation AVMethodDispatcher

- (instancetype)initWithTarget:(id)target selector:(SEL)selector {
    self = [super init];

    if (self) {
        _target = target;
        _selector = selector;
    }

    return self;
}

- (void)callWithArguments:(NSArray *)arguments
          inDispatchQueue:(dispatch_queue_t)dispatchQueue
            asyncronously:(BOOL)asyncronously
{
    if (!dispatchQueue)
        return;

    if (asyncronously) {
        dispatch_async(dispatchQueue, ^{
            [self callWithArguments:arguments];
        });
    } else {
        dispatch_sync(dispatchQueue, ^{
            [self callWithArguments:arguments];
        });
    }
}

- (void)callWithArguments:(NSArray *)arguments {
    id  target   = self.target;
    SEL selector = self.selector;

    if (!target)
        return;
    if (!selector)
        return;
    if (![target respondsToSelector:selector])
        return;

    NSMethodSignature *signature = [target methodSignatureForSelector:selector];

    if (!signature)
        return;

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

    invocation.target   = target;
    invocation.selector = selector;

    /* The first two arguments is already occupied by target itself and selector. */
    const NSInteger argumentStartIndex = 2;

    for (NSInteger i = 0, argc = arguments.count; i < argc; ++i) {
        id argument = arguments[i];
        NSInteger index = argumentStartIndex + i;

        [invocation setArgument:(void *)&argument atIndex:index];
    }

    [invocation invoke];
}

@end
