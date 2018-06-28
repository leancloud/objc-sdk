//
//  AVIMWebSocketWrapper.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMWebSocketWrapper.h"
#import "AVIMWebSocket.h"
#import "LCNetworkReachabilityManager.h"
#import "AVIMErrorUtil.h"
#import "AVIMBlockHelper.h"
#import "AVIMClient_Internal.h"
#import "AVIMUserOptions.h"
#import "AVPaasClient.h"
#import "AVOSCloud_Internal.h"
#import "LCRouter.h"
#import "SDMacros.h"
#import "AVOSCloudIM.h"
#import "AVIMConversation_Internal.h"
#import "AVErrorUtils.h"
#import "AVUtils.h"
#import <arpa/inet.h>

#define PING_INTERVAL (60 * 3)
#define TIMEOUT_CHECK_INTERVAL (1.0)

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

#if DEBUG
#define AssertRunInSerialQueue assert(dispatch_get_specific(_serialQueue_specific_key) == _serialQueue_specific_value)
#else
#define AssertRunInSerialQueue
#endif

static NSTimeInterval AVIMWebSocketDefaultTimeoutInterval = 30.0;

NSString *const AVIMProtocolPROTOBUF1 = @"lc.protobuf2.1";
NSString *const AVIMProtocolPROTOBUF2 = @"lc.protobuf2.2";
NSString *const AVIMProtocolPROTOBUF3 = @"lc.protobuf2.3";

// MARK: - LCIMProtobufCommandWrapper

@interface LCIMProtobufCommandWrapper () {
    
    NSError *_error;
    BOOL _hasDecodedError;
}

@property (nonatomic, copy) void (^callback)(LCIMProtobufCommandWrapper *commandWrapper);

@property (nonatomic, assign) uint16_t serialId;

@property (nonatomic, assign) NSTimeInterval timeoutDeadlineTimestamp;

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
        /*
         set to nil to avoid cycle retain
         */
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

// MARK: - AVIMCommandCarrier

@interface AVIMCommandCarrier : NSObject

@property(nonatomic, strong) AVIMGenericCommand *command;
@property(nonatomic, assign) NSTimeInterval timeoutDeadlineTimestamp;

@end

@implementation AVIMCommandCarrier

- (void)timeoutInSeconds:(NSTimeInterval)seconds
{
    NSTimeInterval currentTimestamp = [NSDate.date timeIntervalSince1970];
    
    _timeoutDeadlineTimestamp = currentTimestamp + seconds;
}

@end

// MARK: - AVIMWebSocketWrapper

@interface AVIMWebSocketWrapper () <AVIMWebSocketDelegate>
{
    __weak id <AVIMWebSocketWrapperDelegate> _delegate;
    
    NSTimeInterval _timeout;
    
    BOOL _invokedOpenOnce;
    
    uint16_t _searialId;
    
    BOOL _isApplicationEnterBackground;
    
    /*
     RTM Server
     */
    BOOL _isGettingRTMServer;
    BOOL _preferToUseSecondaryRTMServer;
    
    /*
     Ping & Pong
     */
    dispatch_source_t _pingTimerSource;
    NSTimeInterval _lastPingTimestamp;
    int _countOfSendPingWithoutReceivePong;
    
    /*
     Reconnect
     */
    BOOL _needReconnect;
    NSTimeInterval _reconnectInterval;
    dispatch_block_t _reconnectBlock;
    
    /*
     Check Timeout
     */
    dispatch_source_t _checkTimeoutTimerSource;
    
    /**
     Internal Serial Queue
     */
    dispatch_queue_t _serialQueue;
#ifdef DEBUG
    void *_serialQueue_specific_key;
    void *_serialQueue_specific_value;
#endif
    
    /*
     Container
     */
    NSMutableArray<AVIMBooleanResultBlock> *_openCallbackArray;
    NSMutableDictionary<NSNumber *, AVIMCommandCarrier *> *_commandDictionary;
    NSMutableDictionary<NSNumber *, LCIMProtobufCommandWrapper *> *_commandWrapperDic;
    NSMutableArray<NSNumber *> *_serialIdArray;
    
    AVIMWebSocket *_webSocket;
    
    LCNetworkReachabilityManager *_reachabilityMonitor;
    AFNetworkReachabilityStatus _oldNetworkReachabilityStatus;
}

@property (nonatomic, strong, readonly) dispatch_queue_t serialQueue;

@end

@implementation AVIMWebSocketWrapper

+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds
{
    if (seconds > 0) {
        
        AVIMWebSocketDefaultTimeoutInterval = seconds;
    }
}

+ (instancetype)newWithDelegate:(id<AVIMWebSocketWrapperDelegate>)delegate
{
    return [[self alloc] initWithDelegate:delegate];
}

