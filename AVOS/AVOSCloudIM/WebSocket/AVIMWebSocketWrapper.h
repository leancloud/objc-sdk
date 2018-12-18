//
//  AVIMWebSocketWrapper.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"
#import "MessagesProtoOrig.pbobjc.h"

@class AVIMWebSocketWrapper;
@class LCIMProtobufCommandWrapper;

// MARK: - Delegate Protocol

@protocol AVIMWebSocketWrapperDelegate <NSObject>

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didReceiveCommandCallback:(LCIMProtobufCommandWrapper *)commandWrapper;
- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didReceiveCommand:(LCIMProtobufCommandWrapper *)commandWrapper;
- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didCommandEncounterError:(LCIMProtobufCommandWrapper *)commandWrapper;
@optional
- (void)webSocketWrapperInReconnecting:(AVIMWebSocketWrapper *)socketWrapper;
- (void)webSocketWrapperDidReopen:(AVIMWebSocketWrapper *)socketWrapper;
- (void)webSocketWrapperDidPause:(AVIMWebSocketWrapper *)socketWrapper;
- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didCloseWithError:(NSError *)error;

@end

// MARK: - Socket Wrapper

@interface AVIMWebSocketWrapper : NSObject

+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds;
- (instancetype)initWithDelegate:(id<AVIMWebSocketWrapperDelegate>)delegate;
- (void)openWithCallback:(void (^)(BOOL succeeded, NSError *error))callback;
- (void)setActivatingReconnectionEnabled:(BOOL)enabled;
- (void)close;
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
