//
//  LCRTMConnection.m
//  AVOSCloudIM
//
//  Created by pzheng on 2020/05/20.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

#import "LCRTMConnection.h"
#import "LCRTMWebSocket.h"

#import "AVApplication_Internal.h"
#import "LCRouter_Internal.h"
#import "AVLogger.h"
#import "AVUtils.h"
#import "AVErrorUtils.h"
#import "AVOSCloudIM.h"
#import "AVIMCommon_Internal.h"

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

static NSTimeInterval gLCRTMConnectionConnectingTimeoutInterval = 0;

// MARK: Interface

@interface LCRTMConnectionManager ()

@property (nonatomic) NSLock *lock;

@end

@interface LCRTMConnectionOutCommand : NSObject

@property (nonatomic, readonly) NSString *peerID;
@property (nonatomic, readonly) AVIMGenericCommand *command;
@property (nonatomic, readonly) dispatch_queue_t callingQueue;
@property (nonatomic, readonly) NSMutableArray<LCRTMConnectionOutCommandCallback> *callbacks;
@property (nonatomic, readonly) NSDate *expiration;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithPeerID:(NSString *)peerID
                       command:(AVIMGenericCommand *)command
                  callingQueue:(dispatch_queue_t)callingQueue
                      callback:(LCRTMConnectionOutCommandCallback)callback NS_DESIGNATED_INITIALIZER;

- (BOOL)microIdempotentFor:(AVIMGenericCommand *)outCommand
                      from:(NSString *)peerID
                     queue:(dispatch_queue_t)queue;

@end

@interface LCRTMConnectionTimer : NSObject

@property (nonatomic, readonly) NSTimeInterval pingpongInterval;
@property (nonatomic, readonly) NSTimeInterval pingTimeout;
@property (nonatomic) NSTimeInterval lastPingSentTimestamp;
@property (nonatomic) NSTimeInterval lastPongReceivedTimestamp;
@property (nonatomic) dispatch_source_t source;
@property (nonatomic) LCRTMWebSocket *socket;
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

- (void)receivePong;

- (BOOL)tryThrottling:(AVIMGenericCommand *)outCommand
                 from:(NSString *)peerID
                queue:(dispatch_queue_t)queue
             callback:(LCRTMConnectionOutCommandCallback)callback;

- (void)appendOutCommand:(LCRTMConnectionOutCommand *)outCommand
                   index:(NSNumber *)index;

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
@property (nonatomic) BOOL needPeerIDForEveryCommandOfInstantMessaging;
@property (nonatomic) LCRTMConnectionTimer *timer;
@property (nonatomic) LCRTMWebSocket *socket;
@property (nonatomic) dispatch_block_t previousConnectingBlock;
@property (nonatomic) BOOL useSecondaryServer;
@property (nonatomic) NSUInteger connectingDelayInterval;
@property (nonatomic) NSUInteger connectingFailedCount;

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
        NSString *appID = [serviceConsumer.application identifierThrowException];
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
        NSString *appID = [serviceConsumer.application identifierThrowException];
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
        _callbacks = [NSMutableArray arrayWithObject:callback];
        _expiration = [NSDate dateWithTimeIntervalSinceNow:30.0];
    }
    return self;
}

- (BOOL)microIdempotentFor:(AVIMGenericCommand *)outCommand
                      from:(NSString *)peerID
                     queue:(dispatch_queue_t)queue
{
    if (![self.peerID isEqualToString:peerID] ||
        self.callingQueue != queue ||
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
    return (outCommand.cmd == self.command.cmd &&
            outCommand.op == self.command.op &&
            [outCommand isEqual:self.command]);
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
        dispatch_source_set_event_handler(_source, ^{
            /*
             For performance, not use weak-self,
             so need to call `-cleanInCurrentQueue:` to break retain-cycle before release it.
             */
            NSDate *currentDate = [NSDate date];
            [self checkCommandTimeout:currentDate];
            [self checkPingPong:currentDate];
        });
        UInt64 interval = 1;
        dispatch_source_set_timer(_source,
                                  DISPATCH_TIME_NOW,
                                  NSEC_PER_SEC * interval,
                                  NSEC_PER_SEC * interval);
        dispatch_resume(_source);
    }
    return self;
}