+ (instancetype)newByLiveQuery
{
    return [[self alloc] initByLiveQuery];
}

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _timeout = AVIMWebSocketDefaultTimeoutInterval;
        
        _invokedOpenOnce = false;
        
        _searialId = 0;
        
#if TARGET_OS_IOS
        _isApplicationEnterBackground = (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground);
#endif
        
        /*
         Serial Queue
         */
        _serialQueue = dispatch_queue_create("AVIMWebSocketWrapper._serialQueue", NULL);
#ifdef DEBUG
        _serialQueue_specific_key = (__bridge void *)_serialQueue;
        _serialQueue_specific_value = (__bridge void *)_serialQueue;
        dispatch_queue_set_specific(_serialQueue,
                                    _serialQueue_specific_key,
                                    _serialQueue_specific_value,
                                    NULL);
#endif
        
        /*
         Container
         */
        _openCallbackArray = [NSMutableArray array];
        _serialIdArray = [NSMutableArray array];
        _commandDictionary = [NSMutableDictionary dictionary];
        _commandWrapperDic = [NSMutableDictionary dictionary];
        
        /*
         Ping & Pong
         */
        _pingTimerSource = nil;
        _lastPingTimestamp = -1;
        _countOfSendPingWithoutReceivePong = 0;
        
        /*
         Check Timeout
         */
        _checkTimeoutTimerSource = nil;
        
        /*
         Reconnect
         */
        _needReconnect = false;
        _reconnectInterval = 1;
        _reconnectBlock = nil;
        
        /*
         RTM Server
         */
        _isGettingRTMServer = false;
        _preferToUseSecondaryRTMServer = false;
        
        _webSocket = nil;
    }
    
    return self;
}

- (instancetype)initByLiveQuery
{
    self = [self init];
    
    if (self) {
        
        [self setupObserverAndReachabilityMonitor];
    }
    
    return self;
}

- (instancetype)initWithDelegate:(id<AVIMWebSocketWrapperDelegate>)delegate
{
    self = [self init];
    
    if (self) {
        
        _delegate = delegate;
        
        [self setupObserverAndReachabilityMonitor];
    }
    
    return self;
}

- (void)setupObserverAndReachabilityMonitor
{
#if TARGET_OS_IOS
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self
               selector:@selector(applicationDidEnterBackground)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(applicationWillEnterForeground)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];
#endif
    
    _reachabilityMonitor = [LCNetworkReachabilityManager manager];
    
    _oldNetworkReachabilityStatus = AFNetworkReachabilityStatusUnknown;
    
    __weak typeof(self) weakSelf = self;
    
    [_reachabilityMonitor setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus newStatus) {
        
        __strong AVIMWebSocketWrapper *strongSelf = weakSelf;
        
        if (strongSelf == nil) {
            
            return;
        }
        
        dispatch_async(strongSelf.serialQueue, ^{
            
            [strongSelf handleReachabilityWithNewStatus:newStatus];
        });
    }];
    
    [_reachabilityMonitor startMonitoring];
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

// MARK: - Application Notification

#if TARGET_OS_IOS

- (void)applicationDidEnterBackground
{
    dispatch_async(_serialQueue, ^{
        
        _isApplicationEnterBackground = true;
        
        if (_invokedOpenOnce) {
            
            [self _closeWithBlockAfterClose:^{
                
                NSError *aError = ({
                    AVIMErrorCode code = AVIMErrorCodeConnectionLost;
                    LCError(code, AVIMErrorMessage(code), nil);
                });
                
                if (_openCallbackArray.count > 0) {
                    
                    [self invokeAllOpenCallbackWithSuccess:false
                                                     error:aError];
                    
                } else {
                    
                    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
                    
                    NSDictionary *userInfo = @{
                                               @"error" : aError,
                                               @"willReconnect" : @(true)
                                               };
                    
                    [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                                          object:self
                                        userInfo:userInfo];
                }
            }];
        }
    });
}

- (void)applicationWillEnterForeground
{
    dispatch_async(_serialQueue, ^{
        
        _isApplicationEnterBackground = false;
        
        if (_invokedOpenOnce) {
            
            [self _openWithCallback:nil blockBeforeOpen:^{
                
                NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
                
                [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT
                                      object:self];
            }];
        }
    });
}

#endif

// MARK: - Reachability

