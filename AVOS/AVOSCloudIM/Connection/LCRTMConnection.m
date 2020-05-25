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

LCIMProtocol const LCIMProtocol3 = @"lc.protobuf2.3";
LCIMProtocol const LCIMProtocol1 = @"lc.protobuf2.1";

// MARK: Interface

@interface LCRTMConnectionManager ()

@property (nonatomic) NSLock *lock;

@end

@interface LCRTMConnection ()

@property (nonatomic) dispatch_queue_t serialQueue;

- (instancetype)initWithApplication:(AVApplication *)application
                           protocol:(LCIMProtocol)protocol
                              error:(NSError * __autoreleasing *)error;

@end

// MARK: Implementation

@implementation LCRTMServiceConsumer

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

@implementation LCRTMConnection

- (instancetype)initWithApplication:(AVApplication *)application
                           protocol:(LCIMProtocol)protocol
                              error:(NSError *__autoreleasing *)error
{
    self = [super init];
    if (self) {
        _application = application;
        _protocol = protocol;
        _serialQueue = dispatch_queue_create("LCRTMConnection.serialQueue", NULL);
    }
    return self;
}

@end
