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

 @param arguments      The arguments that will passed to method.
 @param dispatchQueue  The dispatch queue in which method will be called.
 @param asynchronously A flag indicates whether the dispatch is asynchronous or not.
 */
- (void)callWithArguments:(NSArray *)arguments
          inDispatchQueue:(dispatch_queue_t)dispatchQueue
            asyncronously:(BOOL)asyncronously;

/**
 Call method with arguments in main queue.

 @see <code>-[AVMethodDispatcher callWithArguments:inDispatchQueue:asyncronously:]</code>
 */
- (void)callInMainQueueWithArguments:(NSArray *)arguments
                       asyncronously:(BOOL)asyncronously;

/**
 Call method with arguments.
 */
- (void)callWithArguments:(NSArray *)arguments;

@end
