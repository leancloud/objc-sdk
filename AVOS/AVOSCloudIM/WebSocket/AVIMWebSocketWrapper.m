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

#define AssertRunInSerialQueue NSAssert(dispatch_get_specific(_serialQueue_specific_key) == _serialQueue_specific_value, @"This internal method should run in `_serialQueue`.")

static NSTimeInterval AVIMWebSocketDefaultTimeoutInterval = 30.0;

NSString *const AVIMProtocolPROTOBUF1 = @"lc.protobuf2.1";
NSString *const AVIMProtocolPROTOBUF2 = @"lc.protobuf2.2";
NSString *const AVIMProtocolPROTOBUF3 = @"lc.protobuf2.3";

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

- (instancetype)init
{
    if (!AVOSCloud.getApplicationId) {
        
        [NSException raise:@"AVOSCloudIM Exception"
                    format:@"Application ID not found."];
    }
    
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
    
    return self;
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
                
                NSString *reason = @"Application is in Background.";
                
                NSDictionary *info = @{ @"reason" : reason };
                
                NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                      code:0
                                                  userInfo:info];
                
                if (_openCallbackArray.count > 0) {
                    
                    [self invokeAllOpenCallbackWithSuccess:false
                                                     error:aError];
                    
                } else {
                    
                    [self postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                                         error:aError];
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
                
                [self postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT
                                     error:nil];
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
                
                [self postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT
                                     error:nil];
            }];
        }
        
    } else if (isNewStatusNotReachable && isOldStatusNormal) {
        
        /*
         Status change from `Reachable` to `NotReachable`
         */
        _oldNetworkReachabilityStatus = newStatus;
        
        if (_invokedOpenOnce) {
            
            [self _closeWithBlockAfterClose:^{
                
                NSString *reason = @"Network is Not Reachable.";
                
                NSDictionary *info = @{ @"reason" : reason };
                
                NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                      code:0
                                                  userInfo:info];
                
                if (_openCallbackArray.count > 0) {
                    
                    [self invokeAllOpenCallbackWithSuccess:false
                                                     error:aError];
                    
                } else {
                    
                    [self postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                                         error:aError];
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
    dispatch_async(_serialQueue, ^{
        
        NSString *errReason = nil;
        
        if (_isApplicationEnterBackground) {
            
            errReason = @"Can't open WebSocket when Application in Background.";
            
        } else if (_oldNetworkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
            
            errReason = @"Can't open WebSocket when Network is Not Reachable.";
        }
        
        if (errReason) {
            
            NSDictionary *info = @{ @"reason" : errReason };
            
            NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                  code:0
                                              userInfo:info];
            
            callback(false, aError);
            
            return;
        }
        
        _invokedOpenOnce = true;
        
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
                
                [self postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_ERROR
                                     error:error];
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
        
        [self _sendCommand:genericCommand];
    });
}

- (void)_sendCommand:(AVIMGenericCommand *)genericCommand
{
    AssertRunInSerialQueue;
    
    if (!genericCommand) {
        
        return;
    }
    
    AVLoggerInfo(AVLoggerDomainIM, LCIM_OUT_COMMAND_LOG_FORMAT, [genericCommand avim_description]);
    
    AVIMCommandResultBlock callback = [genericCommand callback];
    
    BOOL needResponse = [genericCommand needResponse];
    
    AVIMWebSocket *webSocket = _webSocket;
    
    if (!webSocket ||
        webSocket.readyState != AVIMWebSocketStateConnected) {
        
        NSError *error = [AVIMErrorUtil errorWithCode:kAVIMErrorConnectionLost
                                               reason:@"Websocket Not Connected."];
        
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
    
    if ([data respondsToSelector:@selector(length)] &&
        data.length > 5000) {
        
        NSError *error = [AVIMErrorUtil errorWithCode:kAVIMErrorMessageTooLong
                                               reason:@"The Size of Message Data is Too Large."];
        
        if (callback) {
            
            callback(genericCommand, nil, error);
            
        } else {
            
            AVLoggerError(AVLoggerDomainIM, @"Out Command is not valid with Error: %@", error);
        }
        
        return;
    }
    
    if (needResponse) {
        
        [self enqueueCommand:genericCommand];
        
    } else {
        
        if (callback) {
            
            callback(genericCommand, nil, nil);
        }
    }
    
    [webSocket send:data];
}

- (void)enqueueCommand:(AVIMGenericCommand *)command
{
    AssertRunInSerialQueue;
    
    if (!command) {
        
        return;
    }
    
    AVIMCommandCarrier *carrier = [[AVIMCommandCarrier alloc] init];
    
    carrier.command = command;
    
    [carrier timeoutInSeconds:_timeout];
    
    NSNumber *num = @(command.i);
    
    [_commandDictionary setObject:carrier forKey:num];
    
    [_serialIdArray addObject:num];
}

- (AVIMGenericCommand *)dequeueCommandWithId:(NSNumber *)num
{
    AssertRunInSerialQueue;
    
    if (!num) {
        
        return nil;
    }
    
    AVIMCommandCarrier *carrier = [_commandDictionary objectForKey:num];
    
    if (carrier) {
        
        [_commandDictionary removeObjectForKey:num];
        
        [_serialIdArray removeObject:num];
        
        return carrier.command;
        
    } else {
        
        return nil;
    }
}

- (void)clearQueuedCommandWithError:(NSError *)error
{
    AssertRunInSerialQueue;
    
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
    
    [_commandDictionary removeAllObjects];
    
    [_serialIdArray removeAllObjects];
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
        
        [self postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_OPENED
                             error:nil];
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    AssertRunInSerialQueue;
    
    AVLoggerDebug(AVLoggerDomainIM, @"Websocket Closed with Code: %ld, Reason: %@, WasClean: %@.", (long)code, reason, @(wasClean));
    
    NSError *error = [AVIMErrorUtil errorWithCode:code
                                           reason:reason];
    
    [self handleWebSocketClosedWithError:error];
    
    if (_openCallbackArray.count > 0) {
        
        [self invokeAllOpenCallbackWithSuccess:false
                                         error:error];
        
    } else {
        
        [self postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                             error:error];
        
        if (_needReconnect) {
            
            [self setupReconnectBlock];
        }
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didFailWithError:(NSError *)error
{
    AssertRunInSerialQueue;
    
    AVLoggerError(AVLoggerDomainIM, @"Websocket Open Failed with Error: %@", error);
    
    _preferToUseSecondaryRTMServer = !_preferToUseSecondaryRTMServer;
    
    [self handleWebSocketClosedWithError:error];
    
    if (_openCallbackArray.count > 0) {
        
        [self invokeAllOpenCallbackWithSuccess:false
                                         error:error];
        
    } else {
        
        [self postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_ERROR
                             error:error];
        
        if (_needReconnect) {
            
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
        
        NSNumber *num = @(inCommand.i);
        
        AVIMGenericCommand *outCommand = [self dequeueCommandWithId:num];
        
        if (outCommand) {
            
            if ([inCommand avim_hasError]) {
                
                error = [inCommand avim_errorObject];
            }
            
            AVIMCommandResultBlock callback = outCommand.callback;
            
            if (callback) {
                
                callback(outCommand, inCommand, error);
                
                /* 另外，对于情景：单点登录, 由于未上传 deviceToken 就 open，如果用户没有 force 登录，会报错,
                 详见 https://leanticket.cn/t/leancloud/925
                 
                 sessionMessage {
                 code: 4111
                 reason: "SESSION_CONFLICT"
                 }
                 这种情况不仅要告知用户登录失败，同时也要也要在 `-[AVIMClient processSessionCommand:]` 中统一进行异常处理，
                 触发代理方法 `-client:didOfflineWithError:` 告知用户需要将 force 设为 YES。
                 */
                if (inCommand.hasSessionMessage && error) {
                    
                    notifyCommand_block();
                }
            } else {
                
                notifyCommand_block();
            }
        } else {
            
            AVLoggerError(AVLoggerDomainIM, @"No Out Command Matched Serial ID: %@", num);
        }
    } else {
        
        notifyCommand_block();
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
                
                NSDictionary *info = @{ @"reason" : reason };
                
                NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                      code:0
                                                  userInfo:info];
                
                callbackError = aError;
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
    
    [self postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT
                         error:nil];
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
            
            [self _closeWithBlockAfterClose:^{
                
                NSString *reason = @"WebSocket Ping Timeout.";
                
                NSDictionary *info = @{ @"reason" : reason };
                
                NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                      code:0
                                                  userInfo:info];
                
                [self postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                                     error:aError];
            }];
            
            [self _openWithCallback:nil blockBeforeOpen:^{
                
                [self postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT
                                     error:nil];
            }];
            
        } else {
            
            [self sendPing];
        }
    }
    
    NSMutableArray *timeoutIdArray = [NSMutableArray array];
    
    for (NSNumber *num in _serialIdArray) {
        
        AVIMCommandCarrier *carrier = [_commandDictionary objectForKey:num];
        
        if (!carrier) {
            
            continue;
        }
        
        if (currentTimestamp <= carrier.timeoutDeadlineTimestamp) {
            
            break;
        }

        [timeoutIdArray addObject:num];
        
        AVIMGenericCommand *command = carrier.command;
        
        AVIMCommandResultBlock callback = command.callback;
        
        if (callback) {
            
            NSError *error = [AVIMErrorUtil errorWithCode:kAVIMErrorTimeout
                                                   reason:@"Request Timeout."];
            
            callback(command, nil, error);
        }
    }
    
    [_commandDictionary removeObjectsForKeys:timeoutIdArray];
    
    [_serialIdArray removeObjectsInArray:timeoutIdArray];
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
    [self clearQueuedCommandWithError:error];
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

- (void)postNotificationName:(NSNotificationName)name
                       error:(NSError *)error
{
    AssertRunInSerialQueue;
    
    NSDictionary *userInfo = nil;
    
    if (error) {
        
        userInfo = @{ @"error" : error };
    }
    
    [NSNotificationCenter.defaultCenter postNotificationName:name
                                                      object:self
                                                    userInfo:userInfo];
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
