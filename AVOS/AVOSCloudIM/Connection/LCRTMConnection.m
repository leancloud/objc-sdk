//
//  LCRTMConnection.m
//  AVOSCloudIM
//
//  Created by pzheng on 2020/05/20.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

#import "LCRTMConnection.h"
#import "LCRTMWebSocket.h"

#import "AVIMCommon_Internal.h"
#import "AVApplication.h"
#import "AVErrorUtils.h"

#if !TARGET_OS_WATCH
#import "LCNetworkReachabilityManager.h"
#endif

#import <TargetConditionals.h>

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
typedef NS_ENUM(NSUInteger, LCRTMConnectionAppState) {
    LCRTMConnectionAppStateBackground,
    LCRTMConnectionAppStateForeground,
};
#endif

LCIMProtocol const LCIMProtocol3 = @"lc.protobuf2.3";
LCIMProtocol const LCIMProtocol1 = @"lc.protobuf2.1";

// MARK: Interface

@interface LCRTMConnectionManager ()

@property (nonatomic) NSLock *lock;

@end

@interface LCRTMConnectionOutCommand : NSObject

@property (nonatomic, readonly) NSString *peerID;
@property (nonatomic) AVIMGenericCommand *command;
@property (nonatomic, nullable) dispatch_queue_t callingQueue;
@property (nonatomic, nullable) NSMutableArray<LCRTMConnectionOutCommandCallback> *callbacks;
@property (nonatomic, nullable) NSDate *expiration;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithPeerID:(NSString *)peerID
                       command:(AVIMGenericCommand *)command
                  callingQueue:(dispatch_queue_t _Nullable)callingQueue
                      callback:(LCRTMConnectionOutCommandCallback _Nullable)callback NS_DESIGNATED_INITIALIZER;

- (BOOL)microIdempotentFor:(AVIMGenericCommand *)outCommand
                      from:(NSString *)peerID;

@end

@interface LCRTMConnectionTimer : NSObject

@property (nonatomic, readonly) NSTimeInterval pingpongInterval;
@property (nonatomic, readonly) NSTimeInterval pingTimeout;
@property (nonatomic) NSTimeInterval lastPingSentTimestamp;
@property (nonatomic) NSTimeInterval lastPongReceivedTimestamp;
@property (nonatomic) dispatch_source_t source;
@property (nonatomic, readonly) LCRTMWebSocket *socket;
@property (nonatomic) NSMutableArray<NSNumber *> *outCommandIndexSequence;
@property (nonatomic) NSMutableDictionary<NSNumber *, LCRTMConnectionOutCommand *> *outCommandCollection;
@property (nonatomic) SInt32 index;
#if DEBUG
@property (nonatomic, readonly) dispatch_queue_t queue;
#endif

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithQueue:(dispatch_queue_t)queue
                       socket:(LCRTMWebSocket *)socket NS_DESIGNATED_INITIALIZER;

- (BOOL)tryThrottling:(AVIMGenericCommand *)outCommand
                 from:(NSString *)peerID
             callback:(LCRTMConnectionOutCommandCallback)callback;

- (void)handleCallbackCommand:(AVIMGenericCommand *)inCommand;

- (SInt32)nextIndex;

- (void)cleanInCurrentQueue:(BOOL)inCurrentQueue;

@end

@interface LCRTMConnection () <LCRTMWebSocketDelegate>

@property (nonatomic) dispatch_queue_t serialQueue;
#if TARGET_OS_IOS || TARGET_OS_TV
@property (nonatomic) LCRTMConnectionAppState previousAppState;
@property (nonatomic) id<NSObject> enterBackgroundObserver;
@property (nonatomic) id<NSObject> enterForegroundObserver;
#endif
#if !TARGET_OS_WATCH
@property (nonatomic) LCNetworkReachabilityStatus previousReachabilityStatus;
@property (nonatomic) LCNetworkReachabilityManager *reachabilityManager;
#endif
@property (nonatomic) NSString *defaultInstantMessagingPeerID;
@property (nonatomic) BOOL needPeerIDForEveryCommand;
@property (nonatomic) LCRTMConnectionTimer *timer;
@property (nonatomic) LCRTMWebSocket *socket;
@property (nonatomic) dispatch_block_t previousConnectingBlock;
@property (nonatomic) BOOL useSecondaryServer;
@property (nonatomic) NSUInteger connectingDelayInterval;
@property (nonatomic) NSUInteger connectingFailedCount;
@property (nonatomic) BOOL isRouting;

