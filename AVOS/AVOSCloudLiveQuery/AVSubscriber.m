//
//  AVSubscriber.m
//  AVOS
//
//  Created by Tang Tianyong on 16/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVSubscriber.h"
#import "AVExponentialTimer.h"
#import "AVLiveQuery.h"
#import "AVLiveQuery_Internal.h"

/* AVOSCloud headers */
#import "AVUtils.h"
#import "AVObjectUtils.h"

/* AVOSCloudIM headers */
#import "AVIMWebSocketWrapper.h"
#import "MessagesProtoOrig.pbobjc.h"

typedef NS_ENUM(NSInteger, AVServiceType) {
    AVServiceTypeLiveQuery = 1
};

static NSString *const AVIdentifierPrefix = @"livequery";

static const NSTimeInterval AVBackoffInitialTime = 0.618;
static const NSTimeInterval AVBackoffMaximumTime = 60;

NSString *const AVLiveQueryEventKey = @"AVLiveQueryEventKey";
NSNotificationName AVLiveQueryEventNotification = @"AVLiveQueryEventNotification";

@interface AVSubscriber () <AVIMWebSocketWrapperDelegate> {
    
    NSHashTable<AVLiveQuery *> *_weakLiveQueryObjectTable;
    NSMutableArray<void (^)(BOOL, NSError *)> *_loginCallbackArray;
    dispatch_queue_t _internalSerialQueue;
    BOOL _isLoginCommandInHandshaking;
}

@property (nonatomic, assign) BOOL alive;
@property (nonatomic, strong) AVIMWebSocketWrapper *webSocket;
@property (nonatomic, strong) AVExponentialTimer   *backoffTimer;

@end

@implementation AVSubscriber

+ (instancetype)sharedInstance
{
    static AVSubscriber *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[AVSubscriber alloc] init];
    });

    return instance;
}

- (instancetype)init
{
    self = [super init];

    if (self) {
        
        NSString *deviceUUID = [AVUtils deviceUUID];
        self->_internalSerialQueue = dispatch_queue_create("AVSubscriber._internalSerialQueue", NULL);
        self->_weakLiveQueryObjectTable = [NSHashTable weakObjectsHashTable];
        self->_loginCallbackArray = nil;
        self->_alive = false;
        
        self->_webSocket = [[AVIMWebSocketWrapper alloc] initWithDelegate:self];
        self->_identifier = [NSString stringWithFormat:@"%@-%@", AVIdentifierPrefix, deviceUUID];
        self->_backoffTimer = [AVExponentialTimer exponentialTimerWithInitialTime:AVBackoffInitialTime
                                                                    maxTime:AVBackoffMaximumTime];
        self->_isLoginCommandInHandshaking = false;
    }

    return self;
}

- (void)dealloc
{
    [self.webSocket close];
}

// MARK: - Queue

- (void)addOperationToInternalSerialQueue:(void (^)(AVSubscriber *subscriber))block
{
    dispatch_async(_internalSerialQueue, ^{
        
        block(self);
    });
}

- (void)invokeCallback:(dispatch_block_t)block
{
    dispatch_queue_t queue = self.callbackQueue;
    
    if (queue) {
        
        dispatch_async(queue, block);
        
    } else {
        
        block();
    }
}

// MARK: - Websocket Delegate

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didCommandEncounterError:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
        if (commandWrapper.hasCallback && commandWrapper.error) {
            [commandWrapper executeCallbackAndSetItToNil];
        }
    }];
}

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didReceiveCommand:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
        AVIMGenericCommand *command = commandWrapper.inCommand;
        /* Filter out non-live-query commands. */
        if (command.service != AVServiceTypeLiveQuery)
            return;
        switch (command.cmd) {
            case AVIMCommandType_Data:
                [subscriber handleDataCommand:command];
                break;
            default:
                break;
        }
    }];
}

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didReceiveCommandCallback:(LCIMProtobufCommandWrapper *)commandWrapper
{
    [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
        if (commandWrapper.hasCallback) {
            [commandWrapper executeCallbackAndSetItToNil];
        }
    }];
}

- (void)webSocketWrapperDidReopen:(AVIMWebSocketWrapper *)socketWrapper
{
    [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
        [subscriber resentLoginCommand];
    }];
}

- (void)webSocketWrapperDidPause:(AVIMWebSocketWrapper *)socketWrapper
{
    [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
        subscriber.alive = false;
    }];
}

- (void)webSocketWrapper:(AVIMWebSocketWrapper *)socketWrapper didCloseWithError:(NSError *)error
{
    [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
        subscriber.alive = false;
    }];
}

- (void)handleDataCommand:(AVIMGenericCommand *)command {
    NSArray<AVIMJsonObjectMessage*> *messages = command.dataMessage.msgArray;

    for (AVIMJsonObjectMessage *message in messages)
        [self handleDataMessage:message];
}