- (void)handleReachabilityWithNewStatus:(AFNetworkReachabilityStatus)newStatus
{
    AssertRunInSerialQueue;
    
    /*
     Should ignore Unknown Status
     */
    
    AFNetworkReachabilityStatus oldStatus = _oldNetworkReachabilityStatus;
    
    BOOL isOldStatusNormal = (
                              (oldStatus == AFNetworkReachabilityStatusReachableViaWWAN) ||
                              (oldStatus == AFNetworkReachabilityStatusReachableViaWiFi)
                              );
    
    BOOL isOldStatusNotReachable = (oldStatus == AFNetworkReachabilityStatusNotReachable);
    
    BOOL isNewStatusNormal = (
                              (newStatus == AFNetworkReachabilityStatusReachableViaWWAN) ||
                              (newStatus == AFNetworkReachabilityStatusReachableViaWiFi)
                              );
    
    BOOL isNewStatusNotReachable = (newStatus == AFNetworkReachabilityStatusNotReachable);
    
    if (isNewStatusNormal && isOldStatusNotReachable) {
        
        /*
         Status change from `NotReachable` to `Reachable`
         */
        
        _oldNetworkReachabilityStatus = newStatus;
        
        if (_invokedOpenOnce) {
            
            [self _openWithCallback:nil blockBeforeOpen:^{
                
                NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
                
                [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT
                                      object:self];
            }];
        }
        
    } else if (isNewStatusNotReachable && isOldStatusNormal) {
        
        /*
         Status change from `Reachable` to `NotReachable`
         */
        _oldNetworkReachabilityStatus = newStatus;
        
        if (_invokedOpenOnce) {
            
            [self _closeWithBlockAfterClose:^{
                
                NSError *aError = ({
                    AVIMErrorCode code = AVIMErrorCodeConnectionLost;
                    LCError(code, AVIMErrorMessage(code), nil);
                });
                
                if (_openCallbackArray.count > 0) {
                    
                    [self invokeAllOpenCallbackWithSuccess:false
                                                     error:aError];
                    
                } else {

                    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
                    
                    NSDictionary *userInfo = @{
                                               @"error" : aError,
                                               @"willReconnect" : @(true)
                                               };
                    
                    [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                                          object:self
                                        userInfo:userInfo];
                }
            }];
        }
        
    } else if (isNewStatusNormal && isOldStatusNormal) {
        
        /*
         Status change from `Reachable` to `Reachable`
         */
        
        _oldNetworkReachabilityStatus = newStatus;
    }
    
    if (_oldNetworkReachabilityStatus == AFNetworkReachabilityStatusUnknown &&
        newStatus != AFNetworkReachabilityStatusUnknown) {
        
        /*
         Init with a valid status.
         */
        
        _oldNetworkReachabilityStatus = newStatus;
    }
}

// MARK: - Open WebSocket

- (void)openWithCallback:(AVIMBooleanResultBlock)callback
{
    dispatch_async(self->_serialQueue, ^{
        
        if (self->_isApplicationEnterBackground ||
            self->_oldNetworkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
            NSError *error = ({
                AVIMErrorCode code = AVIMErrorCodeConnectionLost;
                LCError(code, AVIMErrorMessage(code), nil);
            });
            callback(false, error);
            return;
        }
        
        self->_invokedOpenOnce = true;
        
        [self _openWithCallback:callback blockBeforeOpen:nil];
    });
}

- (void)_openWithCallback:(AVIMBooleanResultBlock)callback
          blockBeforeOpen:(void(^)(void))block
{
    AssertRunInSerialQueue;
    
    [self cancelReconnectBlock];
    
    if (!_invokedOpenOnce ||
        _isApplicationEnterBackground ||
        _oldNetworkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
        
        return;
    }
    
    AVLoggerInfo(AVLoggerDomainIM, @"Start Open Websocket Connection.");
    
    AVIMWebSocket *webSocket = _webSocket;
    
    if (webSocket) {
        
        AVIMWebSocketState readyState = webSocket.readyState;
        
        if (readyState == AVIMWebSocketStateConnected) {
            
            if (callback) {
                
                callback(true, nil);
            }
            
            return;
        }
        
        if (readyState == AVIMWebSocketStateConnecting) {
            
            if (callback && [_openCallbackArray containsObject:callback] == false) {
                
                [_openCallbackArray addObject:callback];
            }
            
            return;
        }
    }
    
    if (callback && [_openCallbackArray containsObject:callback] == false) {
        
        [_openCallbackArray addObject:callback];
    }
    
    if (block) { block(); }
    
    [self getRTMServerWithCallback:^(NSString *RTMServer, NSError *error){
        
        AssertRunInSerialQueue;
        
        _isGettingRTMServer = false;
        
        if (error) {
            
            if (_openCallbackArray.count > 0) {
                
                [self invokeAllOpenCallbackWithSuccess:false
                                                 error:error];
                
            } else {

                NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
                
                NSDictionary *userInfo = @{
                                           @"error" : error,
                                           @"willReconnect" : @(false)
                                           };
                
                [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                                      object:self
                                    userInfo:userInfo];
            }
            
            return;
        }
        
        [self newWebSocketAndConnectWithServer:RTMServer];
    }];
}

