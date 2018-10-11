//
//  AVIMWebSocketWrapper.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVOSCloudIM.h"
#import "AVIMWebSocketWrapper.h"
#import "AVIMWebSocket.h"
#import "AVIMErrorUtil.h"
#import "AVIMCommon_Internal.h"
#import "AVIMClient_Internal.h"

#import "LCNetworkReachabilityManager.h"
#import "AVPaasClient.h"
#import "AVOSCloud_Internal.h"
#import "LCRouter_Internal.h"
#import "AVErrorUtils.h"
#import "AVUtils.h"

#import "AVIMGenericCommand+AVIMMessagesAdditions.h"
#import <TargetConditionals.h>

#define LCIM_OUT_COMMAND_LOG_FORMAT \
    @"\n\n" \
    @"------ BEGIN LeanCloud IM Out Command ------\n" \
    @"content: %@\n"                                  \
    @"------ END ---------------------------------\n" \
    @"\n"

#define LCIM_IN_COMMAND_LOG_FORMAT \
    @"\n\n" \
    @"------ BEGIN LeanCloud IM In Command ------\n" \
    @"content: %@\n"                                 \
    @"------ END --------------------------------\n" \
    @"\n"

// 180s
#define PingInterval (60.0 * 3.0)
// 20s
#define PingTimeout (PingInterval / 9.0)
// 10s
#define PingLeeway (PingTimeout / 2.0)

static NSTimeInterval AVIMWebSocketDefaultTimeoutInterval = 30.0;
static NSString * const AVIMProtocolPROTOBUF1 = @"lc.protobuf2.1";
static NSString * const AVIMProtocolPROTOBUF2 = @"lc.protobuf2.2";
static NSString * const AVIMProtocolPROTOBUF3 = @"lc.protobuf2.3";

// MARK: - LCIMProtobufCommandWrapper

@interface LCIMProtobufCommandWrapper () {
    NSError *_error;
    BOOL _hasDecodedError;
}

@property (nonatomic, copy) void (^callback)(LCIMProtobufCommandWrapper *commandWrapper);
@property (nonatomic, assign) uint16_t index;
@property (nonatomic, assign) NSTimeInterval deadlineTimestamp;

@end

@implementation LCIMProtobufCommandWrapper

- (instancetype)init
{
    self = [super init];
    if (self) {
        self->_hasDecodedError = false;
    }
    return self;
}

- (BOOL)hasCallback
{
    return self->_callback ? true : false;
}

- (void)executeCallbackAndSetItToNil
{
    if (self->_callback) {
        self->_callback(self);
        // set to nil to avoid cycle retain
        self->_callback = nil;
    }
}

- (void)setError:(NSError *)error
{
    self->_error = error;
}

- (NSError *)error
{
    if (self->_error) {
        return self->_error;
    }
    else if (self->_inCommand && !self->_hasDecodedError) {
        self->_hasDecodedError = true;
        self->_error = [self decodingError:self->_inCommand];
        return self->_error;
    }
    return nil;
}

- (NSError *)decodingError:(AVIMGenericCommand *)command
{
    int32_t code = 0;
    NSString *reason = nil;
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    
    AVIMErrorCommand *errorCommand = (command.hasErrorMessage ? command.errorMessage : nil);
    AVIMSessionCommand *sessionCommand = (command.hasSessionMessage ? command.sessionMessage : nil);
    AVIMAckCommand *ackCommand = (command.hasAckMessage ? command.ackMessage : nil);
    
    if (errorCommand && errorCommand.hasCode) {
        code = errorCommand.code;
        reason = (errorCommand.hasReason ? errorCommand.reason : nil);
        if (errorCommand.hasAppCode) {
            userInfo[keyPath(errorCommand, appCode)] = @(errorCommand.appCode);
        }
        if (errorCommand.hasDetail) {
            userInfo[keyPath(errorCommand, detail)] = errorCommand.detail;
        }
    }
    else if (sessionCommand && sessionCommand.hasCode) {
        code = sessionCommand.code;
        reason = (sessionCommand.hasReason ? sessionCommand.reason : nil);
        if (sessionCommand.hasDetail) {
            userInfo[keyPath(sessionCommand, detail)] = sessionCommand.detail;
        }
    }
    else if (ackCommand && ackCommand.hasCode) {
        code = ackCommand.code;
        reason = (ackCommand.hasReason ? ackCommand.reason : nil);
        if (ackCommand.hasAppCode) {
            userInfo[keyPath(ackCommand, appCode)] = @(ackCommand.appCode);
        }
    }
    
    return (code > 0) ? LCError(code, reason, userInfo) : nil;
}