- (instancetype)initWithApplication:(AVApplication *)application
                           protocol:(LCIMProtocol)protocol
                              error:(NSError * __autoreleasing *)error;

@end

// MARK: Implementation

@implementation LCRTMServiceConsumer

- (instancetype)initWithApplication:(AVApplication *)application
                            service:(LCRTMService)service
                           protocol:(LCIMProtocol)protocol
                             peerID:(NSString *)peerID
{
    self = [super init];
    if (self) {
        _application = application;
        _service = service;
        _protocol = protocol;
        _peerID = peerID;
    }
    return self;
}

@end

@implementation LCRTMConnectionManager

+ (instancetype)sharedManager
{
    static LCRTMConnectionManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LCRTMConnectionManager alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _lock = [NSLock new];
        _imProtobuf3Registry = [NSMutableDictionary dictionary];
        _imProtobuf1Registry = [NSMutableDictionary dictionary];
        _liveQueryRegistry = [NSMutableDictionary dictionary];
    }
    return self;
}

- (LCRTMConnection *)registerWithServiceConsumer:(LCRTMServiceConsumer *)serviceConsumer
                                           error:(NSError * __autoreleasing *)error
{
    return (LCRTMConnection *)[self synchronize:^id{
        NSString *appID = serviceConsumer.application.identifier;
        LCRTMConnection *connection;
        if (serviceConsumer.service == LCRTMServiceInstantMessaging) {
            LCRTMInstantMessagingRegistry registry = [self registryFromProtocol:serviceConsumer.protocol];
            NSMutableDictionary<NSString *, LCRTMConnection *> *connectionMap = registry[appID];
            LCRTMConnection *sharedConnection = connectionMap.allValues.firstObject;
            if (sharedConnection) {
                if (connectionMap[serviceConsumer.peerID]) {
                    if (error) {
                        *error = LCError(AVErrorInternalErrorCodeInconsistency,
                                         @"Duplicate registration for connection.", nil);
                    }
                    return nil;
                }
                connectionMap[serviceConsumer.peerID] = sharedConnection;
            } else {
                sharedConnection = self.liveQueryRegistry[appID];
                if (![sharedConnection.protocol isEqualToString:serviceConsumer.protocol]) {
                    sharedConnection = [[LCRTMConnection alloc] initWithApplication:serviceConsumer.application
                                                                           protocol:serviceConsumer.protocol
                                                                              error:error];
                    if (error && *error) {
                        return nil;
                    }
                }
                connectionMap = [NSMutableDictionary dictionaryWithObject:sharedConnection
                                                                   forKey:serviceConsumer.peerID];
                registry[appID] = connectionMap;
            }
            connection = sharedConnection;
        } else if (serviceConsumer.service == LCRTMServiceLiveQuery) {
            LCRTMConnection *sharedConnection = self.liveQueryRegistry[appID];
            if (!sharedConnection) {
                sharedConnection = self.imProtobuf3Registry[appID].allValues.firstObject;
                if (!sharedConnection) {
                    sharedConnection = self.imProtobuf1Registry[appID].allValues.firstObject;
                    if (!sharedConnection) {
                        sharedConnection = [[LCRTMConnection alloc] initWithApplication:serviceConsumer.application
                                                                               protocol:serviceConsumer.protocol
                                                                                  error:error];
                        if (error && *error) {
                            return nil;
                        }
                    }
                }
            }
            self.liveQueryRegistry[appID] = sharedConnection;
            connection = sharedConnection;
        } else {
            [NSException raise:NSInternalInconsistencyException
                        format:@"should not happen"];
        }
        return connection;
    }];
}