- (void)newWebSocketAndConnectWithServer:(NSString *)server
{
    AssertRunInSerialQueue;
    
    AVLoggerInfo(AVLoggerDomainIM, @"Opening WebSocket with URL: %@", server);
    
    if (_webSocket) {
        
        /*
         close old websocket
         */
        
        _webSocket.delegate = nil;
        
        [_webSocket close];
        
        _webSocket = nil;
    }
    
    NSMutableSet *protocols = [NSMutableSet set];
    NSDictionary *userOptions = [AVIMClient _userOptions];
    
    if ([userOptions[kAVIMUserOptionUseUnread] boolValue]) {
        
        [protocols addObject:AVIMProtocolPROTOBUF3];
        
    } else {
        
        [protocols addObject:AVIMProtocolPROTOBUF1];
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (userOptions[AVIMUserOptionCustomProtocols]) {
        
        [protocols removeAllObjects];
        
        [protocols addObjectsFromArray:userOptions[AVIMUserOptionCustomProtocols]];
    }
#pragma clang diagnostic pop
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:server]];
    
    AVIMWebSocket *webSocket = nil;
    
    if (protocols.count > 0) {
        
        webSocket = [[AVIMWebSocket alloc] initWithURLRequest:request protocols:[protocols allObjects]];
        
    } else {
        
        webSocket = [[AVIMWebSocket alloc] initWithURLRequest:request];
    }
    
    [webSocket setDelegateDispatchQueue:_serialQueue];
    webSocket.delegate = self;
    
    [webSocket open];
    
    _webSocket = webSocket;
}

// MARK: - Close WebSocket

- (void)close
{
    dispatch_async(_serialQueue, ^{

        /*
         Reset this to avoid reopen due to `Application Notification` or `Reachability`
         */
        _invokedOpenOnce = false;

        [self _closeWithBlockAfterClose:nil];
    });
}

- (void)_closeWithBlockAfterClose:(void(^)(void))block
{
    AssertRunInSerialQueue;
    
    AVLoggerInfo(AVLoggerDomainIM, @"Closing WebSocket Connection.");
    
    /*
     stop reconnect
     */
    [self cancelReconnectBlock];
    _needReconnect = false;
    _reconnectInterval = 1;
    
    /*
     stop ping timer
     */
    [self stopPingTimer];
    
    /*
     stop check timeout timer
     */
    [self stopCheckTimeoutTimer];
    
    /*
     close websocket
     */
    if (_webSocket) {
        
        _webSocket.delegate = nil;
        
        [_webSocket close];
        
        _webSocket = nil;
        
        if (block) { block(); }
    }
}

// MARK: - Send Command

- (void)sendCommand:(AVIMGenericCommand *)genericCommand
{
    dispatch_async(_serialQueue, ^{
        
        if (!genericCommand) {
            
            return;
        }
        
        AVIMCommandResultBlock callback = [genericCommand callback];
        
        BOOL needResponse = [genericCommand needResponse];
        
        AVIMWebSocket *webSocket = _webSocket;
        
        if (!webSocket ||
            webSocket.readyState != AVIMWebSocketStateConnected) {
            
            NSError *error = ({
                AVIMErrorCode code = AVIMErrorCodeConnectionLost;
                LCError(code, AVIMErrorMessage(code), nil);
            });
            
            if (callback) {
                
                callback(genericCommand, nil, error);
                
            } else {
                
                AVLoggerError(AVLoggerDomainIM, @"Command without Need Response is Dropped with Error: %@", error);
            }
            
            return;
        }
        
        if (needResponse) {
            
            /*
             Set `i` before generate data
             */
            
            genericCommand.i = [self nextSerialId];
        }
        
        NSData *data = [genericCommand data];
        
        if (data.length > 5000) {
            
            NSError *error = ({
                AVIMErrorCode code = AVIMErrorCodeCommandDataLengthTooLong;
                LCError(code, AVIMErrorMessage(code), nil);
            });
            
            if (callback) {
                
                callback(genericCommand, nil, error);
                
            } else {
                
                AVLoggerError(AVLoggerDomainIM, @"Out Command is not valid with Error: %@", error);
            }
            
            return;
        }
        
        if (needResponse) {

            AVIMCommandCarrier *carrier = [[AVIMCommandCarrier alloc] init];
            
            carrier.command = genericCommand;
            
            [carrier timeoutInSeconds:_timeout];
            
            NSNumber *num = @(genericCommand.i);
            
            [_commandDictionary setObject:carrier forKey:num];
            
            [_serialIdArray addObject:num];
            
        } else {
            
            if (callback) {
                
                callback(genericCommand, nil, nil);
            }
        }
        
        AVLoggerInfo(AVLoggerDomainIM, LCIM_OUT_COMMAND_LOG_FORMAT, [genericCommand avim_description]);
        
        [webSocket send:data];
    });
}

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper
{
    dispatch_async(_serialQueue, ^{
        
        if (!commandWrapper || !commandWrapper.outCommand) {
            
            return;
        }
        
        AVIMWebSocket *webSocket = _webSocket;
        
        if (!webSocket || webSocket.readyState != AVIMWebSocketStateConnected) {
            
            id <AVIMWebSocketWrapperDelegate> delegate = _delegate;
            
            if (delegate) {
                
                NSError *error = ({
                    AVIMErrorCode code = AVIMErrorCodeConnectionLost;
                    LCError(code, AVIMErrorMessage(code), nil);
                });
                
                commandWrapper.error = error;
                
                [delegate webSocketWrapper:self didOccurError:commandWrapper];
            }
            
            return;
        }
        
        if (commandWrapper.callback) {
            
            uint16_t serialId = [self nextSerialId];
            
            commandWrapper.serialId = serialId;
            
            commandWrapper.outCommand.i = serialId;
        }
        
        NSData *data = [commandWrapper.outCommand data];
        
        if (data.length > 5000) {
            
            id <AVIMWebSocketWrapperDelegate> delegate = _delegate;
            
            if (delegate) {
                
                NSError *error = ({
                    AVIMErrorCode code = AVIMErrorCodeCommandDataLengthTooLong;
                    LCError(code, AVIMErrorMessage(code), nil);
                });
                
                commandWrapper.error = error;
                
                [delegate webSocketWrapper:self didOccurError:commandWrapper];
            }
            
            return;
        }
        
        if (commandWrapper.serialId) {
            
            commandWrapper.timeoutDeadlineTimestamp = ({
                
                NSTimeInterval timestamp = NSDate.date.timeIntervalSince1970 + _timeout;
                
                timestamp;
            });
            
            _commandWrapperDic[@(commandWrapper.serialId)] = commandWrapper;
            
            [_serialIdArray addObject:@(commandWrapper.serialId)];
        }
        
        AVLoggerInfo(AVLoggerDomainIM, LCIM_OUT_COMMAND_LOG_FORMAT, [commandWrapper.outCommand avim_description]);
        
        [webSocket send:data];
    });
}