@end

// MARK: - AVIMWebSocketWrapper

@interface AVIMWebSocketWrapper () <AVIMWebSocketDelegate>

@property (atomic, assign) BOOL isApplicationInBackground;
@property (atomic, assign) AFNetworkReachabilityStatus currentNetworkReachabilityStatus;

@end

@implementation AVIMWebSocketWrapper {
    
    __weak id<AVIMWebSocketWrapperDelegate> _delegate;
    
    NSTimeInterval _commandTimeToLive;
    uint16_t _serialIndex;
    BOOL _activatingReconnection;
    BOOL _useSecondaryServer;
    
    NSMutableArray<void (^)(BOOL, NSError *)> *_openCallbacks;
    NSMutableDictionary<NSNumber *, LCIMProtobufCommandWrapper *> *_commandWrapperMap;
    NSMutableArray<NSNumber *> *_serialIndexArray;
    
    dispatch_queue_t _internalSerialQueue;
    
    dispatch_source_t _pingSenderTimerSource;
    NSTimeInterval _lastPingTimestamp;
    NSTimeInterval _lastPingSenderEventTimestamp;
    BOOL _didReceivePong;
    
    dispatch_source_t _timeoutCheckerTimerSource;
    
    AVIMWebSocket *_websocket;
    LCNetworkReachabilityManager *_reachabilityMonitor;
    BOOL _didInitNetworkReachabilityStatus;
}

+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds
{
    if (seconds > 0) {
        AVIMWebSocketDefaultTimeoutInterval = seconds;
    }
}

