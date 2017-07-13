//
//  AVConnection.h
//  AVOS
//
//  Created by Tang Tianyong on 09/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVNamedTable.h"
#import "AVApplication.h"

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
 This class defines some options which can tune up behaviors of connection.
 */
@interface AVConnectionOptions : AVNamedTable

@end

@interface AVConnection : NSObject

@property (nonatomic, strong, readonly) AVApplication *application;
@property (nonatomic,   copy, readonly) AVConnectionOptions *options;

/**
 Initialize connection with options.

 @param options The connection options.
 */
- (instancetype)initWithApplication:(AVApplication *)application
                            options:(AVConnectionOptions *)options;

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
 Keep connection alive.
 */
- (void)keepAlive;

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