- (void)handleDataMessage:(AVIMJsonObjectMessage *)message {
    NSString *JSONString = message.data_p;

    if (!JSONString)
        return;

    NSError *error = nil;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[JSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                               options:0
                                                                 error:&error];

    if (error || !dictionary)
        return;

    NSDictionary *event = (NSDictionary *)[AVObjectUtils objectFromDictionary:dictionary recursive:YES];
    NSDictionary *userInfo = @{ AVLiveQueryEventKey: event };

    [[NSNotificationCenter defaultCenter] postNotificationName:AVLiveQueryEventNotification
                                                        object:self
                                                      userInfo:userInfo];
}

// MARK: - Login

- (AVIMGenericCommand *)makeLoginCommand
{
    AVIMGenericCommand *command = [[AVIMGenericCommand alloc] init];

    command.cmd             = AVIMCommandType_Login;
    command.appId           = [AVOSCloud getApplicationId];
    command.installationId  = self.identifier;
    command.service         = AVServiceTypeLiveQuery;

    return command;
}

- (void)invokeAllLoginCallbackWithSucceeded:(BOOL)succeeded error:(NSError *)error
{
    NSArray<void (^)(BOOL, NSError *)> *callbacks = self->_loginCallbackArray;
    if (!callbacks) { return; }
    self->_loginCallbackArray = nil;
    [self invokeCallback:^{
        for (void (^callback)(BOOL, NSError *) in callbacks) {
            callback(succeeded, error);
        }
    }];
}

- (void)loginWithCallback:(void (^)(BOOL succeeded, NSError *error))callback
{
    [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
        
        if (subscriber.alive) {
            [subscriber invokeCallback:^{
                callback(true, nil);
            }];
            return;
        }
        
        if (subscriber->_loginCallbackArray) {
            [subscriber->_loginCallbackArray addObject:callback];
        } else {
            subscriber->_loginCallbackArray = [NSMutableArray arrayWithObject:callback];
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = [subscriber makeLoginCommand];
            [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
                subscriber->_isLoginCommandInHandshaking = false;
                NSError *error = commandWrapper.error;
                AVIMGenericCommand *inCommand = commandWrapper.inCommand;
                subscriber.alive = (!error && inCommand && inCommand.cmd == AVIMCommandType_Loggedin);
                if (subscriber.alive) {
                    [subscriber.backoffTimer reset];
                    [subscriber invokeAllLoginCallbackWithSucceeded:true error:nil];
                    [subscriber.webSocket setActivatingReconnectionEnabled:true];
                } else {
                    [subscriber resentLoginCommand];
                }
            }];
            
            [subscriber.webSocket openWithCallback:^(BOOL succeeded, NSError *error) {
                [subscriber addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
                    if (error) {
                        [subscriber invokeAllLoginCallbackWithSucceeded:false error:error];
                    } else {
                        subscriber->_isLoginCommandInHandshaking = true;
                        [subscriber.webSocket sendCommandWrapper:commandWrapper];
                    }
                }];
            }];
        }
    }];
}

- (void)resentLoginCommand
{
    if (self->_isLoginCommandInHandshaking) {
        return;
    }
    if (self.alive) {
        [self invokeAllLoginCallbackWithSucceeded:true error:nil];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
    commandWrapper.outCommand = [self makeLoginCommand];
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        NSError *error = commandWrapper.error;
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        self.alive = (!error && inCommand && inCommand.cmd == AVIMCommandType_Loggedin);
        if (self.alive) {
            [self.backoffTimer reset];
            [self invokeAllLoginCallbackWithSucceeded:true error:nil];
            NSArray<AVLiveQuery *> *livingObjects = [self->_weakLiveQueryObjectTable allObjects];
            BOOL liveQueryExist = false;
            for (AVLiveQuery *item in livingObjects) {
                if (item) {
                    liveQueryExist = true;
                    [item resubscribe];
                }
            }
            [self.webSocket setActivatingReconnectionEnabled:liveQueryExist];
        } else {
            NSTimeInterval after = [self.backoffTimer timeIntervalAndCalculateNext];
            dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(after * NSEC_PER_SEC));
            dispatch_after(when, self->_internalSerialQueue, ^{
                [self resentLoginCommand];
            });
        }
    }];
    [self.webSocket sendCommandWrapper:commandWrapper];
}

// MARK: - Weak Retainer

- (void)addLiveQueryObjectToWeakTable:(AVLiveQuery *)liveQueryObject
{
    [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
        
        [subscriber->_weakLiveQueryObjectTable addObject:liveQueryObject];
    }];
}

- (void)removeLiveQueryObjectFromWeakTable:(AVLiveQuery *)liveQueryObject
{
    [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
        
        [subscriber->_weakLiveQueryObjectTable removeObject:liveQueryObject];
    }];
}

@end
