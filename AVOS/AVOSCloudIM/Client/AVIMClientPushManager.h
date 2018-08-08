//
//  AVIMClientPushManager.h
//  AVOS
//
//  Created by zapcannon87 on 2018/7/30.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"

@class AVIMClient;
@class AVInstallation;

@interface AVIMClientPushManager : NSObject

@property (nonatomic, weak, readonly) AVIMClient *client;
@property (nonatomic, strong, readonly) AVInstallation *installation;
@property (nonatomic, strong, readonly) NSString *deviceToken;

- (instancetype)initWithInstallation:(AVInstallation *)installation client:(AVIMClient *)client;

- (void)addingClientIdToChannels;
- (void)removingClientIdFromChannels;
- (void)uploadingDeviceToken;

/// for unit test
- (void)saveInstallationWithAddingClientId:(BOOL)addingClientId callback:(void (^)(BOOL succeeded, NSError *error))callback;
- (void)uploadingDeviceToken:(BOOL)isUploaded callback:(void (^)(NSError *error))callback;

@end
