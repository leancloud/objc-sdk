//
//  AVIMClientPushManager.m
//  AVOS
//
//  Created by zapcannon87 on 2018/7/30.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMClientPushManager.h"
#import "AVIMCommon_Internal.h"
#import "AVIMClient_Internal.h"

#import "AVUtils.h"

typedef NS_ENUM(NSInteger, AddClientIdToChannelsStatus) {
    AddClientIdToChannelsStatusError = -1,
    AddClientIdToChannelsStatusNone = 0,
    AddClientIdToChannelsStatusSaving = 1,
    AddClientIdToChannelsStatusSaved = 2,
};

@interface AVIMClientPushManager ()

@property (nonatomic, strong) NSString *clientId;
@property (nonatomic, assign) AddClientIdToChannelsStatus addClientIdToChannelsStatus;

@end

@implementation AVIMClientPushManager {
#if DEBUG
    dispatch_queue_t _internalSerialQueue;
#endif
}

- (instancetype)initWithInstallation:(AVInstallation *)installation client:(AVIMClient *)client
{
    self = [super init];
    if (self) {
#if DEBUG
        self->_internalSerialQueue = client.internalSerialQueue;
#endif
        self->_installation = installation;
        self->_client = client;
        self->_clientId = client.clientId;
        self->_deviceToken = installation.deviceToken;
        self->_addClientIdToChannelsStatus = AddClientIdToChannelsStatusNone;
        
        [self->_installation addObserver:self
                              forKeyPath:keyPath(self->_installation, deviceToken)
                                 options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                                 context:nil];
    }
    return self;
}

- (void)dealloc
{
    [self.installation removeObserver:self forKeyPath:keyPath(self.installation, deviceToken)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (object == self.installation &&
        [keyPath isEqualToString:keyPath(self.installation, deviceToken)])
    {
        NSString *newDeviceToken = [NSString lc__decodingDictionary:change key:NSKeyValueChangeNewKey];
        if (newDeviceToken && newDeviceToken.length != 0) {
            [self.client addOperationToInternalSerialQueue:^(AVIMClient *client) {
                if (![self.deviceToken isEqualToString:newDeviceToken]) {
                    self->_deviceToken = newDeviceToken;
                    if (client.status == AVIMClientStatusOpened) {
                        [self uploadDeviceTokenWithCallback:nil];
                        if (self.addClientIdToChannelsStatus != AddClientIdToChannelsStatusError) {
                            self.addClientIdToChannelsStatus = AddClientIdToChannelsStatusNone;
                            [self addingClientIdToChannels];
                        }
                    }
                }
            }];
        }
    }
}

- (void)addingClientIdToChannels
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    if (!self.deviceToken ||
        self.deviceToken.length == 0 ||
        self.addClientIdToChannelsStatus != AddClientIdToChannelsStatusNone) {
        return;
    }
    self.addClientIdToChannelsStatus = AddClientIdToChannelsStatusSaving;
    [self saveInstallationWithAddingClientId:true callback:^(BOOL succeeded, NSError *error) {
        [self.client addOperationToInternalSerialQueue:^(AVIMClient *client) {
            if (error) {
                AVLoggerError(AVLoggerDomainIM, @"%@", error);
                if (error.code == kAVErrorInvalidChannelName) {
                    self.addClientIdToChannelsStatus = AddClientIdToChannelsStatusError;
                } else {
                    self.addClientIdToChannelsStatus = AddClientIdToChannelsStatusNone;
                }
            }
            else if (self.addClientIdToChannelsStatus == AddClientIdToChannelsStatusSaving) {
                self.addClientIdToChannelsStatus = AddClientIdToChannelsStatusSaved;
            }
        }];
    }];
}

- (void)removingClientIdFromChannels
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    if (!self.deviceToken ||
        self.deviceToken.length == 0 ||
        self.addClientIdToChannelsStatus == AddClientIdToChannelsStatusError) {
        return;
    }
    [self saveInstallationWithAddingClientId:false callback:^(BOOL succeeded, NSError *error) {
        [self.client addOperationToInternalSerialQueue:^(AVIMClient *client) {
            if (error) {
                AVLoggerError(AVLoggerDomainIM, @"%@", error);
                if (error.code == kAVErrorInvalidChannelName) {
                    self.addClientIdToChannelsStatus = AddClientIdToChannelsStatusError;
                    return;
                }
            }
            self.addClientIdToChannelsStatus = AddClientIdToChannelsStatusNone;
        }];
    }];
}

- (void)saveInstallationWithAddingClientId:(BOOL)addingClientId callback:(void (^)(BOOL succeeded, NSError *error))callback
{
    if (addingClientId) {
        [self.installation addUniqueObject:self.clientId forKey:@"channels"];
    } else {
        [self.installation removeObject:self.clientId forKey:@"channels"];
    }
    [self.installation saveInBackgroundWithBlock:callback];
}

- (void)uploadDeviceTokenWithCallback:(void (^)(NSError *error))callback
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    if (!self.deviceToken || self.deviceToken.length == 0) {
        if (callback) { callback(nil); }
        return;
    }
    
    AVIMClient *client = self.client;
    if (!client || client.status != AVIMClientStatusOpened) {
        if (callback) { callback(nil); }
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMReportCommand *reportCommand = [AVIMReportCommand new];
        outCommand.cmd = AVIMCommandType_Report;
        outCommand.op = AVIMOpType_Upload;
        outCommand.reportMessage = reportCommand;
        reportCommand.initiative = true;
        reportCommand.type = @"token";
        reportCommand.data_p = self.deviceToken;
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        if (callback) {
            if (commandWrapper.error) {
                callback(commandWrapper.error);
            } else {
                callback(nil);
            }
        }
    }];
    [client sendCommandWrapper:commandWrapper];
}

@end
