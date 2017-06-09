//
//  AVIMConnection.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"
#import "AVIMCommandCommon.h"

FOUNDATION_EXPORT NSString *const AVIMProtocolPROTOBUF1;
FOUNDATION_EXPORT NSString *const AVIMProtocolPROTOBUF2;
FOUNDATION_EXPORT NSString *const AVIMProtocolPROTOBUF3;

@class AVIMConnection;

@protocol AVIMConnectionDelegate <NSObject>

- (void)connectionDidOpen:(AVIMConnection *)connection;
- (void)connection:(AVIMConnection *)connection didReceiveCommand:(AVIMGenericCommand *)command;
- (void)connection:(AVIMConnection *)connection didReceiveError:(NSError *)error;
- (void)connection:(AVIMConnection *)connection didCloseWithError:(NSError *)error;
- (void)connectionDidReconnect:(AVIMConnection *)connection;

@end

@interface AVIMConnection : NSObject

@property(nonatomic, assign) CGFloat timeout;

+ (instancetype)sharedInstance;

/**
 Set the default timeout interval.

 @param seconds Timeout length, in seconds.
 */
+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds;

/**
 Add a delegate for receiving connection events.

 @note The connection object will weakly hold the delegate.

 @param delegate The object to receive connection events.
 */
- (void)addDelegate:(id<AVIMConnectionDelegate>)delegate;

/**
 Remove a delegate that added previously.

 @param delegate The previously added delegate.
 */
- (void)removeDelegate:(id<AVIMConnectionDelegate>)delegate;

- (void)openWithCallback:(AVIMBooleanResultBlock)callback;

- (void)sendCommand:(AVIMGenericCommand *)genericCommand;

- (BOOL)isOpen;

@end
