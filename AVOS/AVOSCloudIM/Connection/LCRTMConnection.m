//
//  LCRTMConnection.m
//  AVOSCloudIM
//
//  Created by pzheng on 2020/05/20.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

#import "LCRTMConnection.h"

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

@interface LCRTMConnection ()

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
        _callback = callback;
    }
    return self;
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
#if DEBUG
        dispatch_queue_set_specific(_serialQueue,
                                    (__bridge void *)_serialQueue,
                                    (__bridge void *)_serialQueue,
                                    NULL);
#endif
        __weak typeof(self) weakSelf = self;
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
            [weakSelf applicationStateChanged:LCRTMConnectionAppStateBackground];
        }];
        _enterForegroundObserver = [NSNotificationCenter.defaultCenter
                                    addObserverForName:UIApplicationWillEnterForegroundNotification
                                    object:nil
                                    queue:appStateQueue
                                    usingBlock:^(NSNotification * _Nonnull note) {
            [weakSelf applicationStateChanged:LCRTMConnectionAppStateForeground];
        }];
#endif
#if !TARGET_OS_WATCH
        _reachabilityManager = [LCNetworkReachabilityManager manager];
        _reachabilityManager.reachabilityQueue = _serialQueue;
        _previousReachabilityStatus = _reachabilityManager.networkReachabilityStatus;
        [_reachabilityManager setReachabilityStatusChangeBlock:^(LCNetworkReachabilityStatus status) {
            [weakSelf networkReachabilityStatusChanged:status];
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

@end
