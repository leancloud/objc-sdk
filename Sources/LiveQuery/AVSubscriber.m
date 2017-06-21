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
#import "AVConnection.h"
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

<AVConnectionDelegate>

@property (nonatomic, assign) BOOL alive;
@property (nonatomic, assign) BOOL inKeepAlive;
@property (nonatomic, assign) dispatch_once_t loginOnceToken;
@property (nonatomic,   weak) AVConnection *connection;
@property (nonatomic, strong) AVExponentialTimer *backoffTimer;

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

    _connection = [AVConnection sharedInstance];
    _identifier = [NSString stringWithFormat:@"%@-%@", AVIdentifierPrefix, deviceUUID];
    _backoffTimer = [AVExponentialTimer exponentialTimerWithInitialTime:AVBackoffInitialTime
                                                                maxTime:AVBackoffMaximumTime];

    [_connection addDelegate:self];
}

#pragma mark - AVConnectionDelegate

- (void)connectionDidOpen:(AVConnection *)connection {
    [self keepAlive];
}

- (void)connection:(AVConnection *)connection didReceiveCommand:(AVIMGenericCommand *)command {
    [self processCommand:command];
}

- (void)connection:(AVConnection *)connection didReceiveError:(NSError *)error {
    self.alive = NO;
    [self keepAlive];
}

- (void)connection:(AVConnection *)connection didCloseWithError:(NSError *)error {
    self.alive = NO;
    [self keepAlive];
}

#pragma mark -

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)processCommand:(AVIMGenericCommand *)command {
    /* Filter out non-live-query commands. */
    if (command.service != AVServiceTypeLiveQuery)
        return;

    switch (command.cmd) {
    case AVIMCommandType_Data:
        [self handleDataCommand:command];
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

    NSDictionary *event = [AVObjectUtils objectFromDictionary:dictionary recursive:YES];
    NSDictionary *userInfo = @{ AVLiveQueryEventKey: event };

    [[NSNotificationCenter defaultCenter] postNotificationName:AVLiveQueryEventNotification
                                                        object:self
                                                      userInfo:userInfo];
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

    if ([self.connection isOpen]) {
        [self.connection sendCommand:command];
        return;
    }

    [self.connection openWithCallback:^(BOOL succeeded, NSError *error) {
        if (error) {
            [AVUtils callBooleanResultBlock:callback error:error];
        } else {
            [self.connection sendCommand:command];
        }
    }];
}

- (void)keepAliveIntermittently {
    if (self.alive) {
        self.inKeepAlive = NO;
        return;
    }

    [self loginWithCallback:^(BOOL succeeded, NSError *error) {
        if (self.alive) {
            self.inKeepAlive = NO;
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
        if (self.inKeepAlive) {
            return;
        }

        self.inKeepAlive = YES;
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