- (instancetype)initWithDelegate:(id<AVIMWebSocketWrapperDelegate>)delegate
{
    self = [super init];
    if (self) {
#if DEBUG
        NSParameterAssert([delegate respondsToSelector:@selector(webSocketWrapper:didReceiveCommand:)]);
        NSParameterAssert([delegate respondsToSelector:@selector(webSocketWrapper:didReceiveCommandCallback:)]);
        NSParameterAssert([delegate respondsToSelector:@selector(webSocketWrapper:didCommandEncounterError:)]);
#endif
        self->_delegate = delegate;
        self->_commandTimeToLive = AVIMWebSocketDefaultTimeoutInterval;
        self->_serialIndex = 1;
        self->_activatingReconnection = false;
        self->_useSecondaryServer = false;
        
        self->_openCallbacks = nil;
        self->_commandWrapperMap = [NSMutableDictionary dictionary];
        self->_serialIndexArray = [NSMutableArray array];
        
        self->_internalSerialQueue = ({
            NSString *className = NSStringFromClass(self.class);
            NSString *ivarName = ivarName(self, _internalSerialQueue);
            NSString *label = [NSString stringWithFormat:@"%@.%@", className, ivarName];
            dispatch_queue_t queue = dispatch_queue_create(label.UTF8String, DISPATCH_QUEUE_SERIAL);
#ifdef DEBUG
            void *key = (__bridge void *)queue;
            dispatch_queue_set_specific(queue, key, key, NULL);
#endif
            queue;
        });
        
        self->_pingSenderTimerSource = nil;
        self->_lastPingSenderEventTimestamp = 0;
        self->_lastPingTimestamp = 0;
        self->_didReceivePong = false;
        
        self->_timeoutCheckerTimerSource = nil;
        
        self->_websocket = nil;
        
#if TARGET_OS_IOS
        self->_isApplicationInBackground = (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground);
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
#endif
        
        __weak typeof(self) weakSelf = self;
        self->_reachabilityMonitor = [LCNetworkReachabilityManager manager];
        // this is not real init for Network Reachability Status, but need it to handle follow-up event.
        self->_currentNetworkReachabilityStatus = AFNetworkReachabilityStatusUnknown;
        self->_didInitNetworkReachabilityStatus = false;
        [self->_reachabilityMonitor setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            AVIMWebSocketWrapper *strongSelf = weakSelf;
            if (!strongSelf) { return; }
            AVLoggerInfo(AVLoggerDomainIM, @"<websocket wrapper address: %p> network reachability status: %@.", strongSelf, @(status));
            AFNetworkReachabilityStatus oldStatus = strongSelf.currentNetworkReachabilityStatus;
            strongSelf.currentNetworkReachabilityStatus = status;
            if (strongSelf->_didInitNetworkReachabilityStatus) {
                if (status == oldStatus) {
                    // should dealt with status as state machine.
                    // so if the status not changed, do nothing.
                    // ref: https://github.com/ashleymills/Reachability.swift/issues/95#issuecomment-229401474
                } else if (status == AFNetworkReachabilityStatusNotReachable) {
                    [strongSelf addOperationToInternalSerialQueue:^(AVIMWebSocketWrapper *websocketWrapper) {
                        [websocketWrapper internalClose];
                        if (websocketWrapper->_activatingReconnection) {
                            id<AVIMWebSocketWrapperDelegate> delegate = websocketWrapper->_delegate;
                            if ([delegate respondsToSelector:@selector(webSocketWrapperDidPause:)]) {
                                [delegate webSocketWrapperDidPause:websocketWrapper];
                            }
                        }
                    }];
                } else {
                    [strongSelf addOperationToInternalSerialQueue:^(AVIMWebSocketWrapper *websocketWrapper) {
                        [websocketWrapper tryReconnecting];
                    }];
                }
            } else {
                strongSelf->_didInitNetworkReachabilityStatus = true;
            }
        }];
        [self->_reachabilityMonitor startMonitoring];
    }
    return self;
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self->_reachabilityMonitor stopMonitoring];
}

// MARK: - Application Notification

#if TARGET_OS_IOS
- (void)applicationDidEnterBackground
{
    AVLoggerInfo(AVLoggerDomainIM, @"<websocket wrapper address: %p> application did enter background.", self);
    [self handleApplicationStateIsInBackground:true];
}

- (void)applicationWillEnterForeground
{
    AVLoggerInfo(AVLoggerDomainIM, @"<websocket wrapper address: %p> application will enter foreground.", self);
    [self handleApplicationStateIsInBackground:false];
}

- (void)handleApplicationStateIsInBackground:(BOOL)isInBackground
{
    BOOL newStatus = isInBackground;
    BOOL oldStatus = self.isApplicationInBackground;
    self.isApplicationInBackground = newStatus;
    if (newStatus != oldStatus) {
        [self addOperationToInternalSerialQueue:^(AVIMWebSocketWrapper *websocketWrapper) {
            if (isInBackground) {
                [websocketWrapper internalClose];
                if (websocketWrapper->_activatingReconnection) {
                    id<AVIMWebSocketWrapperDelegate> delegate = websocketWrapper->_delegate;
                    if ([delegate respondsToSelector:@selector(webSocketWrapperDidPause:)]) {
                        [delegate webSocketWrapperDidPause:websocketWrapper];
                    }
                }
            } else {
                [websocketWrapper tryReconnecting];
            }
        }];
    }
}
#endif

// MARK: - Open & Close