- (void)dealloc
{
    // TODO: log
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

- (void)receivePong
{
    NSParameterAssert([self assertSpecificQueue]);
    // TODO: log
    self.lastPongReceivedTimestamp = [NSDate date].timeIntervalSince1970;
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
        [self.socket sendPing:[NSData data] completion:^{
            NSParameterAssert([self assertSpecificQueue]);
            // TODO: log
            self.lastPingSentTimestamp = currentTimestamp;
        }];
    }
}

- (BOOL)tryThrottling:(AVIMGenericCommand *)outCommand
                 from:(NSString *)peerID
                queue:(dispatch_queue_t)queue
             callback:(LCRTMConnectionOutCommandCallback)callback
{
    NSParameterAssert([self assertSpecificQueue]);
    for (NSNumber *i in self.outCommandIndexSequence) {
        LCRTMConnectionOutCommand *command = self.outCommandCollection[i];
        if ([command microIdempotentFor:outCommand
                                   from:peerID
                                  queue:queue]) {
            [command.callbacks addObject:callback];
            return true;
        }
    }
    return false;
}

- (void)appendOutCommand:(LCRTMConnectionOutCommand *)outCommand
                   index:(NSNumber *)index
{
    NSParameterAssert([self assertSpecificQueue]);
    [self.outCommandIndexSequence addObject:index];
    self.outCommandCollection[index] = outCommand;
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
        self.socket = nil;
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

+ (void)setConnectingTimeoutInterval:(NSTimeInterval)timeoutInterval
{
    gLCRTMConnectionConnectingTimeoutInterval = timeoutInterval;
}

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
        _needPeerIDForEveryCommandOfInstantMessaging = false;
        _timer = nil;
        _socket = nil;
        _previousConnectingBlock = nil;
        _useSecondaryServer = false;
        _connectingDelayInterval = 0;
        _connectingFailedCount = 0;
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
    // TODO: log
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
- (void)applicationStateChanged:(LCRTMConnectionAppState)newState
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    LCRTMConnectionAppState oldState = self.previousAppState;
    self.previousAppState = newState;
    if (oldState == LCRTMConnectionAppStateBackground &&
        newState == LCRTMConnectionAppStateForeground) {
        [self tryConnectingWithDelay:false];
    } else if (oldState == LCRTMConnectionAppStateForeground &&
               newState == LCRTMConnectionAppStateBackground) {
        [self tryCleanConnectionWithError:
         LCError(AVIMErrorCodeConnectionLost,
                 @"Application did enter background, connection lost.", nil)];
        self.connectingDelayInterval = 0;
    }
}
#endif

#if !TARGET_OS_WATCH
- (void)networkReachabilityStatusChanged:(LCNetworkReachabilityStatus)newStatus
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    LCNetworkReachabilityStatus oldStatus = self.previousReachabilityStatus;
    self.previousReachabilityStatus = newStatus;
    if (oldStatus != LCNetworkReachabilityStatusNotReachable &&
        newStatus == LCNetworkReachabilityStatusNotReachable) {
        [self tryCleanConnectionWithError:
         LCError(AVIMErrorCodeConnectionLost,
                 @"Network not reachable, connection lost.", nil)];
        self.connectingDelayInterval = 0;
    } else if (oldStatus != newStatus &&
               newStatus != LCNetworkReachabilityStatusNotReachable) {
        [self tryCleanConnectionWithError:
         LCError(AVIMErrorCodeConnectionLost,
                 @"Network interface changed, connection lost.", nil)];
        self.connectingDelayInterval = 0;
        [self tryConnectingWithDelay:false];
    }
}
#endif

- (BOOL)hasDelegator
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    return (self.instantMessagingDelegatorMap.count > 0 ||
            self.liveQueryDelegatorMap.count > 0);
}