- (void)unregisterWithServiceConsumer:(LCRTMServiceConsumer *)serviceConsumer
{
    [self synchronize:^id{
        NSString *appID = serviceConsumer.application.identifier;
        if (serviceConsumer.service == LCRTMServiceInstantMessaging) {
            LCRTMInstantMessagingRegistry registry = [self registryFromProtocol:serviceConsumer.protocol];
            NSMutableDictionary<NSString *, LCRTMConnection *> *connectionMap = registry[appID];
            [connectionMap removeObjectForKey:serviceConsumer.peerID];
        } else if (serviceConsumer.service == LCRTMServiceLiveQuery) {
            [self.liveQueryRegistry removeObjectForKey:appID];
        } else {
            [NSException raise:NSInternalInconsistencyException
                        format:@"should not happen"];
        }
        return nil;
    }];
}

- (id)synchronize:(id (^)(void))block
{
    id result;
    [self.lock lock];
    result = block();
    [self.lock unlock];
    return result;
}

- (LCRTMInstantMessagingRegistry)registryFromProtocol:(LCIMProtocol)protocol
{
    if ([protocol isEqualToString:LCIMProtocol3]) {
        return self.imProtobuf3Registry;
    } else if ([protocol isEqualToString:LCIMProtocol1]) {
        return self.imProtobuf1Registry;
    } else {
        [NSException raise:NSInternalInconsistencyException
                    format:@"should not happen"];
        return nil;
    }
}

@end

@implementation LCRTMConnectionDelegator

- (instancetype)initWithPeerID:(NSString *)peerID
                      delegate:(id<LCRTMConnectionDelegate>)delegate
                         queue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self) {
        _peerID = peerID;
        _delegate = delegate;
        _queue = queue;
    }
    return self;
}

@end

@implementation LCRTMConnectionOutCommand

- (instancetype)initWithPeerID:(NSString *)peerID
                       command:(AVIMGenericCommand *)command
                  callingQueue:(dispatch_queue_t)callingQueue
                      callback:(LCRTMConnectionOutCommandCallback)callback
{
    self = [super init];
    if (self) {
        _peerID = peerID;
        _command = command;
        _callingQueue = callingQueue;
        if (callback) {
            _callbacks = [NSMutableArray arrayWithObject:callback];
        }
    }
    return self;
}

- (BOOL)microIdempotentFor:(AVIMGenericCommand *)outCommand
                      from:(NSString *)peerID
{
    if (![self.peerID isEqualToString:peerID] ||
        outCommand.cmd == AVIMCommandType_Direct ||
        (outCommand.cmd == AVIMCommandType_Conv &&
         (outCommand.op == AVIMOpType_Start ||
          outCommand.op == AVIMOpType_Update ||
          outCommand.op == AVIMOpType_Members))) {
        return false;
    }
    if (self.command.hasI) {
        outCommand.i = self.command.i;
    }
    return [outCommand isEqual:self.command];
}

@end

@implementation LCRTMConnectionTimer

- (instancetype)initWithQueue:(dispatch_queue_t)queue
                       socket:(LCRTMWebSocket *)socket
{
    self = [super init];
    if (self) {
#if DEBUG
        _queue = queue;
#endif
        _pingpongInterval = 180.0;
        _pingTimeout = 20.0;
        _lastPingSentTimestamp = 0;
        _lastPongReceivedTimestamp = 0;
        _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        _socket = socket;
        _outCommandIndexSequence = [NSMutableArray array];
        _outCommandCollection = [NSMutableDictionary dictionary];
        _index = 0;
        __weak typeof(self) ws = self;
        dispatch_source_set_event_handler(_source, ^{
            LCRTMConnectionTimer *ss = ws;
            if (ss) {
                NSDate *currentDate = [NSDate date];
                [ss checkCommandTimeout:currentDate];
                [ss checkPingPong:currentDate];
            }
        });
        NSTimeInterval interval = 1.0;
        dispatch_source_set_timer(_source,
                                  DISPATCH_TIME_NOW,
                                  NSEC_PER_SEC * interval,
                                  NSEC_PER_SEC * interval);
        dispatch_resume(_source);
    }
    return self;
}