// MARK: - AVIMWebSocketDelegate

- (void)webSocketDidOpen:(AVIMWebSocket *)webSocket
{
    AssertRunInSerialQueue;
    
    AVLoggerInfo(AVLoggerDomainIM, @"Websocket Connection Opened.");
    
    /*
     open reconnect
     */
    _needReconnect = true;
    
    /*
     start ping timer
     */
    [self startPingTimer];
    
    /*
     start check timeout timer
     */
    [self startCheckTimeoutTimer];
    
    if (_openCallbackArray.count > 0) {
        
        [self invokeAllOpenCallbackWithSuccess:true
                                         error:nil];
        
    } else {
        
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        
        [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_OPENED
                              object:self];
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    AssertRunInSerialQueue;
    
    AVLoggerDebug(AVLoggerDomainIM, @"Websocket Closed with Code: %ld, Reason: %@, WasClean: %@.", (long)code, reason, @(wasClean));
    
    NSError *error = LCError(code, reason, nil);
    
    [self handleWebSocketClosedWithError:error];
    
    if (_openCallbackArray.count > 0) {
        
        [self invokeAllOpenCallbackWithSuccess:false
                                         error:error];
        
    } else {
        
        BOOL needReconnect = _needReconnect;
        
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        
        NSDictionary *userInfo = @{
                                   @"error" : error,
                                   @"willReconnect" : @(needReconnect)
                                   };
        
        [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                              object:self
                            userInfo:userInfo];
        
        if (needReconnect) {
            
            [self setupReconnectBlock];
        }
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didFailWithError:(NSError *)error
{
    AssertRunInSerialQueue;
    
    if (!error) {
        
        error = ({
            AVIMErrorCode code = AVIMErrorCodeConnectionLost;
            LCError(code, AVIMErrorMessage(code), nil);
        });
    }
    
    AVLoggerError(AVLoggerDomainIM, @"Websocket Open Failed with Error: %@", error);
    
    _preferToUseSecondaryRTMServer = !_preferToUseSecondaryRTMServer;
    
    [self handleWebSocketClosedWithError:error];
    
    if (_openCallbackArray.count > 0) {
        
        [self invokeAllOpenCallbackWithSuccess:false
                                         error:error];
        
    } else {
        
        BOOL needReconnect = _needReconnect;
        
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        
        NSDictionary *userInfo = @{
                                   @"error" : error,
                                   @"willReconnect" : @(needReconnect)
                                   };
        
        [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                              object:self
                            userInfo:userInfo];
        
        if (needReconnect) {
            
            [self setupReconnectBlock];
        }
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didReceiveMessage:(id)message
{
    AssertRunInSerialQueue;
    
    NSError *error = nil;
    
    /*
     message for server which is in accordance with protobuf protocol must be data type, there is no need to convert string to data.
     */
    AVIMGenericCommand *inCommand = [AVIMGenericCommand parseFromData:message
                                                                error:&error];
    
    if (!inCommand) {
        
        AVLoggerError(AVLoggerDomainIM, @"Not Handled Data with Error: %@", (error ?: @"nil"));
        
        return;
    }
    
    AVLoggerInfo(AVLoggerDomainIM, LCIM_IN_COMMAND_LOG_FORMAT, [inCommand avim_description]);
    
    void(^notifyCommand_block)(void) = ^(void) {
        
        [NSNotificationCenter.defaultCenter postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_COMMAND
                                                          object:self
                                                        userInfo:@{ @"command" : inCommand }];
    };
    
    if (inCommand.i > 0) {
        
        NSNumber *serialId = @(inCommand.i);
        
        AVIMGenericCommand *outCommand = ({
            
            AVIMGenericCommand *outCommand = nil;
            
            AVIMCommandCarrier *carrier = [_commandDictionary objectForKey:serialId];
            
            if (carrier) {
                
                [_commandDictionary removeObjectForKey:serialId];
                
                [_serialIdArray removeObject:serialId];
                
                outCommand = carrier.command;
            }
            
            outCommand;
        });
        
        if (outCommand) {
            
            NSError *inError = ({
                
                LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
                commandWrapper.outCommand = outCommand;
                commandWrapper.inCommand = inCommand;
                commandWrapper.error;
            });
            
            AVIMCommandResultBlock callback = outCommand.callback;
            
            if (callback) {
                
                callback(outCommand, inCommand, inError);
                
                /* 另外，对于情景：单点登录, 由于未上传 deviceToken 就 open，如果用户没有 force 登录，会报错,
                 详见 https://leanticket.cn/t/leancloud/925
                 
                 sessionMessage {
                 code: 4111
                 reason: "SESSION_CONFLICT"
                 }
                 这种情况不仅要告知用户登录失败，同时也要也要在 `-[AVIMClient processSessionCommand:]` 中统一进行异常处理，
                 触发代理方法 `-client:didOfflineWithError:` 告知用户需要将 force 设为 YES。
                 */
                if (inCommand.hasSessionMessage && inError) {
                    
                    notifyCommand_block();
                }
            } else {
                
                notifyCommand_block();
            }
        } else {
            
            LCIMProtobufCommandWrapper *commandWrapper = ({
                
                LCIMProtobufCommandWrapper *commandWrapper = _commandWrapperDic[serialId];
                
                if (commandWrapper) {
                    
                    [_commandWrapperDic removeObjectForKey:serialId];
                    
                    [_serialIdArray removeObject:serialId];
                }
                
                commandWrapper;
            });
            
            id <AVIMWebSocketWrapperDelegate> delegate = _delegate;
            
            if (commandWrapper && delegate) {
                
                commandWrapper.inCommand = inCommand;
                
                [delegate webSocketWrapper:self didReceiveCallback:commandWrapper];
            }
        }
    } else {
        
        notifyCommand_block();
        
        id <AVIMWebSocketWrapperDelegate> delegate = _delegate;
        
        if (delegate) {
            
            LCIMProtobufCommandWrapper *commandWrapper = ({
                
                LCIMProtobufCommandWrapper *commandWrapper = [[LCIMProtobufCommandWrapper alloc] init];
                
                commandWrapper.inCommand = inCommand;
                
                commandWrapper;
            });
            
            [delegate webSocketWrapper:self didReceiveCommand:commandWrapper];
        }
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didReceivePong:(id)data
{
    AssertRunInSerialQueue;
    
    AVLoggerInfo(AVLoggerDomainIM, @"Websocket Received Pong.");
    
    _countOfSendPingWithoutReceivePong = 0;
}

// MARK: - RTM Server

- (void)getRTMServerWithCallback:(void(^)(NSString *, NSError *))callback
{
    AssertRunInSerialQueue;
    
    if (_isGettingRTMServer) {
        
        return;
    }
    
    _isGettingRTMServer = true;
    
    NSString *RTMServer = AVOSCloudIM.defaultOptions.RTMServer;
    
    if (RTMServer) {
        
        callback(RTMServer, nil);
        
        return;
    }
    
    LCRouter *router = LCRouter.sharedInstance;
    
    NSDictionary *RTMServerTable = router.cachedRTMServerTable;
    
    if (RTMServerTable) {
        
        NSString *primary   = RTMServerTable[@"server"];
        
        NSString *secondary = RTMServerTable[@"secondary"];
        
        if (_preferToUseSecondaryRTMServer) {
            
            RTMServer = secondary ?: primary;
            
        } else {
            
            RTMServer = primary ?: secondary;
        }
        
        if (RTMServer) {
            
            callback(RTMServer, nil);
            
            return;
        }
    }
    
    [router fetchRTMServerTableInBackground:^(NSDictionary *RTMServerTable, NSError *error){
        
        dispatch_async(_serialQueue, ^{
            
            if (RTMServerTable) {
                
                _preferToUseSecondaryRTMServer = false;
                
                NSString *primary   = RTMServerTable[@"server"];
                
                NSString *secondary = RTMServerTable[@"secondary"];
                
                NSString *RTMServer = primary ?: secondary;
                
                if (RTMServer) {
                    
                    callback(RTMServer, nil);
                    
                    return;
                }
            }
            
            NSError *callbackError = nil;
            
            if (error) {
                
                callbackError = error;
                
            } else {
                
                NSString *reason = @"Unknown Error when fetching RTM Server Table.";
                
                callbackError = LCErrorInternal(reason);
            }
            
            callback(nil, callbackError);
        });
    }];
}

// MARK: - Reconnect

- (void)setupReconnectBlock
{
    AssertRunInSerialQueue;
    
    [self cancelReconnectBlock];
    
    __weak typeof(self) weakSelf = self;
    
    _reconnectBlock = dispatch_block_create(0, ^{
        
        AssertRunInSerialQueue;
    
        [weakSelf cancelReconnectBlock];
        
        [weakSelf _openWithCallback:nil blockBeforeOpen:nil];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_reconnectInterval * NSEC_PER_SEC)),
                   _serialQueue,
                   _reconnectBlock);
    
    _reconnectInterval = (_reconnectInterval * 2);
    
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    
    [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT
                          object:self];
}

- (void)cancelReconnectBlock
{
    AssertRunInSerialQueue;
    
    if (_reconnectBlock) {
        
        dispatch_block_cancel(_reconnectBlock);
        
        _reconnectBlock = nil;
    }
}

// MARK: - Ping Timer

- (void)stopPingTimer
{
    AssertRunInSerialQueue;
    
    if (_pingTimerSource) {
        
        dispatch_source_cancel(_pingTimerSource);
        
        _pingTimerSource = nil;
    }
    
    _lastPingTimestamp = -1;
    _countOfSendPingWithoutReceivePong = 0;
}

- (void)startPingTimer
{
    AssertRunInSerialQueue;
    
    [self stopPingTimer];
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_block_t eventHandler = ^{
        
        [weakSelf sendPing];
    };
    
    _pingTimerSource = [self newTimerSourceWithInterval:PING_INTERVAL
                                                 atOnce:true
                                           eventHandler:eventHandler];
}

- (void)sendPing
{
    AssertRunInSerialQueue;
    
    AVIMWebSocket *webSocket = _webSocket;
    
    if (!webSocket ||
        webSocket.readyState != AVIMWebSocketStateConnected) {
        
        return;
    }
    
    AVLoggerInfo(AVLoggerDomainIM, @"Websocket Send Ping.");
    
    _lastPingTimestamp = NSDate.date.timeIntervalSince1970;
    
    _countOfSendPingWithoutReceivePong += 1;
    
    NSData *pingData = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    
    [webSocket sendPing:pingData];
}

// MARK: - Check Timeout Timer

- (void)stopCheckTimeoutTimer
{
    AssertRunInSerialQueue;
    
    if (_checkTimeoutTimerSource) {
        
        dispatch_source_cancel(_checkTimeoutTimerSource);
        
        _checkTimeoutTimerSource = nil;
    }
}

- (void)startCheckTimeoutTimer
{
    AssertRunInSerialQueue;
    
    [self stopCheckTimeoutTimer];
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_block_t eventHandler = ^{
        
        [weakSelf checkTimeout];
    };
    
    _checkTimeoutTimerSource = [self newTimerSourceWithInterval:TIMEOUT_CHECK_INTERVAL
                                                         atOnce:false
                                                   eventHandler:eventHandler];
}

- (void)checkTimeout
{
    AssertRunInSerialQueue;
    
    NSTimeInterval currentTimestamp = NSDate.date.timeIntervalSince1970;
    
    if (_lastPingTimestamp > 0 &&
        _countOfSendPingWithoutReceivePong > 0 &&
        (currentTimestamp - _lastPingTimestamp) > _timeout) {
        
        if (_countOfSendPingWithoutReceivePong >= 3) {
            
            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            
            [self _closeWithBlockAfterClose:^{
                
                NSError *error = ({
                    AVIMErrorCode code = AVIMErrorCodeConnectionLost;
                    LCError(code, AVIMErrorMessage(code), nil);
                });
                
                NSDictionary *userInfo = @{
                                           @"error" : error,
                                           @"willReconnect" : @(true)
                                           };
                
                [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                                      object:self
                                    userInfo:userInfo];
            }];
            
            [self _openWithCallback:nil blockBeforeOpen:^{
                
                [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT
                                      object:self];
            }];
            
        } else {
            
            [self sendPing];
        }
    }
    
    NSMutableArray *timeoutIdArray1 = [NSMutableArray array];
    
    NSMutableArray *timeoutIdArray2 = [NSMutableArray array];
    
    for (NSNumber *num in _serialIdArray) {
        
        AVIMCommandCarrier *carrier = [_commandDictionary objectForKey:num];
        
        if (carrier) {
            
            if (currentTimestamp <= carrier.timeoutDeadlineTimestamp) {
                
                break;
            }
            
            [timeoutIdArray1 addObject:num];
            
            AVIMGenericCommand *command = carrier.command;
            
            AVIMCommandResultBlock callback = command.callback;
            
            if (callback) {
                NSError *error = ({
                    AVIMErrorCode code = AVIMErrorCodeCommandTimeout;
                    LCError(code, AVIMErrorMessage(code), nil);
                });
                callback(command, nil, error);
            }
        } else {
            
            LCIMProtobufCommandWrapper *commandWrapper = _commandWrapperDic[num];
            
            if (!commandWrapper) {
                
                [timeoutIdArray2 addObject:num];
                
                continue;
            }
            
            if (currentTimestamp <= commandWrapper.timeoutDeadlineTimestamp) {
                
                break;
            }
            
            [timeoutIdArray2 addObject:num];
            
            id <AVIMWebSocketWrapperDelegate> delegate = _delegate;
            
            if (delegate) {
                
                commandWrapper.error = ({
                    AVIMErrorCode code = AVIMErrorCodeCommandTimeout;
                    LCError(code, AVIMErrorMessage(code), nil);
                });
                
                [delegate webSocketWrapper:self didOccurError:commandWrapper];
            }
        }
    }
    
    [_commandDictionary removeObjectsForKeys:timeoutIdArray1];
    [_commandWrapperDic removeObjectsForKeys:timeoutIdArray2];
    [_serialIdArray removeObjectsInArray:[timeoutIdArray1 arrayByAddingObjectsFromArray:timeoutIdArray2]];
}

// MARK: - Misc

- (void)invokeAllOpenCallbackWithSuccess:(BOOL)success
                                   error:(NSError *)error
{
    AssertRunInSerialQueue;
    
    for (AVIMBooleanResultBlock block in _openCallbackArray) {
        
        block(success, error);
    }
    
    [_openCallbackArray removeAllObjects];
}

- (void)handleWebSocketClosedWithError:(NSError *)error
{
    AssertRunInSerialQueue;
    
    if (_webSocket) {
        
        /*
         Discard webSocket
         */
        
        _webSocket.delegate = nil;
        
        [_webSocket close];
        
        _webSocket = nil;
    }
    
    /*
     Stop Ping
     */
    [self stopPingTimer];
    
    /*
     Stop Check Timeout
     */
    [self stopCheckTimeoutTimer];
    
    /*
     Clear Queued Command
     */
    NSArray<AVIMCommandCarrier *> *allCarrierArray = [_commandDictionary allValues];
    
    for (AVIMCommandCarrier *carrier in allCarrierArray) {
        
        AVIMGenericCommand *outCommand = carrier.command;
        
        if (outCommand) {
            
            AVIMCommandResultBlock callback = [outCommand callback];
            
            if (callback) {
                
                callback(outCommand, nil, error);
            }
        }
    }
    
    id <AVIMWebSocketWrapperDelegate> delegate = _delegate;
    
    if (delegate) {
        
        NSArray<LCIMProtobufCommandWrapper *> *allCommandWrapper = [_commandWrapperDic allValues];
        
        for (LCIMProtobufCommandWrapper *item in allCommandWrapper) {
            
            item.error = error;
            
            [delegate webSocketWrapper:self didOccurError:item];
        }
    }
    
    [_commandDictionary removeAllObjects];
    [_commandWrapperDic removeAllObjects];
    [_serialIdArray removeAllObjects];
}

- (dispatch_source_t)newTimerSourceWithInterval:(NSTimeInterval)interval
                                         atOnce:(BOOL)atOnce
                                   eventHandler:(dispatch_block_t)eventHandler
{
    AssertRunInSerialQueue;
    
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _serialQueue);
    
    uint64_t _interval = interval * NSEC_PER_SEC;
    
    int64_t startDelay = atOnce ? 0 : (int64_t)_interval;
    
    dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, startDelay);
    
    dispatch_source_set_timer(source, startTime, _interval, 0);
    
    dispatch_source_set_event_handler(source, eventHandler);
    
    dispatch_resume(source);
    
    return source;
}

- (uint16_t)nextSerialId
{
    AssertRunInSerialQueue;
    
    if (_searialId == 0) {
        
        _searialId += 1;
    }
    
    uint16_t result = _searialId;
    
    _searialId = (_searialId + 1) % (UINT16_MAX + 1);
    
    return result;
}

@end