- (NSArray<LCRTMConnectionDelegator *> *)allDelegators
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    return [self.instantMessagingDelegatorMap.allValues
            arrayByAddingObjectsFromArray:self.liveQueryDelegatorMap.allValues];
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
                [self tryConnectingWithDelay:(self.connectingFailedCount > 10)];
            }
        } else {
            /* in connecting, just wait. */
        }
    });
}

- (void)tryConnectingWithDelay:(BOOL)delay
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    if (![self canConnecting]) {
        return;
    }
    for (LCRTMConnectionDelegator *delegator in [self allDelegators]) {
        dispatch_async(delegator.queue, ^{
            [delegator.delegate LCRTMConnectionInConnecting:self];
        });
    }
    if (self.previousConnectingBlock) {
        dispatch_block_cancel(self.previousConnectingBlock);
        self.previousConnectingBlock = nil;
    }
    __weak typeof(self) ws = self;
    self.previousConnectingBlock = dispatch_block_create(0, ^{
        LCRTMConnection *ss = ws;
        if (ss) {
            NSParameterAssert([ss assertSpecificSerialQueue]);
            ss.previousConnectingBlock = nil;
            [ss connect];
        }
    });
    if (delay) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     NSEC_PER_SEC * [self nextConnectingDelayInterval]),
                       self.serialQueue,
                       self.previousConnectingBlock);
    } else {
        self.previousConnectingBlock();
    }
}

- (void)connect
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    [self getRTMServerWithCompletion:^(LCRTMConnection *connection, NSURL *serverURL, NSError *error) {
        NSParameterAssert([connection assertSpecificSerialQueue]);
        if (![connection canConnecting]) {
            return;
        }
        if (serverURL) {
            connection.socket = [[LCRTMWebSocket alloc] initWithURL:serverURL
                                                          protocols:@[connection.protocol]];
            [connection.socket.request setValue:nil
                             forHTTPHeaderField:@"Origin"];
            if (gLCRTMConnectionConnectingTimeoutInterval > 0) {
                connection.socket.request.timeoutInterval = gLCRTMConnectionConnectingTimeoutInterval;
            }
            connection.socket.delegateQueue = connection.serialQueue;
            connection.socket.delegate = connection;
            [connection.socket open];
        } else {
            for (LCRTMConnectionDelegator *delegator in [connection allDelegators]) {
                dispatch_async(delegator.queue, ^{
                    [delegator.delegate LCRTMConnection:connection didDisconnectWithError:error];
                });
            }
            [connection tryConnectingWithDelay:true];
        }
    }];
}

- (void)getRTMServerWithCompletion:(void(^)(LCRTMConnection *connection, NSURL *serverURL, NSError *error))completion
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    if ([AVOSCloudIM defaultOptions].RTMServer) {
        completion(self, [NSURL URLWithString:[AVOSCloudIM defaultOptions].RTMServer], nil);
    } else {
        __weak typeof(self) ws = self;
        [[LCRouter sharedInstance] getRTMURLWithAppID:[self.application identifierThrowException]
                                             callback:^(NSDictionary *dictionary, NSError *error) {
            LCRTMConnection *ss = ws;
            if (!ss) {
                return;
            }
            if (error) {
                dispatch_async(ss.serialQueue, ^{
                    completion(ss, nil, error);
                });
            } else {
                NSString *primaryServer = [NSString _lc_decoding:dictionary
                                                             key:RouterKeyRTMServer];
                NSString *secondaryServer = [NSString _lc_decoding:dictionary
                                                               key:RouterKeyRTMSecondary];
                dispatch_async(ss.serialQueue, ^{
                    NSString *server = ((ss.useSecondaryServer
                                         ? secondaryServer
                                         : primaryServer)
                                        ?: primaryServer);
                    NSURL *serverURL;
                    if (server) {
                        serverURL = [NSURL URLWithString:server];
                    }
                    completion(ss,
                               serverURL,
                               (serverURL
                                ? nil
                                : LCError(AVErrorInternalErrorCodeNotFound,
                                          @"RTM server URL not found.", nil)));
                });
            }
        }];
    }
}

