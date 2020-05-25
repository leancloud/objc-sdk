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

typedef NS_ENUM(NSUInteger, LCRTMService) {
    LCRTMServiceLiveQuery = 1,
    LCRTMServiceInstantMessaging = 2,
};

typedef NSString * LCIMProtocol NS_STRING_ENUM;
FOUNDATION_EXPORT LCIMProtocol const LCIMProtocol3;
FOUNDATION_EXPORT LCIMProtocol const LCIMProtocol1;

typedef NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, LCRTMConnection *> *> * LCRTMInstantMessagingRegistry;
typedef NSMutableDictionary<NSString *, LCRTMConnection *> * LCRTMLiveQueryRegistryRegistry;

@interface LCRTMServiceConsumer : NSObject

@property (nonatomic) AVApplication *application;
@property (nonatomic) LCRTMService service;
@property (nonatomic) NSString *peerID;
@property (nonatomic) LCIMProtocol protocol;

@end

@interface LCRTMConnectionManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic) LCRTMInstantMessagingRegistry imProtobuf3Registry;
@property (nonatomic) LCRTMInstantMessagingRegistry imProtobuf1Registry;
@property (nonatomic) LCRTMLiveQueryRegistryRegistry liveQueryRegistry;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (LCRTMConnection *)registerWithServiceConsumer:(LCRTMServiceConsumer *)serviceConsumer
                                           error:(NSError * __autoreleasing *)error;

- (void)unregisterWithServiceConsumer:(LCRTMServiceConsumer *)serviceConsumer;

@end

@protocol LCRTMConnectionDelegate <NSObject>

- (void)LCRTMConnectionInConnecting:(LCRTMConnection *)connection;

- (void)LCRTMConnectionDidConnect:(LCRTMConnection *)connection;

- (void)LCRTMConnection:(LCRTMConnection *)connection didDisconnectWithError:(NSError *)error;

- (void)LCRTMConnection:(LCRTMConnection *)connection didReceiveCommand:(AVIMGenericCommand *)inCommand;

@end

@interface LCRTMConnection : NSObject

@property (nonatomic, readonly) AVApplication *application;
@property (nonatomic, readonly) LCIMProtocol protocol;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
