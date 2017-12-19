//
//  AVIMWebSocketWrapper.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"
#import "AVIMCommandCommon.h"

#define AVIM_NOTIFICATION_WEBSOCKET_OPENED    @"AVIM_NOTIFICATION_WEBSOCKET_OPENED"
#define AVIM_NOTIFICATION_WEBSOCKET_CLOSED    @"AVIM_NOTIFICATION_WEBSOCKET_CLOSED"
#define AVIM_NOTIFICATION_WEBSOCKET_RECONNECT @"AVIM_NOTIFICATION_WEBSOCKET_RECONNECT"
#define AVIM_NOTIFICATION_WEBSOCKET_ERROR     @"AVIM_NOTIFICATION_WEBSOCKET_ERROR"
#define AVIM_NOTIFICATION_WEBSOCKET_COMMAND   @"AVIM_NOTIFICATION_WEBSOCKET_COMMAND"

@interface AVIMWebSocketWrapper : NSObject

+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds;

- (void)openWithCallback:(AVIMBooleanResultBlock)callback;

- (void)close;

- (void)sendCommand:(AVIMGenericCommand *)genericCommand;

@end
