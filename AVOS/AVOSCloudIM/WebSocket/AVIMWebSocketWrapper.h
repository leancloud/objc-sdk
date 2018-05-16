//
//  AVIMWebSocketWrapper.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"
#import "AVIMCommandCommon.h"

@class AVIMWebSocketWrapper;
@class LCIMProtobufCommandWrapper;

#define AVIM_NOTIFICATION_WEBSOCKET_OPENED    @"AVIM_NOTIFICATION_WEBSOCKET_OPENED"
#define AVIM_NOTIFICATION_WEBSOCKET_CLOSED    @"AVIM_NOTIFICATION_WEBSOCKET_CLOSED"
#define AVIM_NOTIFICATION_WEBSOCKET_RECONNECT @"AVIM_NOTIFICATION_WEBSOCKET_RECONNECT"
#define AVIM_NOTIFICATION_WEBSOCKET_COMMAND   @"AVIM_NOTIFICATION_WEBSOCKET_COMMAND"

// MARK: - Delegate Protocol

@protocol AVIMWebSocketWrapperDelegate <NSObject>

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didReceiveCallback:(LCIMProtobufCommandWrapper *)commandWrapper;

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didReceiveCommand:(LCIMProtobufCommandWrapper *)commandWrapper;

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didOccurError:(LCIMProtobufCommandWrapper *)commandWrapper;

@end

// MARK: - Socket Wrapper

@interface AVIMWebSocketWrapper : NSObject

+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds;

+ (instancetype)newWithDelegate:(id <AVIMWebSocketWrapperDelegate>)delegate;

+ (instancetype)newByLiveQuery;

- (void)openWithCallback:(AVIMBooleanResultBlock)callback;

- (void)close;

- (void)sendCommand:(AVIMGenericCommand *)genericCommand;

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper;

@end

// MARK: - Data Wrapper

@interface LCIMProtobufCommandWrapper : NSObject

@property (nonatomic, strong) AVIMGenericCommand *outCommand;

@property (nonatomic, strong) AVIMGenericCommand *inCommand;

@property (nonatomic, strong) NSError *error;

- (void)setCallback:(void (^)(LCIMProtobufCommandWrapper *commandWrapper))callback;

- (BOOL)hasCallback;

- (void)executeCallbackAndSetItToNil;

@end
