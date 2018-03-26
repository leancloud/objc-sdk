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

@interface AVSubscriber () {
    
    NSHashTable<AVLiveQuery *> *_weakLiveQueryObjectTable;
    NSMutableArray<void (^)(BOOL, NSError *)> *_loginCallbackArray;
    dispatch_queue_t _internalSerialQueue;
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
        _internalSerialQueue = dispatch_queue_create("AVSubscriber._internalSerialQueue", NULL);
        _weakLiveQueryObjectTable = [NSHashTable weakObjectsHashTable];
        _loginCallbackArray = nil;
        _alive = false;
        
        _webSocket = [AVIMWebSocketWrapper newByLiveQuery];
        _identifier = [NSString stringWithFormat:@"%@-%@", AVIdentifierPrefix, deviceUUID];
        _backoffTimer = [AVExponentialTimer exponentialTimerWithInitialTime:AVBackoffInitialTime
                                                                    maxTime:AVBackoffMaximumTime];
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        
        [notificationCenter addObserver:self
                               selector:@selector(webSocketDidReopen:)
                                   name:AVIM_NOTIFICATION_WEBSOCKET_OPENED
                                 object:_webSocket];
        
        [notificationCenter addObserver:self
                               selector:@selector(webSocketDidReceiveCommand:)
                                   name:AVIM_NOTIFICATION_WEBSOCKET_COMMAND
                                 object:_webSocket];
        
        [notificationCenter addObserver:self
                               selector:@selector(webSocketDidClose:)
                                   name:AVIM_NOTIFICATION_WEBSOCKET_CLOSED
                                 object:_webSocket];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

// MARK: - Websocket Notification

- (void)webSocketDidReopen:(NSNotification *)notification
{
    [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
        
        [subscriber resentLoginCommand];
    }];
}

- (void)webSocketDidReceiveCommand:(NSNotification *)notification
{
    [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
        
        NSDictionary *dict = notification.userInfo;
        AVIMGenericCommand *command = [dict objectForKey:@"command"];
        
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

- (void)webSocketDidClose:(NSNotification *)notification
{
    [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
        
        subscriber.alive = false;
    }];
}

// MARK: - Login

- (AVIMGenericCommand *)makeLoginCommand
{
    AVIMGenericCommand *command = [[AVIMGenericCommand alloc] init];

    command.cmd             = AVIMCommandType_Login;
    command.appId           = [AVOSCloud getApplicationId];
    command.installationId  = self.identifier;
    command.service         = AVServiceTypeLiveQuery;
    command.needResponse    = YES;

    return command;
}

- (void)invokeAllLoginCallbackWithSucceeded:(BOOL)succeeded error:(NSError *)error
{
    NSArray<void (^)(BOOL, NSError *)> *callbacks = _loginCallbackArray;
    
    if (!callbacks) {
        
        return;
    }
    
    _loginCallbackArray = nil;
    
    [self invokeCallback:^{
        
        for (void (^item_callback)(BOOL, NSError *) in callbacks) {
            
            item_callback(succeeded, error);
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
            
            return;
        }
            
        subscriber->_loginCallbackArray = [NSMutableArray arrayWithObject:callback];
        
        AVIMGenericCommand *command = [subscriber makeLoginCommand];
        
        [command setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
            
            [subscriber addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
                
                subscriber.alive = (!error && inCommand && inCommand.cmd == AVIMCommandType_Loggedin);
                
                if (subscriber.alive) {
                    
                    [subscriber.backoffTimer reset];
                    
                    [subscriber invokeAllLoginCallbackWithSucceeded:true error:nil];
                    
                } else {
                    
                    [subscriber resentLoginCommand];
                }
            }];
        }];
        
        [subscriber.webSocket openWithCallback:^(BOOL succeeded, NSError *error) {
            
            [subscriber addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
                
                if (error) {
                    
                    [subscriber invokeAllLoginCallbackWithSucceeded:false error:error];
                    
                } else {
                    
                    [subscriber.webSocket sendCommand:command];
                }
            }];
        }];
    }];
}

- (void)resentLoginCommand
{
    if (self.alive) {
        
        [self invokeAllLoginCallbackWithSucceeded:true error:nil];
        
        return;
    }
    
    AVIMGenericCommand *command = [self makeLoginCommand];
    
    [command setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
        
        [self addOperationToInternalSerialQueue:^(AVSubscriber *subscriber) {
            
            subscriber.alive = (!error && inCommand && inCommand.cmd == AVIMCommandType_Loggedin);
            
            if (subscriber.alive) {
                
                [subscriber.backoffTimer reset];
                
                [subscriber invokeAllLoginCallbackWithSucceeded:true error:nil];
                
                NSArray<AVLiveQuery *> *livingObjects = [subscriber->_weakLiveQueryObjectTable allObjects];
                
                for (AVLiveQuery *item in livingObjects) {
                    
                    [item resubscribe];
                }
            } else {
                
                NSTimeInterval after = [subscriber.backoffTimer timeIntervalAndCalculateNext];
                
                dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(after * NSEC_PER_SEC));
                
                dispatch_after(when, subscriber->_internalSerialQueue, ^{
                    
                    [subscriber resentLoginCommand];
                });
            }
        }];
    }];
    
    [self.webSocket sendCommand:command];
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