- (BOOL)assertSpecificQueue
{
#if DEBUG
    void *specificKey = (__bridge void *)_queue;
    return dispatch_get_specific(specificKey) == specificKey;
#else
    return true;
#endif
}

- (void)checkCommandTimeout:(NSDate *)currentDate
{
    NSParameterAssert([self assertSpecificQueue]);
    NSUInteger len = 0;
    for (NSNumber *i in self.outCommandIndexSequence) {
        LCRTMConnectionOutCommand *command = self.outCommandCollection[i];
        if (command) {
            if ([command.expiration compare:currentDate] == NSOrderedDescending) {
                break;
            } else {
                NSError *error = LCError(AVIMErrorCodeCommandTimeout,
                                         @"Command timeout.", nil);
                for (LCRTMConnectionOutCommandCallback callback in command.callbacks) {
                    dispatch_async(command.callingQueue, ^{
                        callback(nil, error);
                    });
                }
                [self.outCommandCollection removeObjectForKey:i];
                len += 1;
            }
        } else {
            len += 1;
        }
    }
    if (len > 0) {
        [self.outCommandIndexSequence removeObjectsInRange:NSMakeRange(0, len)];
    }
}

- (void)checkPingPong:(NSDate *)currentDate
{
    NSParameterAssert([self assertSpecificQueue]);
    NSTimeInterval currentTimestamp = currentDate.timeIntervalSince1970;
    BOOL isPingSentAndPongNotReceived = (self.lastPingSentTimestamp > self.lastPongReceivedTimestamp);
    BOOL isLastPingTimeout = (isPingSentAndPongNotReceived &&
                              (currentTimestamp > self.lastPingSentTimestamp + self.pingTimeout));
    BOOL shouldNextPingPong = (!isPingSentAndPongNotReceived &&
                               (currentTimestamp > self.lastPongReceivedTimestamp + self.pingpongInterval));
    if (isLastPingTimeout || shouldNextPingPong) {
        __weak typeof(self) ws = self;
        [self.socket sendPing:[NSData data] completion:^{
            // TODO: log
            ws.lastPingSentTimestamp = currentTimestamp;
        }];
    }
}

- (BOOL)tryThrottling:(AVIMGenericCommand *)outCommand
                 from:(NSString *)peerID
             callback:(LCRTMConnectionOutCommandCallback)callback
{
    NSParameterAssert([self assertSpecificQueue]);
    for (NSNumber *i in self.outCommandIndexSequence) {
        LCRTMConnectionOutCommand *command = self.outCommandCollection[i];
        if ([command microIdempotentFor:outCommand from:peerID]) {
            [command.callbacks addObject:callback];
            return true;
        }
    }
    return false;
}

- (void)handleCallbackCommand:(AVIMGenericCommand *)inCommand
{
    NSParameterAssert([self assertSpecificQueue]);
    NSNumber *i = @(inCommand.i);
    LCRTMConnectionOutCommand *command = self.outCommandCollection[i];
    if (command) {
        for (LCRTMConnectionOutCommandCallback callback in command.callbacks) {
            dispatch_async(command.callingQueue, ^{
                callback(inCommand, nil);
            });
        }
        [self.outCommandIndexSequence removeObject:i];
        [self.outCommandCollection removeObjectForKey:i];
    }
}

- (SInt32)nextIndex
{
    NSParameterAssert([self assertSpecificQueue]);
    if (self.index == INT32_MAX) {
        self.index = 0;
    }
    self.index += 1;
    return self.index;
}

