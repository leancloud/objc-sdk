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

// TODO: To! Do! if Wrapper change to Normal Instance in Future, then a global static var is not appropriate anymore too!
static NSTimeInterval AVIMWebSocketDefaultTimeoutInterval = 30.0;

NSString *const AVIMProtocolPROTOBUF1 = @"lc.protobuf2.1";
NSString *const AVIMProtocolPROTOBUF2 = @"lc.protobuf2.2";
NSString *const AVIMProtocolPROTOBUF3 = @"lc.protobuf2.3";

// MARK: - AVIMCommandCarrier

@interface AVIMCommandCarrier : NSObject

@property(nonatomic, strong) AVIMGenericCommand *command;
@property(nonatomic, assign) NSTimeInterval timestamp;

@end

@implementation AVIMCommandCarrier

- (void)timeoutInSeconds:(NSTimeInterval)seconds
{
    NSTimeInterval currentTimestamp = [NSDate.date timeIntervalSince1970];
    
    _timestamp = currentTimestamp + seconds;
}

@end

// MARK: - AVIMWebSocketWrapper

@interface AVIMWebSocketWrapper () <AVIMWebSocketDelegate>
{
    int _observerCount;
    
    NSTimeInterval _timeout;
    
    /*
     Ping & Pong
     */
    NSTimeInterval _lastPingTimestamp;
    NSTimeInterval _lastPongTimestamp;
    int _countOfSendPingWithoutReceivePong;
    
    /*
     lock `fetchRTMServerTableInBackground` method
     */
    BOOL _isFetchingRTMServerTable;
    
    /*
     determine prefer Secondary or Primary server.
     */
    BOOL _preferToUseSecondaryRTMServer;
    
    /*
     Avoid fetch loop.
     */
    int _fetchedRTMServerTableTimes;
    
    /*
     if Invoked WebSocket Close,
     use this flag to record it.
     */
    BOOL _invokedClose;
    
    /*
     Reconnect
     */
    BOOL _needReconnect;
    NSTimeInterval _reconnectInterval;
    
    /**
     Internal Serial Queue
     */
    ///
    void *_serialQueue_specific_key;
    void *_serialQueue_specific_value;
    ///
    
    /*
     Timer source
     */
    ///
    dispatch_source_t _pingTimerSource;
    dispatch_source_t _checkTimeoutTimerSource;
    ///
    