static NSArray<NSString *> * RTMProtocols()
{
    NSMutableSet<NSString *> *protocols = [NSMutableSet set];
    NSDictionary *userOptions = [AVIMClient sessionProtocolOptions];
    NSNumber *useUnread = [NSNumber lc__decodingDictionary:userOptions key:kAVIMUserOptionUseUnread];
    if (useUnread.boolValue) {
        [protocols addObject:AVIMProtocolPROTOBUF3];
    } else {
        [protocols addObject:AVIMProtocolPROTOBUF1];
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArray *customProtocols = [NSArray lc__decodingDictionary:userOptions key:AVIMUserOptionCustomProtocols];
    if (customProtocols) {
        [protocols removeAllObjects];
        for (NSString *protocol in customProtocols) {
            if ([NSString lc__checkingType:protocol]) {
                [protocols addObject:protocol];
            }
        }
    }
#pragma clang diagnostic pop
    return protocols.allObjects;
}

- (void)openWithCallback:(void (^)(BOOL succeeded, NSError *error))callback
{
    [self addOperationToInternalSerialQueue:^(AVIMWebSocketWrapper *websocketWrapper) {
        websocketWrapper->_activatingReconnection = true;
        AVIMWebSocket *websocket = websocketWrapper->_websocket;
        if (websocket && websocket.readyState == AVIMWebSocketStateConnected) {
            callback(true, nil);
        } else {
            [websocketWrapper internalOpenWithCallback:callback delegateBlock:nil];
        }
    }];
}

- (void)internalOpenWithCallback:(void (^)(BOOL succeeded, NSError *error))callback
                   delegateBlock:(void (^)(void))delegateBlock
{
    AssertRunInQueue(self->_internalSerialQueue);
    if (self->_openCallbacks) {
        [self->_openCallbacks addObject:callback];
    } else {
        self->_openCallbacks = [NSMutableArray arrayWithObject:callback];
        [self purgeWithError:({
            AVIMErrorCode code = AVIMErrorCodeConnectionLost;
            LCError(code, AVIMErrorMessage(code), nil);
        })];
        if (delegateBlock) { delegateBlock(); }
        [self getRTMServerWithCallback:^(NSString *server, NSError *error) {
            AssertRunInQueue(self->_internalSerialQueue);
            NSAssert(self->_websocket == nil, @"wrapper's websocket should be nil.");
            if (self.isApplicationInBackground) {
                [self invokeOpenCallbacksWithSucceeded:false error:LCErrorInternal(@"websocket can't open when application in background.")];
                return;
            }
            if (self.currentNetworkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
                [self invokeOpenCallbacksWithSucceeded:false error:LCErrorInternal(@"websocket can't open when network not reachable.")];
                return;
            }
            if (error) {
                if ([error.domain isEqualToString:kLeanCloudErrorDomain]) {
                    self->_activatingReconnection = false;
                }
                [self invokeOpenCallbacksWithSucceeded:false error:error];
            } else if (self->_openCallbacks) {
                NSParameterAssert(server);
                NSArray<NSString *> *protocols = RTMProtocols();
                NSURL *URL = [NSURL URLWithString:server];
                if (protocols.count > 0) {
                    self->_websocket = [[AVIMWebSocket alloc] initWithURL:URL protocols:protocols];
                } else {
                    self->_websocket = [[AVIMWebSocket alloc] initWithURL:URL];
                }
                [self->_websocket setDelegateDispatchQueue:self->_internalSerialQueue];
                [self->_websocket setDelegate:self];
                AVLoggerInfo(AVLoggerDomainIM, @"<address: %p> websocket open with URL: %@, protocols: %@.", self->_websocket, URL, protocols);
                [self->_websocket open];
            } else { /* do nothing */ }
        }];
    }
}

- (void)invokeOpenCallbacksWithSucceeded:(BOOL)succeeded error:(NSError *)error
{
    AssertRunInQueue(self->_internalSerialQueue);
    NSMutableArray<void (^)(BOOL, NSError *)> *openCallbacks = self->_openCallbacks;
    for (void (^openCallback)(BOOL, NSError *) in openCallbacks) {
        openCallback(succeeded, error);
    }
    self->_openCallbacks = nil;
}

- (void)close
{
    [self addOperationToInternalSerialQueue:^(AVIMWebSocketWrapper *websocketWrapper) {
        websocketWrapper->_activatingReconnection = false;
        [websocketWrapper internalClose];
    }];
}

- (void)internalClose
{
    AssertRunInQueue(self->_internalSerialQueue);
    NSError *error = ({
        AVIMErrorCode code = AVIMErrorCodeConnectionLost;
        LCError(code, AVIMErrorMessage(code), nil);
    });
    [self purgeWithError:error];
    [self invokeOpenCallbacksWithSucceeded:false error:error];
}

// MARK: - Websocket Open & Close Notification

- (void)webSocketDidOpen:(AVIMWebSocket *)webSocket
{
    AssertRunInQueue(self->_internalSerialQueue);
    NSParameterAssert(webSocket == self->_websocket);
    NSAssert(self->_openCallbacks, @"wrapper's open callbacks should not be nil.");
    AVLoggerInfo(AVLoggerDomainIM, @"<address: %p> websocket did open.", webSocket);
    [self startPingSender];
    [self startTimeoutChecker];
    [self invokeOpenCallbacksWithSucceeded:true error:nil];
}

- (void)webSocket:(AVIMWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    // handle close by remote.
    AssertRunInQueue(self->_internalSerialQueue);
    NSParameterAssert(webSocket == self->_websocket);
    NSError *error = [NSError errorWithDomain:AVIMWebSocketErrorDomain code:code userInfo:({
        NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
        if (reason) { mutableDictionary[@"reason"] = reason; }
        mutableDictionary[@"wasClean"] = @(wasClean);
        mutableDictionary;
    })];
    AVLoggerError(AVLoggerDomainIM, @"<address: %p> websocket did close by remote with error: %@.", webSocket, error);
    self->_activatingReconnection = false;
    [self purgeWithError:error];
    if (self->_openCallbacks) {
        [self invokeOpenCallbacksWithSucceeded:false error:error];
    } else {
        id<AVIMWebSocketWrapperDelegate> delegate = self->_delegate;
        if ([delegate respondsToSelector:@selector(webSocketWrapper:didCloseWithError:)]) {
            [delegate webSocketWrapper:self didCloseWithError:error];
        }
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didFailWithError:(NSError *)error
{
    AssertRunInQueue(self->_internalSerialQueue);
    NSParameterAssert(webSocket == self->_websocket);
    AVLoggerError(AVLoggerDomainIM, @"<address: %p> websocket did encounter error: %@.", webSocket, error);
    [self purgeWithError:error];
    if ([error.domain isEqualToString:AVIMWebSocketErrorDomain] && (error.code == 2132 || error.code == 2133)) {
        // failed in upgrading HTTP protocol to the WebSocket protocol.
        self->_useSecondaryServer = !self->_useSecondaryServer;
    }
    if (self->_openCallbacks) {
        [self invokeOpenCallbacksWithSucceeded:false error:error];
    } else {
        id<AVIMWebSocketWrapperDelegate> delegate = self->_delegate;
        if ([delegate respondsToSelector:@selector(webSocketWrapperDidPause:)]) {
            [delegate webSocketWrapperDidPause:self];
        }
    }
}

// MARK: - Command Send & Receive

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueue:^(AVIMWebSocketWrapper *websocketWrapper) {
        if (!commandWrapper || !commandWrapper.outCommand) {
            return;
        }
        AVIMWebSocket *webSocket = websocketWrapper->_websocket;
        id<AVIMWebSocketWrapperDelegate> delegate = websocketWrapper->_delegate;
        if (!webSocket || webSocket.readyState != AVIMWebSocketStateConnected) {
            commandWrapper.error = ({
                AVIMErrorCode code = AVIMErrorCodeConnectionLost;
                LCError(code, AVIMErrorMessage(code), nil);
            });
            [delegate webSocketWrapper:websocketWrapper didCommandEncounterError:commandWrapper];
            return;
        }
        if ([commandWrapper hasCallback]) {
            uint16_t index = [websocketWrapper serialIndex];
            commandWrapper.index = index;
            commandWrapper.outCommand.i = index;
        }
        NSData *data = [commandWrapper.outCommand data];
        if (data.length > 5000) {
            commandWrapper.error = ({
                AVIMErrorCode code = AVIMErrorCodeCommandDataLengthTooLong;
                LCError(code, AVIMErrorMessage(code), nil);
            });
            [delegate webSocketWrapper:websocketWrapper didCommandEncounterError:commandWrapper];
            return;
        }
        if (commandWrapper.index) {
            commandWrapper.deadlineTimestamp = NSDate.date.timeIntervalSince1970 + websocketWrapper->_commandTimeToLive;
            NSNumber *index = @(commandWrapper.index);
            websocketWrapper->_commandWrapperMap[index] = commandWrapper;
            [websocketWrapper->_serialIndexArray addObject:index];
        }
        AVLoggerInfo(AVLoggerDomainIM, LCIM_OUT_COMMAND_LOG_FORMAT, [commandWrapper.outCommand avim_description]);
        [webSocket send:data];
    }];
}

- (void)webSocket:(AVIMWebSocket *)webSocket didReceiveMessage:(id)message
{
    AssertRunInQueue(self->_internalSerialQueue);
    AVIMGenericCommand *inCommand = ({
        NSError *error = nil;
        AVIMGenericCommand *inCommand = [AVIMGenericCommand parseFromData:message error:&error];
        if (!inCommand) {
            AVLoggerError(AVLoggerDomainIM, @"did receive message with error: %@", error);
            return;
        }
        inCommand;
    });
    AVLoggerInfo(AVLoggerDomainIM, LCIM_IN_COMMAND_LOG_FORMAT, [inCommand avim_description]);
    id<AVIMWebSocketWrapperDelegate> delegate = self->_delegate;
    if (inCommand.hasI && inCommand.i > 0) {
        NSNumber *index = @(inCommand.i);
        LCIMProtobufCommandWrapper *commandWrapper = self->_commandWrapperMap[index];
        if (commandWrapper) {
            [self->_commandWrapperMap removeObjectForKey:index];
            [self->_serialIndexArray removeObject:index];
            commandWrapper.inCommand = inCommand;
            [delegate webSocketWrapper:self didReceiveCommandCallback:commandWrapper];
        }
    } else {
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.inCommand = inCommand;
        [delegate webSocketWrapper:self didReceiveCommand:commandWrapper];
    }
}

// MARK: - Ping Sender

- (void)startPingSender
{
    AssertRunInQueue(self->_internalSerialQueue);
    [self tryStopPingSender];
    self->_pingSenderTimerSource = [self newTimerWithInterval:PingInterval leeway:PingLeeway immediate:true event:^{
        AssertRunInQueue(self->_internalSerialQueue);
        self->_didReceivePong = false;
        self->_lastPingSenderEventTimestamp = NSDate.date.timeIntervalSince1970;
        [self sendPing];
    }];
    dispatch_resume(self->_pingSenderTimerSource);
}

- (void)tryStopPingSender
{
    AssertRunInQueue(self->_internalSerialQueue);
    if (self->_pingSenderTimerSource) {
        dispatch_source_cancel(self->_pingSenderTimerSource);
        self->_pingSenderTimerSource = nil;
        self->_lastPingTimestamp = 0;
        self->_lastPingSenderEventTimestamp = 0;
        self->_didReceivePong = false;
    }
}

- (void)sendPing
{
    AssertRunInQueue(self->_internalSerialQueue);
    AVIMWebSocket *websocket = self->_websocket;
    if (!websocket || websocket.readyState != AVIMWebSocketStateConnected) {
        return;
    }
    AVLoggerInfo(AVLoggerDomainIM, @"<address: %p> websocket send ping.", websocket);
    self->_lastPingTimestamp = NSDate.date.timeIntervalSince1970;
    [websocket sendPing:[@"" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)webSocket:(AVIMWebSocket *)webSocket didReceivePong:(id)data
{
    AssertRunInQueue(self->_internalSerialQueue);
    AVLoggerInfo(AVLoggerDomainIM, @"<address: %p> websocket did receive pong.", webSocket);
    self->_didReceivePong = true;
}

// MARK: - Timeout Checker

- (void)startTimeoutChecker
{
    AssertRunInQueue(self->_internalSerialQueue);
    [self tryStopTimeoutChecker];
    self->_timeoutCheckerTimerSource = [self newTimerWithInterval:1 leeway:1 immediate:false event:^{
        AssertRunInQueue(self->_internalSerialQueue);
        [self checkTimeout];
    }];
    dispatch_resume(self->_timeoutCheckerTimerSource);
}

- (void)tryStopTimeoutChecker
{
    AssertRunInQueue(self->_internalSerialQueue);
    if (self->_timeoutCheckerTimerSource) {
        dispatch_source_cancel(self->_timeoutCheckerTimerSource);
        self->_timeoutCheckerTimerSource = nil;
    }
}

- (void)checkTimeout
{
    AssertRunInQueue(self->_internalSerialQueue);
    NSTimeInterval currentTimestamp = NSDate.date.timeIntervalSince1970;
    /// check ping
    if (!self->_didReceivePong && (self->_lastPingTimestamp > 0) && (self->_lastPingSenderEventTimestamp > 0)) {
        NSTimeInterval lastPingTimestamp = self->_lastPingTimestamp;
        NSTimeInterval lastPingSenderEventTimestamp = self->_lastPingSenderEventTimestamp;
        BOOL inRange = ({
            BOOL left = (lastPingTimestamp >= lastPingSenderEventTimestamp);
            BOOL right = (lastPingTimestamp <= (lastPingSenderEventTimestamp + (PingInterval / 2)));
            (left && right);
        });
        if (inRange && (currentTimestamp >= (lastPingTimestamp + PingTimeout))) {
            [self sendPing];
        }
    }
    /// check command
    NSMutableArray<NSNumber *> *timeoutIndexes = [NSMutableArray array];
    for (NSNumber *number in self->_serialIndexArray) {
        LCIMProtobufCommandWrapper *commandWrapper = self->_commandWrapperMap[number];
        if (!commandWrapper) {
            [timeoutIndexes addObject:number];
            continue;
        }
        if (currentTimestamp > commandWrapper.deadlineTimestamp) {
            [timeoutIndexes addObject:number];
            id<AVIMWebSocketWrapperDelegate> delegate = self->_delegate;
            if (delegate) {
                commandWrapper.error = ({
                    AVIMErrorCode code = AVIMErrorCodeCommandTimeout;
                    LCError(code, AVIMErrorMessage(code), nil);
                });
                [delegate webSocketWrapper:self didCommandEncounterError:commandWrapper];
            }
        } else {
            break;
        }
    }
    if (timeoutIndexes.count > 0) {
        [self->_commandWrapperMap removeObjectsForKeys:timeoutIndexes];
        [self->_serialIndexArray removeObjectsInArray:timeoutIndexes];
    }
}

// MARK: - Misc

- (void)addOperationToInternalSerialQueue:(void (^)(AVIMWebSocketWrapper *websocketWrapper))block
{
    dispatch_async(self->_internalSerialQueue, ^{
        block(self);
    });
}

- (void)tryReconnecting
{
    AssertRunInQueue(self->_internalSerialQueue);
    if (!self->_activatingReconnection) { return; }
    AVLoggerInfo(AVLoggerDomainIM, @"<websocket wrapper address: %p> try reconnecting.", self);
    id<AVIMWebSocketWrapperDelegate> delegate = self->_delegate;
    [self internalOpenWithCallback:^(BOOL succeeded, NSError *error) {
        AssertRunInQueue(self->_internalSerialQueue);
        if (error) {
            if (self->_activatingReconnection) {
                if ([delegate respondsToSelector:@selector(webSocketWrapperDidPause:)]) {
                    [delegate webSocketWrapperDidPause:self];
                }
            } else {
                if ([delegate respondsToSelector:@selector(webSocketWrapper:didCloseWithError:)]) {
                    [delegate webSocketWrapper:self didCloseWithError:error];
                }
            }
        } else {
            if ([delegate respondsToSelector:@selector(webSocketWrapperDidReopen:)]) {
                [delegate webSocketWrapperDidReopen:self];
            }
        }
    } delegateBlock:^{
        AssertRunInQueue(self->_internalSerialQueue);
        if ([delegate respondsToSelector:@selector(webSocketWrapperInReconnecting:)]) {
            [delegate webSocketWrapperInReconnecting:self];
        }
    }];
}

- (void)getRTMServerWithCallback:(void (^)(NSString *server, NSError *error))callback
{
    AssertRunInQueue(self->_internalSerialQueue);
    NSString *customRTMServer = AVOSCloudIM.defaultOptions.RTMServer;
    if (customRTMServer) {
        callback(customRTMServer, nil);
    } else {
        [LCRouter.sharedInstance getRTMURLWithAppID:[AVOSCloud getApplicationId] callback:^(NSDictionary *dictionary, NSError *error) {
            [self addOperationToInternalSerialQueue:^(AVIMWebSocketWrapper *websocketWrapper) {
                if (error) {
                    callback(nil, error);
                } else {
                    NSString *primaryServer = [NSString lc__decodingDictionary:dictionary key:RouterKeyRTMServer];
                    NSString *secondaryServer = [NSString lc__decodingDictionary:dictionary key:RouterKeyRTMSecondary];
                    if (primaryServer && secondaryServer) {
                        NSString *server = (websocketWrapper->_useSecondaryServer ? secondaryServer : primaryServer);
                        callback(server, nil);
                    } else {
                        callback(nil, LCErrorInternal(@"RTM router response invalid."));
                    }
                }
            }];
        }];
    }
}

- (void)purgeWithError:(NSError *)error
{
    AssertRunInQueue(self->_internalSerialQueue);
    // discard websocket
    if (self->_websocket) {
        AVLoggerInfo(AVLoggerDomainIM, @"<address: %p> websocket discard.", self->_websocket);
        [self->_websocket setDelegate:nil];
        [self->_websocket close];
        self->_websocket = nil;
    }
    // reset ping sender
    [self tryStopPingSender];
    // stop timeout checker
    [self tryStopTimeoutChecker];
    // purge command
    id<AVIMWebSocketWrapperDelegate> delegate = self->_delegate;
    for (NSNumber *number in self->_serialIndexArray) {
        LCIMProtobufCommandWrapper *commandWrapper = self->_commandWrapperMap[number];
        if (commandWrapper && delegate) {
            commandWrapper.error = error;
            [delegate webSocketWrapper:self didCommandEncounterError:commandWrapper];
        }
    }
    [self->_serialIndexArray removeAllObjects];
    [self->_commandWrapperMap removeAllObjects];
}

- (dispatch_source_t)newTimerWithInterval:(uint64_t)interval leeway:(uint64_t)leeway immediate:(BOOL)immediate event:(dispatch_block_t)event
{
    AssertRunInQueue(self->_internalSerialQueue);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self->_internalSerialQueue);
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, (immediate ? 0 : interval) * NSEC_PER_SEC);
    dispatch_source_set_timer(timer, start, interval * NSEC_PER_SEC, leeway * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, event);
    return timer;
}

- (uint16_t)serialIndex
{
    AssertRunInQueue(self->_internalSerialQueue);
    self->_serialIndex = (self->_serialIndex == 0) ? 1 : self->_serialIndex;
    uint16_t result = self->_serialIndex;
    self->_serialIndex = (self->_serialIndex + 1) % (UINT16_MAX + 1);
    return result;
}

@end