- (void)cleanInCurrentQueue:(BOOL)inCurrentQueue
{
    void(^clean)(void) = ^(void) {
        NSParameterAssert([self assertSpecificQueue]);
        if (self.source) {
            dispatch_source_cancel(self.source);
            self.source = nil;
        }
        if (self.outCommandIndexSequence.count > 0) {
            NSError *error = LCError(AVIMErrorCodeConnectionLost,
                                     @"Connection lost.", nil);
            for (NSNumber *i in self.outCommandIndexSequence) {
                LCRTMConnectionOutCommand *command = self.outCommandCollection[i];
                if (command) {
                    for (LCRTMConnectionOutCommandCallback callback in command.callbacks) {
                        dispatch_async(command.callingQueue, ^{
                            callback(nil, error);
                        });
                    }
                }
            }
            [self.outCommandIndexSequence removeAllObjects];
            [self.outCommandCollection removeAllObjects];
        }
    };
    if (inCurrentQueue) {
        clean();
    } else {
        dispatch_async(self.queue, ^{
            clean();
        });
    }
}

@end

@implementation LCRTMConnection

- (instancetype)initWithApplication:(AVApplication *)application
                           protocol:(LCIMProtocol)protocol
                              error:(NSError *__autoreleasing *)error
{
    self = [super init];
    if (self) {
        _application = application;
        _protocol = protocol;
        _instantMessagingDelegatorMap = [NSMutableDictionary dictionary];
        _liveQueryDelegatorMap = [NSMutableDictionary dictionary];
        _serialQueue = dispatch_queue_create("LCRTMConnection.serialQueue", NULL);
        _defaultInstantMessagingPeerID = nil;
        _needPeerIDForEveryCommand = false;
        _timer = nil;
        _socket = nil;
        _previousConnectingBlock = nil;
        _useSecondaryServer = false;
        _connectingDelayInterval = 0;
        _connectingFailedCount = 0;
        _isRouting = false;
#if DEBUG
        dispatch_queue_set_specific(_serialQueue,
                                    (__bridge void *)_serialQueue,
                                    (__bridge void *)_serialQueue,
                                    NULL);
#endif
        __weak typeof(self) ws = self;
#if TARGET_OS_IOS || TARGET_OS_TV
        if (NSThread.isMainThread) {
            _previousAppState = UIApplication.sharedApplication.applicationState;
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                _previousAppState = UIApplication.sharedApplication.applicationState;
            });
        }
        NSOperationQueue *appStateQueue = [[NSOperationQueue alloc] init];
        appStateQueue.underlyingQueue = _serialQueue;
        _enterBackgroundObserver = [NSNotificationCenter.defaultCenter
                                    addObserverForName:UIApplicationDidEnterBackgroundNotification
                                    object:nil
                                    queue:appStateQueue
                                    usingBlock:^(NSNotification * _Nonnull note) {
            [ws applicationStateChanged:LCRTMConnectionAppStateBackground];
        }];
        _enterForegroundObserver = [NSNotificationCenter.defaultCenter
                                    addObserverForName:UIApplicationWillEnterForegroundNotification
                                    object:nil
                                    queue:appStateQueue
                                    usingBlock:^(NSNotification * _Nonnull note) {
            [ws applicationStateChanged:LCRTMConnectionAppStateForeground];
        }];
#endif
#if !TARGET_OS_WATCH
        _reachabilityManager = [LCNetworkReachabilityManager manager];
        _reachabilityManager.reachabilityQueue = _serialQueue;
        _previousReachabilityStatus = _reachabilityManager.networkReachabilityStatus;
        [_reachabilityManager setReachabilityStatusChangeBlock:^(LCNetworkReachabilityStatus status) {
            [ws networkReachabilityStatusChanged:status];
        }];
        [_reachabilityManager startMonitoring];
#endif
    }
    return self;
}

- (void)dealloc
{
#if TARGET_OS_IOS || TARGET_OS_TV
    if (self.enterBackgroundObserver) {
        [NSNotificationCenter.defaultCenter removeObserver:self.enterBackgroundObserver];
    }
    if (self.enterForegroundObserver) {
        [NSNotificationCenter.defaultCenter removeObserver:self.enterForegroundObserver];
    }
#endif
#if !TARGET_OS_WATCH
    [self.reachabilityManager stopMonitoring];
#endif
    [self.timer cleanInCurrentQueue:false];
    [self.socket clean];
}

