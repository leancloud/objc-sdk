//
//  LCRTMConnection.h
//  AVOSCloudIM
//
//  Created by pzheng on 2020/05/20.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MessagesProtoOrig.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

@class LCRTMConnection;
@class AVApplication;

typedef NS_ENUM(int32_t, LCRTMService) {
    LCRTMServiceLiveQuery = 1,
    LCRTMServiceInstantMessaging = 2,
};

typedef NSString * LCIMProtocol NS_STRING_ENUM;
FOUNDATION_EXPORT LCIMProtocol const LCIMProtocol3;
FOUNDATION_EXPORT LCIMProtocol const LCIMProtocol1;

typedef void(^LCRTMConnectionOutCommandCallback)(AVIMGenericCommand * _Nullable inCommand, NSError * _Nullable error);

@interface LCRTMServiceConsumer : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, readonly) AVApplication *application;
@property (nonatomic, readonly) LCRTMService service;
@property (nonatomic, readonly) LCIMProtocol protocol;
@property (nonatomic, readonly) NSString *peerID;

- (instancetype)initWithApplication:(AVApplication *)application
                            service:(LCRTMService)service
                           protocol:(LCIMProtocol)protocol
                             peerID:(NSString *)peerID NS_DESIGNATED_INITIALIZER;

@end

@interface LCRTMConnectionManager : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)sharedManager;

- (nullable LCRTMConnection *)registerWithServiceConsumer:(LCRTMServiceConsumer *)serviceConsumer
                                                    error:(NSError **)error;

- (void)unregisterWithServiceConsumer:(LCRTMServiceConsumer *)serviceConsumer;

@end

@protocol LCRTMConnectionDelegate <NSObject>

- (void)LCRTMConnectionInConnecting:(LCRTMConnection *)connection;

- (void)LCRTMConnectionDidConnect:(LCRTMConnection *)connection;

- (void)LCRTMConnection:(LCRTMConnection *)connection didDisconnectWithError:(NSError * _Nullable)error;

- (void)LCRTMConnection:(LCRTMConnection *)connection didReceiveCommand:(AVIMGenericCommand *)inCommand;

@end

@interface LCRTMConnectionDelegator : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, readonly) NSString *peerID;
@property (nonatomic, readonly) dispatch_queue_t queue;
@property (nonatomic, weak) id<LCRTMConnectionDelegate> delegate;

- (instancetype)initWithPeerID:(NSString *)peerID
                      delegate:(id<LCRTMConnectionDelegate>)delegate
                         queue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

@end

@interface LCRTMConnection : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, readonly) AVApplication *application;
@property (nonatomic, readonly) LCIMProtocol protocol;

+ (void)setConnectingTimeoutInterval:(NSTimeInterval)timeoutInterval;

- (void)connectWithServiceConsumer:(LCRTMServiceConsumer *)serviceConsumer
                         delegator:(LCRTMConnectionDelegator *)delegator;

- (void)removeDelegatorWithServiceConsumer:(LCRTMServiceConsumer *)serviceConsumer;

- (void)sendCommand:(AVIMGenericCommand *)command
            service:(LCRTMService)service
             peerID:(NSString *)peerID
            onQueue:(dispatch_queue_t _Nullable)queue
           callback:(LCRTMConnectionOutCommandCallback _Nullable)callback;

@end

NS_ASSUME_NONNULL_END
