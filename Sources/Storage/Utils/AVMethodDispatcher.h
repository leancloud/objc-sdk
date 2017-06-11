//
//  AVMethodDispatcher.h
//  AVOS
//
//  Created by Tang Tianyong on 08/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Dispatch method call to an object.
 */
@interface AVMethodDispatcher : NSObject

/// The target that receives method call.
@property (nonatomic, strong, readonly) id target;

/// The method selector of target.
@property (nonatomic, assign, readonly) SEL selector;

/**
 Initialize dispatcher with target and selector.

 @param target   The target that receives method call.
 @param selector The method selector of target.

 @return An instance of method dispatcher.
 */
- (instancetype)initWithTarget:(id)target selector:(SEL)selector;

/**
 Call method with arguments in specified dispatch queue.

 You can specify nil in the argument list without exception.

 @param dispatchQueue  The dispatch queue in which method will be called.
 @param asynchronously A flag indicates whether the dispatch is asynchronous or not.
 @param argument       The first argument.
 @param vaList         A va_list.
 */
- (void)callInDispatchQueue:(dispatch_queue_t)dispatchQueue
             asynchronously:(BOOL)asynchronously
               withArgument:(id)argument
                     vaList:(va_list)vaList;

/**
 Call method with arguments in specified dispatch queue.

 You can specify nil in the argument list without exception.

 @param dispatchQueue  The dispatch queue in which method will be called.
 @param asynchronously A flag indicates whether the dispatch is asynchronous or not.
 @param argument1 The start of argument list.
 */
- (void)callInDispatchQueue:(dispatch_queue_t)dispatchQueue
             asynchronously:(BOOL)asynchronously
              withArguments:(id)argument1, ...;

/**
 Call method with arguments.

 @param argument The first argument.
 @param vaList   A va_list.
 */
- (void)callWithArgument:(id)argument
                  vaList:(va_list)vaList;

/**
 Call method with arguments.

 @param argument1 The start of argument list.
 */
- (void)callWithArguments:(id)argument1, ...;

@end