- (void)removeDelegatorWithServiceConsumer:(LCRTMServiceConsumer *)serviceConsumer
{
    dispatch_async(self.serialQueue, ^{
        if (serviceConsumer.service == LCRTMServiceInstantMessaging) {
            [self.instantMessagingDelegatorMap removeObjectForKey:serviceConsumer.peerID];
        } else if (serviceConsumer.service == LCRTMServiceLiveQuery) {
            [self.liveQueryDelegatorMap removeObjectForKey:serviceConsumer.peerID];
        } else {
            [NSException raise:NSInternalInconsistencyException
                        format:@"should not happen"];
        }
    });
}

- (void)tryCleanConnectionWithError:(NSError *)error
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    if (self.previousConnectingBlock) {
        dispatch_block_cancel(self.previousConnectingBlock);
        self.previousConnectingBlock = nil;
    }
    if (self.timer) {
        [self.timer cleanInCurrentQueue:true];
        self.timer = nil;
    }
    if (self.socket) {
        self.socket.delegate = nil;
        [self.socket closeWithCloseCode:LCRTMWebSocketCloseCodeNormalClosure
                                 reason:nil];
        [self.socket clean];
        self.socket = nil;
    }
    if (error) {
        for (LCRTMConnectionDelegator *delegator in [self allDelegators]) {
            dispatch_async(delegator.queue, ^{
                [delegator.delegate LCRTMConnection:self didDisconnectWithError:error];
            });
        }
    }
}

- (void)handleGoaway:(AVIMGenericCommand *)inCommand
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    if (inCommand.cmd == AVIMCommandType_Goaway) {
        NSError *error;
        [[LCRouter sharedInstance] cleanCacheWithApplication:self.application
                                                         key:RouterCacheKeyRTM
                                                       error:&error];
        if (error) {
            AVLoggerError(AVLoggerDomainIM, @"%@", error);
        }
        [self tryCleanConnectionWithError:
         LCError(AVIMErrorCodeConnectionLost,
                 @"Connection did close by remote peer.", nil)];
        self.connectingDelayInterval = 0;
        [self tryConnectingWithDelay:false];
    }
}

- (void)sendCommand:(AVIMGenericCommand *)command
            service:(LCRTMService)service
             peerID:(NSString *)peerID
            onQueue:(dispatch_queue_t)queue
           callback:(LCRTMConnectionOutCommandCallback)callback
{
    dispatch_async(self.serialQueue, ^{
        if (!self.socket ||
            !self.timer) {
            if (queue && callback) {
                dispatch_async(queue, ^{
                    callback(nil, LCError(AVIMErrorCodeConnectionLost,
                                          @"Connection lost.", nil));
                });
            }
            return;
        }
        if (service == LCRTMServiceInstantMessaging) {
            [self tryPadPeerID:peerID forCommand:command];
        }
        if (queue && callback) {
            if ([self.timer tryThrottling:command
                                     from:peerID
                                    queue:queue
                                 callback:callback]) {
                return;
            }
            command.i = [self.timer nextIndex];
        }
        NSData *data = [command data];
        if (!data) {
            if (queue && callback) {
                dispatch_async(queue, ^{
                    callback(nil, LCError(AVIMErrorCodeInvalidCommand,
                                          @"Serializing out command failed.", nil));
                });
            }
            return;
        } else if (data.length > (1024 * 5)) {
            if (queue && callback) {
                dispatch_async(queue, ^{
                    callback(nil, LCError(AVIMErrorCodeCommandDataLengthTooLong,
                                          @"The size of the out command should less than 5KB.", nil));
                });
            }
            return;
        }
        if (queue && callback) {
            [self.timer appendOutCommand:[[LCRTMConnectionOutCommand alloc]
                                          initWithPeerID:peerID
                                          command:command
                                          callingQueue:queue
                                          callback:callback]
                                   index:@(command.i)];
        }
        [self.socket sendMessage:[LCRTMWebSocketMessage messageWithData:data] completion:^{
            NSParameterAssert([self assertSpecificSerialQueue]);
            // TODO: log
        }];
    });
}

