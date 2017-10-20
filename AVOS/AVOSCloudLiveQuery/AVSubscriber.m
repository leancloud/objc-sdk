//
//  AVSubscriber.m
//  AVOS
//
//  Created by Tang Tianyong on 16/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVSubscriber.h"
#import "AVExponentialTimer.h"

/* AVOSCloud headers */
#import "AVConfiguration.h"
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

@interface AVSubscriber ()

@property (nonatomic, assign) BOOL alive;
@property (nonatomic, assign) dispatch_once_t loginOnceToken;
@property (nonatomic,   weak) AVIMWebSocketWrapper *webSocket;
@property (nonatomic, strong) AVExponentialTimer   *backoffTimer;

@end

@implementation AVSubscriber

+ (instancetype)sharedInstance {
    static AVSubscriber *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[AVSubscriber alloc] init];
    });

    return instance;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        [self doInitialize];
    }

    return self;
}

- (void)doInitialize {
    NSString *deviceUUID = [AVUtils deviceUUID];

    _webSocket = [AVIMWebSocketWrapper sharedSecurityInstance];
    _identifier = [NSString stringWithFormat:@"%@-%@", AVIdentifierPrefix, deviceUUID];
    _backoffTimer = [AVExponentialTimer exponentialTimerWithInitialTime:AVBackoffInitialTime
                                                                maxTime:AVBackoffMaximumTime];

    [self observeWebSocket:_webSocket];
}

- (void)observeWebSocket:(AVIMWebSocketWrapper *)webSocket {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter addObserver:self selector:@selector(webSocketDidOpen:)            name:AVIM_NOTIFICATION_WEBSOCKET_OPENED   object:_webSocket];
    [notificationCenter addObserver:self selector:@selector(webSocketDidReceiveCommand:)  name:AVIM_NOTIFICATION_WEBSOCKET_COMMAND  object:_webSocket];
    [notificationCenter addObserver:self selector:@selector(webSocketDidReceiveError:)    name:AVIM_NOTIFICATION_WEBSOCKET_ERROR    object:_webSocket];
    [notificationCenter addObserver:self selector:@selector(webSocketDidClose:)           name:AVIM_NOTIFICATION_WEBSOCKET_CLOSED   object:_webSocket];

    [_webSocket increaseObserverCount];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)webSocketDidOpen:(NSNotification *)notification {
    [self keepAlive];
}

- (void)webSocketDidReceiveCommand:(NSNotification *)notification {
    NSDictionary *dict = notification.userInfo;
    AVIMGenericCommand *command = [dict objectForKey:@"command"];

    /* Filter out non-live-query commands. */
    if (command.service != AVServiceTypeLiveQuery)
        return;

    switch (command.cmd) {
        case AVIMCommandType_Data:
            [self handleDataCommand:command];
            break;
        default:
            break;
    }
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

- (void)webSocketDidReceiveError:(NSNotification *)notification {
    self.alive = NO;
    [self keepAliveIntermittently];
}

- (void)webSocketDidClose:(NSNotification *)notification {
    self.alive = NO;
}

- (AVIMGenericCommand *)makeLoginCommand {
    AVIMGenericCommand *command = [[AVIMGenericCommand alloc] init];

    command.cmd             = AVIMCommandType_Login;
    command.appId           = [AVConfiguration sharedInstance].applicationId;
    command.installationId  = self.identifier;
    command.service         = AVServiceTypeLiveQuery;
    command.needResponse    = YES;

    return command;
}

- (BOOL)isLoggedInCommand:(AVIMGenericCommand *)command {
    BOOL isLoggedIn = (command && command.cmd == AVIMCommandType_Loggedin);
    return isLoggedIn;
}

- (void)loginWithCallback:(AVBooleanResultBlock)callback {
    AVIMGenericCommand *command = [self makeLoginCommand];

    command.callback = ^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
        self.alive = [self isLoggedInCommand:inCommand];
        [AVUtils callBooleanResultBlock:callback error:error];
    };

    if ([self.webSocket isConnectionOpen]) {
        [self.webSocket sendCommand:command];
        return;
    }

    [self.webSocket openWebSocketConnectionWithCallback:^(BOOL succeeded, NSError *error) {
        if (error) {
            [AVUtils callBooleanResultBlock:callback error:error];
        } else {
            [self.webSocket sendCommand:command];
        }
    }];
}

- (void)keepAliveIntermittently {
    if (self.alive) {
        return;
    }

    [self loginWithCallback:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            self.alive = YES;
            return;
        }

        NSTimeInterval after = [self.backoffTimer timeIntervalAndCalculateNext];

        dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(after * NSEC_PER_SEC));
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

        dispatch_after(when, queue, ^{
            [self keepAliveIntermittently];
        });
    }];
}

- (void)keepAlive {
    @synchronized (self) {
        [self.backoffTimer reset];
        [self keepAliveIntermittently];
    }
}

- (void)start {
    dispatch_once(&_loginOnceToken, ^{
        [self loginWithCallback:^(BOOL succeeded, NSError *error) {
            if (!self.alive)
                [self keepAlive];
        }];
    });
}

@end
