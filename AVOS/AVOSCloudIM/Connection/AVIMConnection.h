//
//  AVIMConnection.h
//  AVOS
//
//  Created by Tang Tianyong on 09/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVDynamicObject.h"

/**
 A protocol for handling connection events.
 */
@protocol AVIMConnectionDelegate <NSObject>

@end

/**
 A type defines an object that used to tune up behaviors of connection.
 */
@interface AVIMConnectionConfiguration: AVDynamicObject

@end

@interface AVIMConnection : NSObject

@property (nonatomic, copy, readonly) AVIMConnectionConfiguration *configuration;

/**
 Initialize connection with configuration.

 @param configuration The connection configuration.
 */
- (instancetype)initWithConfiguration:(AVIMConnectionConfiguration *)configuration;

/**
 Add a delegate for receiving events on connection.

 @note The delegate you passed in will be weakly held by connection.

 @param delegate The object to receive connection events.
 */
- (void)addDelegate:(id<AVIMConnectionDelegate>)delegate;

/**
 Remove a delegate that added previously.

 @param delegate The object you want to stop to receive connection events.
 */
- (void)removeDelegate:(id<AVIMConnectionDelegate>)delegate;

@end