- (void)tryPadPeerID:(NSString *)peerID
          forCommand:(AVIMGenericCommand *)command
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    if (command.cmd == AVIMCommandType_Session &&
        command.op == AVIMOpType_Open) {
        if (self.defaultInstantMessagingPeerID) {
            if (![self.defaultInstantMessagingPeerID isEqualToString:peerID]) {
                self.needPeerIDForEveryCommandOfInstantMessaging = true;
            }
        } else {
            self.defaultInstantMessagingPeerID = peerID;
        }
    } else if (self.needPeerIDForEveryCommandOfInstantMessaging) {
        command.peerId = peerID;
    }
}

// MARK: LCRTMWebSocket Delegate

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didOpenWithProtocol:(NSString *)protocol
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    NSParameterAssert(self.socket == socket && !self.timer);
    // TODO: log
    self.defaultInstantMessagingPeerID = nil;
    self.needPeerIDForEveryCommandOfInstantMessaging = false;
    self.connectingDelayInterval = 0;
    self.connectingFailedCount = 0;
    self.timer = [[LCRTMConnectionTimer alloc] initWithQueue:self.serialQueue
                                                      socket:socket];
    for (LCRTMConnectionDelegator *delegator in [self allDelegators]) {
        dispatch_async(delegator.queue, ^{
            [delegator.delegate LCRTMConnectionDidConnect:self];
        });
    }
}

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didCloseWithError:(NSError *)error
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    NSParameterAssert(self.socket == socket);
    // TODO: log
    if (!error) {
        error = LCError(AVIMErrorCodeConnectionLost,
                        @"Connection did close by remote peer.", nil);
    }
    [self tryCleanConnectionWithError:error];
    self.useSecondaryServer = !self.useSecondaryServer;
    [self tryConnectingWithDelay:true];
}

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didReceiveMessage:(LCRTMWebSocketMessage *)message
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    NSParameterAssert(self.socket == socket && self.timer);
    if (message.type == LCRTMWebSocketMessageTypeData &&
        message.data) {
        NSError *error;
        AVIMGenericCommand *inCommand = [AVIMGenericCommand parseFromData:message.data
                                                                    error:&error];
        if (error) {
            AVLoggerError(AVLoggerDomainIM, @"%@", error);
            return;
        }
        // TODO: log
        if (inCommand.hasI) {
            [self.timer handleCallbackCommand:inCommand];
        } else {
            LCRTMConnectionDelegator *delegator;
            if (inCommand.service == LCRTMServiceInstantMessaging) {
                NSString *peerID = (inCommand.hasPeerId
                                    ? inCommand.peerId
                                    : self.defaultInstantMessagingPeerID);
                if (peerID) {
                    delegator = self.instantMessagingDelegatorMap[peerID];
                }
            } else if (inCommand.service == LCRTMServiceLiveQuery) {
                NSString *installationID = (inCommand.hasInstallationId
                                            ? inCommand.installationId
                                            : nil);
                if (installationID) {
                    delegator = self.liveQueryDelegatorMap[installationID];
                }
            }
            if (delegator) {
                dispatch_async(delegator.queue, ^{
                    [delegator.delegate LCRTMConnection:self
                                      didReceiveCommand:inCommand];
                });
            }
        }
        [self handleGoaway:inCommand];
    }
}

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didReceivePing:(NSData *)data
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    NSParameterAssert(self.socket == socket && self.timer);
    [self.socket sendPong:data completion:^{
        NSParameterAssert([self assertSpecificSerialQueue]);
        // TODO: log
    }];
}

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didReceivePong:(NSData *)data
{
    NSParameterAssert([self assertSpecificSerialQueue]);
    NSParameterAssert(self.socket == socket && self.timer);
    [self.timer receivePong];
}

@end