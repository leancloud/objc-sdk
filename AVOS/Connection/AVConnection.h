//
//  AVConnection.h
//  AVOS
//
//  Created by Tang Tianyong on 09/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 A protocol defines a frame that can be sent by connection.
 */
@protocol AVConnectionFrame <NSObject>

@end

/**
 A protocol for handling connection events.
 */
@protocol AVConnectionDelegate <NSObject>

@end

/**
 A protocol defines an object that used to tune up behaviors of connection.
 */
@protocol AVConnectionConfigurable <NSObject, NSCopying>

@end

@interface AVConnection : NSObject

@property (nonatomic, copy, readonly) id<AVConnectionConfigurable> configuration;

/**
 Initialize connection with configuration.

 @param configuration The connection configuration.
 */
- (instancetype)initWithConfiguration:(id<AVConnectionConfigurable>)configuration;

/**
 Add a delegate for receiving events on connection.

 @note The delegate you passed in will be weakly held by connection.

 @param delegate The object to receive connection events.
 */
- (void)addDelegate:(id<AVConnectionDelegate>)delegate;

/**
 Remove a delegate that added previously.

 @param delegate The object you want to stop to receive connection events.
 */
- (void)removeDelegate:(id<AVConnectionDelegate>)delegate;

/**
 Send a frame to current connection.

 @param frame The frame you want to send.
 */
- (void)sendFrame:(id<AVConnectionFrame>)frame;

/**
 Close connection.
 */
- (void)close;

@end
