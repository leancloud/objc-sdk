//
//  LCRTMConnection.h
//  AVOSCloudIM
//
//  Created by pzheng on 2020/05/20.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LCRTMService) {
    LCRTMServiceLiveQuery = 1,
    LCRTMServiceInstantMessaging = 2,
};

@class LCRTMConnection;

typedef NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, LCRTMConnection *> *> * LCRTMInstantMessagingRegistry;
typedef NSMutableDictionary<NSString *, LCRTMConnection *> * LCRTMLiveQueryRegistryRegistry;

@interface LCRTMConnectionManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic) LCRTMInstantMessagingRegistry imProtobuf1Registry;
@property (nonatomic) LCRTMInstantMessagingRegistry imProtobuf3Registry;
@property (nonatomic) LCRTMLiveQueryRegistryRegistry liveQueryRegistry;

@end

@interface LCRTMConnection : NSObject

@end

NS_ASSUME_NONNULL_END
