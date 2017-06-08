//
//  AVMethodDispatcher.m
//  AVOS
//
//  Created by Tang Tianyong on 08/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVMethodDispatcher.h"

static id nilPlaceholder;

@implementation AVMethodDispatcher

+ (void)initialize {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        [self doInitialize];
    });
}

+ (void)doInitialize {
    nilPlaceholder = [[NSObject alloc] init];
}

- (instancetype)initWithTarget:(id)target selector:(SEL)selector {
    self = [super init];

    if (self) {
        _target   = target;
        _selector = selector;
    }

    return self;
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

        if (argument == nilPlaceholder)
            continue;

        NSInteger index = argumentStartIndex + i;

        [invocation setArgument:(void *)&argument
                        atIndex:index];
    }

    [invocation invoke];
}

- (NSArray *)argumentsFromVaList:(va_list)list
                           arity:(NSInteger)arity
{
    NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:arity];

    for (NSInteger i = 0; i < arity; i++) {
        id argument = va_arg(list, id) ?: nilPlaceholder;
        [arguments addObject:argument];
    }

    return arguments;
}

- (void)callInDispatchQueue:(dispatch_queue_t)dispatchQueue
             asynchronously:(BOOL)asynchronously
              withArguments:(NSArray *)arguments
{
    if (!dispatchQueue)
        return;

    if (asynchronously) {
        dispatch_async(dispatchQueue, ^{
            [self callWithArguments:arguments];
        });
    } else {
        dispatch_sync(dispatchQueue, ^{
            [self callWithArguments:arguments];
        });
    }
}

- (void)callInDispatchQueue:(dispatch_queue_t)dispatchQueue
             asynchronously:(BOOL)asynchronously
                  withArity:(NSInteger)arity
                  arguments:(id)argument1, ...
{
    va_list args;
    va_start(args, argument1);

    [self callInDispatchQueue:dispatchQueue
               asynchronously:asynchronously
                    withArity:arity
                         args:args];

    va_end(args);
}

- (void)callInDispatchQueue:(dispatch_queue_t)dispatchQueue
             asynchronously:(BOOL)asynchronously
                  withArity:(NSInteger)arity
                       args:(va_list)args
{
    NSArray *arguments = [self argumentsFromVaList:args arity:arity];

    [self callInDispatchQueue:dispatchQueue
               asynchronously:asynchronously
                withArguments:arguments];
}

- (void)callWithArity:(NSInteger)arity
            arguments:(id)argument1, ...
{
    va_list args;
    va_start(args, argument1);

    [self callWithArity:arity args:args];

    va_end(args);
}

- (void)callWithArity:(NSInteger)arity
                 args:(va_list)args
{
    NSArray *arguments = [self argumentsFromVaList:args arity:arity];

    [self callWithArguments:arguments];
}

@end