    /*
     Container
     */
    ///
    NSMutableArray<AVIMBooleanResultBlock> *_openCallbackArray;
    NSMutableDictionary<NSNumber *, AVIMCommandCarrier *> *_commandDictionary;
    NSMutableArray<NSNumber *> *_serialIdArray;
    ///
    
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

+ (instancetype)sharedSecurityInstance
{
    // TODO: To! Do! sharedInstance is not appropriate anymore, should change it to Normal Instance in Future!
    
    static dispatch_once_t onceToken;
    
    static AVIMWebSocketWrapper *sharedInstance = nil;
    
    dispatch_once(&onceToken, ^{
        
        if (!AVOSCloud.getApplicationId) {
            
            [NSException raise:@"AVOSCloudIM Exception"
                        format:@"Application ID not found."];
        }
        
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        /*
         Serial Queue init
         */
        ///
        _serialQueue = dispatch_queue_create("AVIMWebSocketWrapper._serialQueue", NULL);
        
        _serialQueue_specific_key = (__bridge void *)_serialQueue;
        _serialQueue_specific_value = (__bridge void *)_serialQueue;
        
        dispatch_queue_set_specific(_serialQueue,
                                    _serialQueue_specific_key,
                                    _serialQueue_specific_value,
                                    NULL);
        ///
        
        _openCallbackArray = [NSMutableArray array];
        
        _commandDictionary = [[NSMutableDictionary alloc] init];
        
        _serialIdArray = [[NSMutableArray alloc] init];
        
        _timeout = AVIMWebSocketDefaultTimeoutInterval;
        
        _lastPingTimestamp = -1;
        _lastPongTimestamp = -1;
        _countOfSendPingWithoutReceivePong = 0;
        
        _observerCount = 0;
        
        _needReconnect = false;
        _reconnectInterval = 1;
        
        _isFetchingRTMServerTable = false;
        
        _preferToUseSecondaryRTMServer = false;
        
        _fetchedRTMServerTableTimes = 0;
        
        _invokedClose = false;
        
        _oldNetworkReachabilityStatus = AFNetworkReachabilityStatusUnknown;
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        
#if TARGET_OS_IOS
        [center addObserver:self
                   selector:@selector(applicationDidEnterBackground:)
                       name:UIApplicationDidEnterBackgroundNotification
                     object:nil];
        
        [center addObserver:self
                   selector:@selector(applicationDidBecomeActive:)
                       name:UIApplicationDidBecomeActiveNotification
                     object:nil];
#endif
        
        // TODO: To! Do! Wrapper should have its own Network Reachability Manager, Do! It! in Future!
        // @Warning: `setReachabilityStatusChangeBlock` & `startMonitoring` is not Thread-Safe, Fix in next Version.
        
        _reachabilityMonitor = [LCNetworkReachabilityManager manager];
        
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

// MARK: - Observer Count

- (void)increaseObserverCount
{
    dispatch_async(_serialQueue, ^{
        
        _observerCount += 1;
    });
}

- (void)decreaseObserverCount
{
    dispatch_async(_serialQueue, ^{
        
        _observerCount -= 1;
        
        if (_observerCount <= 0) {
            
            _observerCount = 0;
            
            [self _close];
        }
    });
}

// MARK: - Application Notification

// TODO: Should Close Connection immediately when Enter Background ? Maybe can add a Delay Mechanism.

- (void)applicationDidEnterBackground:(id)sender
{
    dispatch_async(_serialQueue, ^{
        
        [_reachabilityMonitor stopMonitoring];
        
        [self _close];
    });
}

- (void)applicationDidBecomeActive:(id)sender
{
    dispatch_async(_serialQueue, ^{
        
        [self _openWithCallback:nil RTMServerTable:nil];
        
        [_reachabilityMonitor startMonitoring];
    });
}

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
        
        [self _openWithCallback:nil RTMServerTable:nil];
        
    } else if (isNewStatusNotReachable && isOldStatusNormal) {
        
        /*
         Status change from `Reachable` to `NotReachable`
         */
        _oldNetworkReachabilityStatus = newStatus;
        
        [self _close];
        
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

- (void)openWebSocketConnectionWithCallback:(AVIMBooleanResultBlock)callback
{
    [self openWithCallback:callback];
}

- (void)openWithCallback:(AVIMBooleanResultBlock)callback
{
    dispatch_async(_serialQueue, ^{
        
        [self _openWithCallback:callback
                 RTMServerTable:nil];
    });
}

- (void)_openWithCallback:(AVIMBooleanResultBlock)callback
           RTMServerTable:(NSDictionary *)RTMServerTable
{
    AssertRunInSerialQueue;
    
    AVLoggerInfo(AVLoggerDomainIM, @"Start Open Websocket Connection.");
    
    if (_observerCount == 0) {
        
        /*
         No one use it, just return
         */
        
        if (callback) {
            
            NSString *reason = @"No Observer for WebSocket Wrapper.";
            
            NSDictionary *info = @{ @"reason" : reason };
            
            NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                  code:0
                                              userInfo:info];
            
            callback(false, aError);
        }
        
        return;
    }
    
    if (_oldNetworkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
        
        /*
         if Network is Not Reachable, just return
         */
        
        if (callback) {
            
            NSString *reason = @"Network is Not Reachable.";
            
            NSDictionary *info = @{ @"reason" : reason };
            
            NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                  code:0
                                              userInfo:info];
            
            callback(false, aError);
        }
        
        return;
    }
    
    if (_webSocket && !_invokedClose) {
        
        /*
         if `_webSocket` exist & not call `close`
         */
        
        AVIMWebSocketState readyState = _webSocket.readyState;
        
        if (readyState == AVIMWebSocketStateConnected) {
            
            /*
             if Websocket Opened, Invoking Callback & Return.
             */
            
            if (callback) {
                
                callback(true, nil);
            }
            
            return;
        }
        
        if (readyState == AVIMWebSocketStateConnecting) {
            
            /*
             if Websocket Opening, Add Callback to Array & Return.
             */
            
            if (callback && [_openCallbackArray containsObject:callback] == false) {
                
                [_openCallbackArray addObject:callback];
            }
            
            return;
        }
    }
    
    if (callback && [_openCallbackArray containsObject:callback] == false) {
        
        [_openCallbackArray addObject:callback];
    }
    
    NSString *RTMServer = nil;
    
    if (RTMServerTable) {
        
        /*
         1. connect server from arg table.
         */
        
        RTMServer = [self getRTMServerFromTable:RTMServerTable];
        
        [self newWebSocketAndConnectWithServer:RTMServer];
        
        return;
    }
    
    RTMServer = [AVOSCloudIM defaultOptions].RTMServer;
    
    if (RTMServer) {
        
        /*
         2. connect server from custom server.
         */
        
        [self newWebSocketAndConnectWithServer:RTMServer];
        
        return;
    }
    
    RTMServerTable = [[LCRouter sharedInstance] cachedRTMServerTable];
    
    if (RTMServerTable) {
        
        /*
         3. connect server from cache of router
         */
        
        RTMServer = [self getRTMServerFromTable:RTMServerTable];
        
        if (RTMServer) {
            
            [self newWebSocketAndConnectWithServer:RTMServer];
            
            return;
        }
    }
    
    /*
     4. No Valid Server, then fetch RTMServerTable from server.
     */
    [self fetchRTMServerTable];
}

- (void)newWebSocketAndConnectWithServer:(NSString *)server
{
    AssertRunInSerialQueue;
    
    AVLoggerInfo(AVLoggerDomainIM, @"Opening websocket with url: %@", server);
    
    /*
     reset it
     */
    _fetchedRTMServerTableTimes = 0;
    
    if (_webSocket) {
        
        /*
         close old websocket
         */
        
        if (_webSocket.delegate) {
            
            _webSocket.delegate = nil;
        }
        
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
    
    if (protocols.count > 0) {
        
        _webSocket = [[AVIMWebSocket alloc] initWithURLRequest:request protocols:[protocols allObjects]];
        
    } else {
        
        _webSocket = [[AVIMWebSocket alloc] initWithURLRequest:request];
    }
    
    /*
     new a websocket, so `_invokedCloseConnection` flag should be reset to false.
     */
    _invokedClose = false;
    
    [_webSocket setDelegateDispatchQueue:_serialQueue];
    _webSocket.delegate = self;
    
    [_webSocket open];
}

- (void)fetchRTMServerTable
{
    AssertRunInSerialQueue;
    
    if (_isFetchingRTMServerTable) {
        
        /*
         In process of Fetching RTMServer Table, so return
         */
        
        return;
        
    } else {
        
        _isFetchingRTMServerTable = true;
    }
    
    [LCRouter.sharedInstance fetchRTMServerTableInBackground:^(NSDictionary *RTMServerTable, NSError *error){
        
        dispatch_block_t block = ^(void) {
            
            _isFetchingRTMServerTable = false;
            
            if (_webSocket) {
                
                /*
                 In Connecting or Connected, just Return.
                 */
                
                AVIMWebSocketState state = _webSocket.readyState;
                
                if (state == AVIMWebSocketStateConnecting ||
                    state == AVIMWebSocketStateConnected) {
                    
                    if (RTMServerTable) {
                        
                        /*
                         Also should to change them
                         */
                        
                        _preferToUseSecondaryRTMServer = false;
                        
                        _fetchedRTMServerTableTimes += 1;
                    }
                    
                    return;
                }
            }
            
            if (RTMServerTable) {
                
                _preferToUseSecondaryRTMServer = false;
                
                _fetchedRTMServerTableTimes += 1;
                
                if (_fetchedRTMServerTableTimes <= 3) {
                    
                    [self _openWithCallback:nil RTMServerTable:RTMServerTable];
                    
                    return;
                    
                } else {
                    
                    /*
                     More than 3 times, it can be assumed that server is invalid,
                     invoke callback with a error.
                     */
                    
                    _fetchedRTMServerTableTimes = 0;
                    
                    NSString *reason = @"Unknown Error with RTM server.";
                    
                    NSDictionary *info = @{ @"reason" : reason };
                    
                    NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                          code:0
                                                      userInfo:info];
                    
                    [self invokeAllOpenCallbackWithSuccess:false
                                                     error:aError];
                    
                    return;
                }
            }
            
            /* Error */
            
            NSError *aError = nil;
            
            if (error) {
                
                NSString *reason = [NSHTTPURLResponse localizedStringForStatusCode:error.code];
                
                aError = [AVIMErrorUtil errorWithCode:error.code
                                               reason:reason];
                
            } else {
                
                aError = [AVIMErrorUtil errorWithCode:kAVIMErrorInvalidData
                                               reason:@"No Data Received."];
            }
            
            [self invokeAllOpenCallbackWithSuccess:false
                                             error:aError];
        };
        
        dispatch_async(_serialQueue, block);
    }];
}

- (NSString *)getRTMServerFromTable:(NSDictionary *)RTMServerTable
{
    AssertRunInSerialQueue;
    
    NSString *server = nil;
    
    NSString *primary   = RTMServerTable[@"server"];
    NSString *secondary = RTMServerTable[@"secondary"];
    
    if (_preferToUseSecondaryRTMServer) {
        
        server = secondary ?: primary;
        
    } else {
        
        server = primary ?: secondary;
    }
    
    return server;
}

// MARK: - Close WebSocket

/*
 Because Now Wrapper is a Shared Instance, so `close` API is not be exposed.
 */
//- (void)close
//{
//    dispatch_async(_serialQueue, ^{
//
//        [self _close];
//    });
//}

- (void)_close
{
    AssertRunInSerialQueue;
    
    AVLoggerInfo(AVLoggerDomainIM, @"Closing WebSocket Connection.");
    
    /*
     stop reconnect
     */
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
        
        _invokedClose = true;
        
        [_webSocket close];
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
    
    BOOL(^checkSizeForData_block)(id) = ^BOOL(NSData *data) {
        
        if ([data respondsToSelector:@selector(length)] &&
            data.length > 5000) {
            
            return false;
        }
        
        return true;
    };
    
    if (!genericCommand) {
        
        return;
    }
    
    AVIMCommandResultBlock callback = genericCommand.callback;
    
    if (_invokedClose ||
        (_webSocket && _webSocket.readyState != AVIMWebSocketStateConnected)) {
        
        NSError *error = [AVIMErrorUtil errorWithCode:kAVIMErrorConnectionLost
                                               reason:@"Websocket Not Opened."];
        
        if (callback) {
            
            callback(genericCommand, nil, error);
            
        } else {
            
            [NSNotificationCenter.defaultCenter postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_ERROR
                                                              object:self
                                                            userInfo:@{ @"error": error }];
        }
        
        return;
    }
    
    NSData *data = [genericCommand data];
    
    AVLoggerInfo(AVLoggerDomainIM, LCIM_OUT_COMMAND_LOG_FORMAT, [genericCommand avim_description]);
    
    if (checkSizeForData_block(data) == false) {
        
        NSError *error = [AVIMErrorUtil errorWithCode:kAVIMErrorMessageTooLong
                                               reason:@"the size of Message Data to send is too large."];
        
        if (callback) {
            
            callback(genericCommand, nil, error);
            
        } else {
            
            AVLoggerError(AVLoggerDomainIM, @"Out Command is not valid with Error: %@", error);
        }
        
        return;
    }
    
    BOOL needResponse = genericCommand.needResponse;
    
    if (needResponse) {
        
        [genericCommand avim_addOrRefreshSerialId];
        
        [self enqueueCommand:genericCommand];
        
        [_serialIdArray addObject:@(genericCommand.i)];
    }
    
    [_webSocket send:data];
    
    if (!needResponse && callback) {
        
        callback(genericCommand, nil, nil);
    }
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
        
        return carrier.command;
        
    } else {
        
        return nil;
    }
}

- (void)clearQueuedCommandWithError:(NSError *)error
{
    AssertRunInSerialQueue;
    
    for (NSNumber *serialId in _serialIdArray) {
        
        AVIMGenericCommand *outCommand = [self dequeueCommandWithId:serialId];
        
        if (outCommand) {
            
            AVIMCommandResultBlock callback = outCommand.callback;
            
            if (callback) {
                
                callback(outCommand, nil, error);
            }
        } else {
            
            AVLoggerError(AVLoggerDomainIM, @"No Out Command matched Serial ID %@", serialId);
        }
    }
    
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
    [self stopPingTimer];
    [self startPingTimer];
    
    /*
     start check timeout timer
     */
    [self stopCheckTimeoutTimer];
    [self startCheckTimeoutTimer];
    
    if (_openCallbackArray.count > 0) {
        
        [self invokeAllOpenCallbackWithSuccess:true
                                         error:nil];
        
    } else {
        
        [NSNotificationCenter.defaultCenter postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_OPENED
                                                          object:self
                                                        userInfo:nil];
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    AssertRunInSerialQueue;
    
    AVLoggerDebug(AVLoggerDomainIM, @"Websocket Closed with Code: %ld, Reason: %@, WasClean: %@.", (long)code, reason, @(wasClean));
    
    NSError *error = [AVIMErrorUtil errorWithCode:code reason:reason];
    
    [self clearQueuedCommandWithError:error];
    
    if (_openCallbackArray.count > 0) {
        
        [self invokeAllOpenCallbackWithSuccess:false
                                         error:error];
        
    } else {
        
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        
        if (_needReconnect) {
            
            [self reconnecting];
            
            [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT
                                  object:self
                                userInfo:@{ @"error" : error }];
            
        } else {
            
            [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                                  object:self
                                userInfo:@{ @"error" : error }];
        }
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didFailWithError:(NSError *)error
{
    AssertRunInSerialQueue;
    
    AVLoggerError(AVLoggerDomainIM, @"Websocket Open Failed with Error: %@", error);
    
    _preferToUseSecondaryRTMServer = true;
    
    [self clearQueuedCommandWithError:error];
    
    if (_openCallbackArray.count > 0) {
        
        [self invokeAllOpenCallbackWithSuccess:false
                                         error:error];
        
    } else {
        
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        
        if (_needReconnect) {
            
            [self reconnecting];
            
            [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_RECONNECT
                                  object:self
                                userInfo:@{ @"error" : error }];
            
        } else {
            
            [center postNotificationName:AVIM_NOTIFICATION_WEBSOCKET_ERROR
                                  object:self
                                userInfo:@{ @"error" : error }];
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
    AVIMGenericCommand *inCommand = [AVIMGenericCommand parseFromData:message error:&error];
    
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
            
            [_serialIdArray removeObject:num];
            
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
    
    _lastPongTimestamp = [NSDate.date timeIntervalSince1970];
    
    _countOfSendPingWithoutReceivePong = 0;
}

// MARK: - Reconnect

- (void)reconnecting;
{
    AssertRunInSerialQueue;
    
    if (!_needReconnect) {
        
        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_reconnectInterval * NSEC_PER_SEC)), _serialQueue, ^{
        
        BOOL shouldOpen = true;
        
#if TARGET_OS_IOS
        if (!getenv("LCIM_BACKGROUND_CONNECT_ENABLED") &&
            UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
            
            shouldOpen = false;
        }
#endif
        
        if (shouldOpen) {
            
            [self _openWithCallback:nil RTMServerTable:nil];
        }
    });
    
    _reconnectInterval = (_reconnectInterval * 2);
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
    _lastPongTimestamp = -1;
    _countOfSendPingWithoutReceivePong = 0;
}

- (void)startPingTimer
{
    AssertRunInSerialQueue;
    
    NSAssert(_pingTimerSource == nil, @"`_pingTimerSource` should be nil.");
    
    dispatch_block_t eventHandler = ^{
        
        [self sendPing];
    };
    
    _pingTimerSource = [self newTimerSourceWithInterval:PING_INTERVAL
                                                 atOnce:true
                                           eventHandler:eventHandler];
}

- (void)sendPing
{
    AssertRunInSerialQueue;
    
    if (!_webSocket ||
        _webSocket.readyState != AVIMWebSocketStateConnected) {
        
        /*
         No websocket or No connected, return.
         */
        
        return;
    }
    
    AVLoggerInfo(AVLoggerDomainIM, @"Websocket Send Ping.");
    
    _lastPingTimestamp = [NSDate.date timeIntervalSince1970];
    
    _countOfSendPingWithoutReceivePong += 1;
    
    NSData *pingData = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    
    [_webSocket sendPing:pingData];
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
    
    NSAssert(_checkTimeoutTimerSource == nil, @"`_checkTimeoutTimerSource` should be nil.");
    
    dispatch_block_t eventHandler = ^{
        
        [self checkTimeout];
    };
    
    _checkTimeoutTimerSource = [self newTimerSourceWithInterval:TIMEOUT_CHECK_INTERVAL
                                                         atOnce:false
                                                   eventHandler:eventHandler];
}

- (void)checkTimeout
{
    AssertRunInSerialQueue;
    
    NSTimeInterval currentTimestamp = [NSDate.date timeIntervalSince1970];
    
    if (_lastPingTimestamp > 0) {
        
        BOOL isPingTimeout = ((currentTimestamp - _lastPingTimestamp) > _timeout);
        
        if (isPingTimeout) {
            
            if (_countOfSendPingWithoutReceivePong >= 3) {
                
                [self _close];
                
                [self _openWithCallback:nil RTMServerTable:nil];
                
                return;
                
            } else {
                
                [self sendPing];
            }
        }
    }
    
    NSMutableArray *timeoutIdArray = [NSMutableArray array];
    
    for (NSNumber *num in _serialIdArray) {
        
        AVIMCommandCarrier *carrier = [_commandDictionary objectForKey:num];
        
        if (!carrier) {
            
            continue;
        }
        
        if (currentTimestamp <= carrier.timestamp) {
            
            break;
        }

        [timeoutIdArray addObject:num];
        
        [_commandDictionary removeObjectForKey:num];
        
        AVIMGenericCommand *command = carrier.command;
        
        AVIMCommandResultBlock callback = command.callback;
        
        if (callback) {
            
            NSError *error = [AVIMErrorUtil errorWithCode:kAVIMErrorTimeout
                                                   reason:@"Request Timeout."];
            callback(command, nil, error);
        }
    }
    
    if (timeoutIdArray.count > 0) {
        
        [_serialIdArray removeObjectsInArray:timeoutIdArray];
    }
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

- (BOOL)isConnectionOpen
{
    __block BOOL isOpen;
    
    dispatch_sync(_serialQueue, ^{
        
        isOpen = (_webSocket.readyState == AVIMWebSocketStateConnected);
    });
    
    return isOpen;
}

@end