- (BOOL)assertSpecificSerialQueue
{
#if DEBUG
    void *specificKey = (__bridge void *)_serialQueue;
    return dispatch_get_specific(specificKey) == specificKey;
#else
    return true;
#endif
}

#if TARGET_OS_IOS || TARGET_OS_TV
- (void)applicationStateChanged:(LCRTMConnectionAppState)state
{
    NSParameterAssert([self assertSpecificSerialQueue]);
}
#endif

#if !TARGET_OS_WATCH
- (void)networkReachabilityStatusChanged:(LCNetworkReachabilityStatus)status
{
    NSParameterAssert([self assertSpecificSerialQueue]);
}
#endif

- (BOOL)hasDelegator
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    return (self.instantMessagingDelegatorMap.count > 0 ||
            self.liveQueryDelegatorMap.count > 0);
}

- (NSError *)checkEnvironment
{
    NSParameterAssert([self assertSpecificSerialQueue]);
#if TARGET_OS_IOS || TARGET_OS_TV
    if (self.previousAppState == LCRTMConnectionAppStateBackground) {
        return LCError(AVIMErrorCodeConnectionLost,
                       @"Application did enter background, connection lost.", nil);
    }
#endif
#if !TARGET_OS_WATCH
    if (self.previousReachabilityStatus == LCNetworkReachabilityStatusNotReachable) {
        return LCError(AVIMErrorCodeConnectionLost,
                       @"Network not reachable, connection lost.", nil);
    }
#endif
    return nil;
}

- (BOOL)canConnecting
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    return (!self.socket &&
            [self hasDelegator] &&
            ![self checkEnvironment]);
}

- (NSUInteger)nextConnectingDelayInterval
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    if (self.connectingDelayInterval == 0) {
        self.connectingDelayInterval = 1;
    } else if (self.connectingDelayInterval > 15) {
        self.connectingDelayInterval = 30;
    } else {
        self.connectingDelayInterval *= 2;
    }
    return self.connectingDelayInterval;
}

- (void)connectWithServiceConsumer:(LCRTMServiceConsumer *)serviceConsumer
                         delegator:(LCRTMConnectionDelegator *)delegator
{
    dispatch_async(self.serialQueue, ^{
        if (serviceConsumer.service == LCRTMServiceInstantMessaging) {
            if (self.defaultInstantMessagingPeerID) {
                if (![self.defaultInstantMessagingPeerID isEqualToString:serviceConsumer.peerID]) {
                    self.needPeerIDForEveryCommand = true;
                }
            } else {
                self.defaultInstantMessagingPeerID = serviceConsumer.peerID;
            }
            self.instantMessagingDelegatorMap[delegator.peerID] = delegator;
        } else if (serviceConsumer.service == LCRTMServiceLiveQuery) {
            self.liveQueryDelegatorMap[delegator.peerID] = delegator;
        }
        if (self.socket && self.timer) {
            dispatch_async(delegator.queue, ^{
                [delegator.delegate LCRTMConnectionDidConnect:self];
            });
        } else if (!self.socket && !self.timer) {
            NSError *error = [self checkEnvironment];
            if (error) {
                dispatch_async(delegator.queue, ^{
                    [delegator.delegate LCRTMConnection:self didDisconnectWithError:error];
                });
            } else {
                [self tryConnectingWithDelayInterval:(self.connectingFailedCount > 10
                                                      ? [self nextConnectingDelayInterval]
                                                      : 0)];
            }
        } else {
            /* in connecting, just wait. */
        }
    });
}

- (void)tryConnectingWithDelayInterval:(NSUInteger)delayInterval
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    if (![self canConnecting]) {
        return;
    }
    
}

// MARK: LCRTMWebSocket Delegate

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didOpenWithProtocol:(NSString *)protocol
{
    
}

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didCloseWithError:(NSError *)error
{
    
}

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didReceiveMessage:(LCRTMWebSocketMessage *)message
{
    
}

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didReceivePing:(NSData *)data
{
    
}

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didReceivePong:(NSData *)data
{
    
}

@end
