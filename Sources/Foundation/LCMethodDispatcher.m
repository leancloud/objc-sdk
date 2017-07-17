//
//  LCMethodDispatcher.m
//  AVOS
//
//  Created by Tang Tianyong on 08/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCMethodDispatcher.h"

static const NSInteger LCArgumentOffset = 2;

@interface LCMethodArgument : NSObject

@property (nonatomic, assign, readonly) void *data;

@property (nonatomic, strong) id        objectValue;
@property (nonatomic, assign) int64_t   int64Value;
@property (nonatomic, assign) uint64_t  uint64Value;
@property (nonatomic, assign) double    doubleValue;
@property (nonatomic, assign) BOOL      booleanValue;
@property (nonatomic, assign) void *    pointerValue;

@end

@implementation LCMethodArgument

- (void)setObjectValue:(id)objectValue {
    _objectValue = objectValue;
    _data = &_objectValue;
}

- (void)setInt64Value:(int64_t)int64Value {
    _int64Value = int64Value;
    _data = &_int64Value;
}

- (void)setUint64Value:(uint64_t)uint64Value {
    _uint64Value = uint64Value;
    _data = &_uint64Value;
}

- (void)setDoubleValue:(double)doubleValue {
    _doubleValue = doubleValue;
    _data = &_doubleValue;
}

- (void)setBooleanValue:(BOOL)booleanValue {
    _booleanValue = booleanValue;
    _data = &_booleanValue;
}

- (void)setPointerValue:(void *)pointerValue {
    _pointerValue = pointerValue;
    _data = &_pointerValue;
}

@end

@interface LCMethodDispatcher ()

@property (nonatomic, assign, readonly) NSInteger arity;
@property (nonatomic, strong, readonly) NSMethodSignature *signature;

@end

@implementation LCMethodDispatcher

- (instancetype)initWithTarget:(id)target selector:(SEL)selector {
    self = [super init];

    if (self) {
        _target   = target;
        _selector = selector;
        _signature = [target methodSignatureForSelector:selector];
    }

    return self;
}

- (NSInteger)arity {
    NSArray *components = [NSStringFromSelector(self.selector) componentsSeparatedByString:@":"];
    return [components count] - 1;
}

- (LCMethodArgument *)getArgumentFromVaList:(va_list)vaList
                                    atIndex:(NSInteger)index
{
    LCMethodArgument *argument = [[LCMethodArgument alloc] init];
    const char *type = [self.signature getArgumentTypeAtIndex:index + LCArgumentOffset];

    switch (type[0]) {
    case 'c':
    case 'i':
    case 's':
    case 'l':
    case 'q':
    case 'B':
        argument.int64Value = va_arg(vaList, int64_t);
        break;
    case 'C':
    case 'I':
    case 'S':
    case 'L':
    case 'Q':
    case '*':
        argument.uint64Value = va_arg(vaList, uint64_t);
        break;
    case 'f':
    case 'd':
        argument.doubleValue = va_arg(vaList, double);
        break;
    case '@':
    case '#':
        argument.objectValue = va_arg(vaList, id);
        break;
    }

    return argument;
}

- (NSArray<LCMethodArgument *> *)getArgumentsFromVaList:(va_list)vaList
                                                  start:(void *)start
{
    NSInteger arity = self.arity;
    NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:arity];

    if (!arity)
        return arguments;

    LCMethodArgument *firstArgument = [[LCMethodArgument alloc] init];
    firstArgument.pointerValue = start;

    [arguments addObject:firstArgument];

    va_list args;
    va_copy(args, vaList);

    for (NSInteger i = 1; i < arity; i++) {
        LCMethodArgument *argument = [self getArgumentFromVaList:args atIndex:i];
        [arguments addObject:argument];
    }

    va_end(args);

    return arguments;
}

- (void)callInDispatchQueue:(dispatch_queue_t)dispatchQueue
             asynchronously:(BOOL)asynchronously
               withArgument:(void *)argument
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
              withArguments:(void *)argument1, ...
{
    va_list args;
    va_start(args, argument1);

    [self callInDispatchQueue:dispatchQueue
               asynchronously:asynchronously
                 withArgument:argument1
                       vaList:args];

    va_end(args);
}

- (void)callWithArgument:(void *)argument
                  vaList:(va_list)vaList
{
    id  target   = self.target;
    SEL selector = self.selector;
    NSMethodSignature *signature = self.signature;

    if (!target)
        return;
    if (!selector)
        return;
    if (!signature)
        return;

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

    invocation.target   = target;
    invocation.selector = selector;

    NSInteger index = LCArgumentOffset;
    NSArray<LCMethodArgument *> *arguments = [self getArgumentsFromVaList:vaList start:argument];

    for (LCMethodArgument *argument in arguments) {
        [invocation setArgument:argument.data atIndex:index++];
    }

    [invocation invoke];
}

- (void)callWithArguments:(void *)argument1, ... {
    va_list args;
    va_start(args, argument1);

    [self callWithArgument:argument1 vaList:args];

    va_end(args);
}

@end
