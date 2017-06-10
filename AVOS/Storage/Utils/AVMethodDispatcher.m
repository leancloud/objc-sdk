//
//  AVMethodDispatcher.m
//  AVOS
//
//  Created by Tang Tianyong on 08/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVMethodDispatcher.h"

static id nilPlaceholder;

@interface AVMethodDispatcher ()

@property (nonatomic, assign, readonly) NSInteger arity;

@end

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

- (NSInteger)arity {
    NSArray *components = [NSStringFromSelector(self.selector) componentsSeparatedByString:@":"];
    return [components count] - 1;
}

- (NSArray *)arrayFromVaList:(va_list)vaList
                       start:(id)start
{
    NSInteger arity = self.arity;
    NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:arity];

    if (!arity)
        return arguments;

    id firstArgument = start ?: nilPlaceholder;

    [arguments addObject:firstArgument];

    va_list args;
    va_copy(args, vaList);

    for (NSInteger i = 0, size = arity - 1; i < size; i++) {
        id argument = va_arg(args, id) ?: nilPlaceholder;
        [arguments addObject:argument];
    }

    va_end(args);

    return arguments;
}

- (void)callInDispatchQueue:(dispatch_queue_t)dispatchQueue
             asynchronously:(BOOL)asynchronously
               withArgument:(id)argument
                     vaList:(va_list)vaList
{
    if (!dispatchQueue)
        return;

    if (asynchronously) {
        dispatch_async(dispatchQueue, ^{
            [self callWithArgument:argument vaList:vaList];
        });
    } else {
        dispatch_sync(dispatchQueue, ^{
            [self callWithArgument:argument vaList:vaList];
        });
    }
}

- (void)callInDispatchQueue:(dispatch_queue_t)dispatchQueue
             asynchronously:(BOOL)asynchronously
              withArguments:(id)argument1, ...
{
    va_list args;
    va_start(args, argument1);

    [self callInDispatchQueue:dispatchQueue
               asynchronously:asynchronously
                 withArgument:argument1
                       vaList:args];

    va_end(args);
}

- (void)callWithArgument:(id)argument
                  vaList:(va_list)vaList
{
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

    NSArray *arguments = [self arrayFromVaList:vaList start:argument];

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

- (void)callWithArguments:(id)argument1, ... {
    va_list args;
    va_start(args, argument1);

    [self callWithArgument:argument1 vaList:args];

    va_end(args);
}

@end
