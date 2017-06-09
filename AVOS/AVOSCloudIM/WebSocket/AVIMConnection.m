//
//  AVIMConnection.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMConnection.h"
#import "AVIMWebSocket.h"
#import "LCNetworkReachabilityManager.h"
#import "AVIMErrorUtil.h"
#import "AVIMBlockHelper.h"
#import "AVIMClient_Internal.h"
#import "AVIMUserOptions.h"
#import "AVPaasClient.h"
#import "AVOSCloud_Internal.h"
#import "LCRouter.h"
#import "SDMacros.h"
#import "AVMethodDispatcher.h"

#define PING_INTERVAL 60*3
#define TIMEOUT_CHECK_INTERVAL 1

#define LCIM_OUT_COMMAND_LOG_FORMAT \
    @"\n\n" \
    @"------ BEGIN LeanCloud IM Out Command ------\n" \
    @"cmd: %@\n"                                      \
    @"type: %@\n"                                     \
    @"content: %@\n"                                  \
    @"------ END ---------------------------------\n" \
    @"\n"

#define LCIM_IN_COMMAND_LOG_FORMAT \
    @"\n\n" \
    @"------ BEGIN LeanCloud IM In Command ------\n" \
    @"content: %@\n"                                 \
    @"------ END --------------------------------\n" \
    @"\n"

static NSTimeInterval AVIMWebSocketDefaultTimeoutInterval = 15.0;

NSString *const AVIMProtocolPROTOBUF1 = @"lc.protobuf.1";
NSString *const AVIMProtocolPROTOBUF2 = @"lc.protobuf.2";
NSString *const AVIMProtocolPROTOBUF3 = @"lc.protobuf.3";

@interface AVIMCommandCarrier : NSObject
@property(nonatomic, strong) AVIMGenericCommand *command;
@property(nonatomic)NSTimeInterval timestamp;

@end
@implementation AVIMCommandCarrier
- (void)timeoutInSeconds:(NSTimeInterval)seconds {
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    timestamp += seconds;
    self.timestamp = timestamp;
}
@end

@interface AVIMConnection () <NSURLConnectionDelegate, AVIMWebSocketDelegate> {
    BOOL _isClosed;
    NSTimer *_pingTimer;
    NSTimer *_timeoutCheckTimer;
    NSTimer *_pingTimeoutCheckTimer;

    int32_t _ttl;
    NSTimeInterval _lastPingTimestamp;
    NSTimeInterval _lastPongTimestamp;
    NSTimeInterval _reconnectInterval;

    BOOL _waitingForPong;
    NSMutableDictionary *_commandDictionary;
    NSMutableArray *_serialIdArray;
}

@property (nonatomic, assign) BOOL useSecondary;
@property (nonatomic, assign) BOOL needRetry;
@property (nonatomic, strong) LCNetworkReachabilityManager *reachabilityMonitor;
@property (nonatomic, strong) NSTimer *reconnectTimer;
@property (nonatomic, strong) AVIMWebSocket *webSocket;
@property (nonatomic, copy)   AVIMBooleanResultBlock openCallback;
@property (nonatomic, strong) NSMutableDictionary *IPTable;
@property (nonatomic, strong) NSHashTable *delegates;

@end

@implementation AVIMConnection

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static AVIMConnection *instance = nil;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds {
    if (seconds > 0) {
        AVIMWebSocketDefaultTimeoutInterval = seconds;
    }
}

- (id)init {
    self = [super init];
    if (self) {
        _commandDictionary = [[NSMutableDictionary alloc] init];
        _serialIdArray = [[NSMutableArray alloc] init];
        _ttl = -1;
        _timeout = AVIMWebSocketDefaultTimeoutInterval;
        
        _lastPongTimestamp = [[NSDate date] timeIntervalSince1970];
        
        _reconnectInterval = 1;
        _needRetry = YES;

        _delegates = [NSHashTable weakObjectsHashTable];
        
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
        // Register for notification when the app shuts down
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
#else
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:NSApplicationDidResignActiveNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:NSApplicationDidBecomeActiveNotification object:nil];
#endif
        [self startNotifyReachability];
    }
    return self;
}

- (void)startNotifyReachability {
    @weakify(self, ws);

    _reachabilityMonitor = [LCNetworkReachabilityManager manager];
    [_reachabilityMonitor setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        switch (status) {
        case AFNetworkReachabilityStatusUnknown:
        case AFNetworkReachabilityStatusNotReachable:
            [ws networkDidBecomeUnreachable];
            break;
        case AFNetworkReachabilityStatusReachableViaWWAN:
        case AFNetworkReachabilityStatusReachableViaWiFi:
            [ws networkDidBecomeReachable];
            break;
        }
    }];

    [_reachabilityMonitor startMonitoring];
}

- (BOOL)isReachable {
    return _reachabilityMonitor.networkReachabilityStatus != AFNetworkReachabilityStatusNotReachable;
}

- (void)dealloc {
    [_reachabilityMonitor stopMonitoring];
    if (!_isClosed) {
        [self closeWebSocketConnectionRetry:NO];
    }
}

- (void)addDelegate:(id<AVIMConnectionDelegate>)delegate {
    [_delegates addObject:delegate];
}

- (void)removeDelegate:(id<AVIMConnectionDelegate>)delegate {
    [_delegates removeObject:delegate];
}

- (void)callDelegateMethod:(SEL)selector
             withArguments:(id)argument1, ...
{
    va_list args;
    va_start(args, argument1);

    for (id delegate in _delegates) {
        AVMethodDispatcher *dispatcher = [[AVMethodDispatcher alloc] initWithTarget:delegate selector:selector];
        [dispatcher callWithArgument:argument1 vaList:args];
    }

    va_end(args);
}

#pragma mark - process application notification

- (void)applicationDidFinishLaunching:(id)sender {
    /* Nothing to do. */
}

- (void)applicationDidEnterBackground:(id)sender {
    [self closeWebSocketConnectionRetry:NO];
}

- (void)applicationWillEnterForeground:(id)sender {
    /* Nothing to do. */
}

- (void)applicationWillResignActive:(id)sender {
    /* Nothing to do. */
}

- (void)applicationDidBecomeActive:(id)sender {
    [self reopenWebSocketConnection];
}

- (void)applicationWillTerminate:(id)sender {
    [self closeWebSocketConnectionRetry:NO];
}

#pragma mark - ping timer fierd
- (void)timerFired:(id)sender {
    if (_lastPongTimestamp > 0 && [[NSDate date] timeIntervalSince1970] - _lastPongTimestamp >= 5 * 60) {
        [self closeWebSocketConnection];
        return;
    }
    
    if (_webSocket.readyState == AVIM_OPEN) {
        [self sendPing];
    }
}

#pragma mark - API to use websocket

- (void)networkDidBecomeReachable {
    [self reopenWebSocketConnection];
}

- (void)networkDidBecomeUnreachable {
    [self closeWebSocketConnectionRetry:NO];
}

/**
 Reopen websocket connection if application state is normal.
 */
- (void)reopenWebSocketConnection {
    BOOL shouldOpen = YES;

#if TARGET_OS_IOS
    UIApplicationState state = [UIApplication sharedApplication].applicationState;

    if (!getenv("LCIM_BACKGROUND_CONNECT_ENABLED") && state == UIApplicationStateBackground)
        shouldOpen = NO;
#endif

    if (shouldOpen) {
        _reconnectInterval = 1;
        [self open];
    }
}

- (void)open {
    [self openWithCallback:nil];
}

- (void)openWithCallback:(AVIMBooleanResultBlock)callback {
    @weakify(self);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @strongify(self);

        AVLoggerInfo(AVLoggerDomainIM, @"Open websocket connection.");
        self.openCallback = callback;
        
        self.needRetry = YES;
        [self.reconnectTimer invalidate];
        
        if (!(self.webSocket && (self.webSocket.readyState == AVIM_OPEN || self.webSocket.readyState == AVIM_CONNECTING))) {
            if (!self.openCallback) {
                [self callDelegateMethod:@selector(connectionDidReconnect:) withArguments:self];
            }

            LCRouter *router = [LCRouter sharedInstance];
            NSDictionary *RTMServerTable = [router cachedRTMServerTable];

            if (RTMServerTable) {
                [self openConnectionForRTMServerTable:RTMServerTable];
                return;
            }

            NSString *appId = [AVOSCloud getApplicationId];

            if (!appId) {
                @throw [NSException exceptionWithName:@"AVOSCloudIM Exception" reason:@"Application ID not found." userInfo:nil];
            }

            [[LCRouter sharedInstance] fetchRTMServerTableInBackground:^(NSDictionary *object, NSError *error) {
                NSInteger code = error.code;

                if (object && !error) { /* Everything is OK. */
                    self.useSecondary = NO;
                    [self openConnectionForRTMServerTable:object];
                } else if (code == 404) { /* 404, stop reconnection. */
                    NSError *httpError = [AVIMErrorUtil errorWithCode:code reason:[NSHTTPURLResponse localizedStringForStatusCode:code]];
                    if (self.openCallback) {
                        [AVIMBlockHelper callBooleanResultBlock:self.openCallback error:httpError];
                        self.openCallback = nil;
                    } else {
                        [self callDelegateMethod:@selector(connection:didCloseWithError:) withArguments:self, error];
                    }
                } else if ((!object && !error) || code >= 400 || error) { /* Something error, try to reconnect. */
                    if (!error) {
                        if (code >= 404) {
                            error = [AVIMErrorUtil errorWithCode:code reason:[NSHTTPURLResponse localizedStringForStatusCode:code]];
                        } else {
                            error = [AVIMErrorUtil errorWithCode:kAVIMErrorInvalidData reason:@"No data received"];
                        }
                    }
                    if (self.openCallback) {
                        [AVIMBlockHelper callBooleanResultBlock:self.openCallback error:error];
                        self.openCallback = nil;
                    } else {
                        [self reconnect];
                    }
                }
            }];
        }
    });
}

/**
 Open connection for RTM server table.

 It will choose a RTM server from RTM server table firstly,
 then, create connection to that server.

 If RTM server not found, it will retry from scratch.
 */
- (void)openConnectionForRTMServerTable:(NSDictionary *)RTMServerTable {
    NSString *server = [self chooseServerFromRTMServerTable:RTMServerTable];

    if (server) {
        [self internalOpenWebSocketConnection:server];
    } else {
        AVLoggerError(AVLoggerDomainIM, @"RTM server not found, try reconnection...");
        [self reconnect];
    }
}

/**
 Choose a RTM server from RTM server table.
 RTM server table may contain both primary server and secondary server.

 If `_useSecondary` is true, it will choose secondary server preferentially.
 Otherwise, it will choose primary server preferentially.
 */
- (NSString *)chooseServerFromRTMServerTable:(NSDictionary *)RTMServerTable {
    NSString *server = nil;

    NSString *primary   = RTMServerTable[@"server"];
    NSString *secondary = RTMServerTable[@"secondary"];

    if (_useSecondary)
        server = secondary ?: primary;
    else
        server = primary ?: secondary;

    return server;
}

SecCertificateRef LCGetCertificateFromBase64String(NSString *base64);

- (NSArray *)pinnedCertificates {
    id cert = (__bridge_transfer id)LCGetCertificateFromBase64String(LCRootCertificate);
    return cert ? @[cert] : @[];
}

- (void)internalOpenWebSocketConnection:(NSString *)server {
    _webSocket.delegate = nil;
    [_webSocket close];

    AVLoggerInfo(AVLoggerDomainIM, @"Open websocket with url: %@", server);
    
    NSMutableSet *protocols = [NSMutableSet set];
    NSDictionary *userOptions = [AVIMClient userOptions];

    if ([userOptions[AVIMUserOptionUseUnread] boolValue]) {
        [protocols addObject:AVIMProtocolPROTOBUF3];
    } else {
        [protocols addObject:AVIMProtocolPROTOBUF1];
    }

    if (userOptions[AVIMUserOptionCustomProtocols]) {
        [protocols removeAllObjects];
        [protocols addObjectsFromArray:userOptions[AVIMUserOptionCustomProtocols]];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:server]];

    if ([protocols count]) {
        _webSocket = [[AVIMWebSocket alloc] initWithURLRequest:request protocols:[protocols allObjects]];
    } else {
        _webSocket = [[AVIMWebSocket alloc] initWithURLRequest:request];
    }

    request.AVIM_SSLPinnedCertificates = [self pinnedCertificates];
    _webSocket.SSLPinningMode = AVIMSSLPinningModePublicKey;

    _webSocket.delegate = self;
    [_webSocket open];
}

- (void)closeWebSocketConnection {
    AVLoggerInfo(AVLoggerDomainIM, @"Close websocket connection.");
    [_pingTimer invalidate];
    [_webSocket close];
    [self callDelegateMethod:@selector(connection:didCloseWithError:) withArguments:self, nil];
    _isClosed = YES;
}

- (void)closeWebSocketConnectionRetry:(BOOL)retry {
    AVLoggerInfo(AVLoggerDomainIM, @"Close websocket connection.");
    [_pingTimer invalidate];
    _needRetry = retry;
    [_webSocket close];
    [self callDelegateMethod:@selector(connection:didCloseWithError:) withArguments:self, nil];
    _isClosed = YES;
}

- (void)checkTimeout:(NSTimer *)timer {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (_waitingForPong && now - _lastPingTimestamp > _timeout) {
        _lastPingTimestamp = 0;
        _lastPongTimestamp = 0;
        [self closeWebSocketConnection];
        if (_pingTimeoutCheckTimer) {
            [_pingTimeoutCheckTimer invalidate];
            _pingTimeoutCheckTimer = nil;
        }
    }
    NSMutableArray *array = nil;
    for (NSNumber *num in _serialIdArray) {
        AVIMCommandCarrier *carrier = [_commandDictionary objectForKey:num];
        NSTimeInterval timestamp = carrier.timestamp;
        //        NSLog(@"now:%lf expire:%lf", now, timestamp);
        if (now > timestamp) {
            if (!array) {
                array = [[NSMutableArray alloc] init];
            }
            [array addObject:num];
            AVIMGenericCommand *command = [self dequeueCommandWithId:num];
            AVIMCommandResultBlock callback = command.callback;
            if (callback) {
                NSError *error = [AVIMErrorUtil errorWithCode:kAVIMErrorTimeout reason:@"The request timed out."];
                callback(command, nil, error);
            }
            if (now - _lastPingTimestamp > _timeout) {
                [self sendPing];
            }
        } else {
            break;
        }
    }
    if (array) {
        [_serialIdArray removeObjectsInArray:array];
    }
}

- (void)enqueueCommand:(AVIMGenericCommand *)command {
    AVIMCommandCarrier *carrier = [[AVIMCommandCarrier alloc] init];
    carrier.command = command;
    [carrier timeoutInSeconds:_timeout];
    NSNumber *num = @(command.i);
    [_commandDictionary setObject:carrier forKey:num];
    if (!_timeoutCheckTimer) {
        _timeoutCheckTimer = [NSTimer scheduledTimerWithTimeInterval:TIMEOUT_CHECK_INTERVAL target:self selector:@selector(checkTimeout:) userInfo:nil repeats:YES];
    }
}

- (AVIMGenericCommand *)dequeueCommandWithId:(NSNumber *)num {
    if (!num)
        return nil;
    AVIMCommandCarrier *carrier = [_commandDictionary objectForKey:num];
    AVIMGenericCommand *command = carrier.command;
    [_commandDictionary removeObjectForKey:num];
    if (_commandDictionary.count == 0) {
        [_timeoutCheckTimer invalidate];
        _timeoutCheckTimer = nil;
    }
    return command;
}

- (BOOL)checkSizeForData:(id)data {
    if ([data isKindOfClass:[NSString class]] && [(NSString *)data length] > 5000) {
        return NO;
    } else if ([data isKindOfClass:[NSData class]] && [(NSData *)data length] > 5000) {
        return NO;
    }
    return YES;
}

- (void)sendCommand:(AVIMGenericCommand *)genericCommand {
    LCIMMessage *messageCommand = [genericCommand avim_messageCommand];
    BOOL needResponse = genericCommand.needResponse;
    if (messageCommand && _webSocket.readyState == AVIM_OPEN) {
        if (needResponse) {
            [genericCommand avim_addOrRefreshSerialId];
            [self enqueueCommand:genericCommand];
            NSNumber *num = @(genericCommand.i);
            [_serialIdArray addObject:num];
        }
        NSError *error = nil;
        id data = [genericCommand data];
        if (![self checkSizeForData:data]) {
            AVIMCommandResultBlock callback = genericCommand.callback;
            if (callback) {
                error = [AVIMErrorUtil errorWithCode:kAVIMErrorMessageTooLong reason:@"Message data to send is too long."];
                callback(genericCommand, nil, error);
            }
            return;
        }
        [_webSocket send:data];
        if (!needResponse) {
            AVIMCommandResultBlock callback = genericCommand.callback;
            if (callback) {
                callback(genericCommand, nil, nil);
            }
        }
    } else {
        AVIMCommandResultBlock callback = genericCommand.callback;
        NSError *error = [AVIMErrorUtil errorWithCode:kAVIMErrorConnectionLost reason:@"websocket not opened"];
        if (callback) {
            callback(genericCommand, nil, error);
        } else {
            [self callDelegateMethod:@selector(connection:didReceiveError:) withArguments:self, error];
        }
    }
    AVLoggerInfo(AVLoggerDomainIM, LCIM_OUT_COMMAND_LOG_FORMAT, [AVIMCommandFormatter commandType:genericCommand.cmd], [genericCommand avim_messageClass], [genericCommand avim_description] );
}

- (void)sendPing {
    if ([self isOpen]) {
        AVLoggerInfo(AVLoggerDomainIM, @"Websocket send ping.");
        _lastPingTimestamp = [[NSDate date] timeIntervalSince1970];
        _waitingForPong = YES;
        if (!_pingTimeoutCheckTimer) {
            _pingTimeoutCheckTimer = [NSTimer scheduledTimerWithTimeInterval:TIMEOUT_CHECK_INTERVAL target:self selector:@selector(checkTimeout:) userInfo:nil repeats:YES];
        }
        [_webSocket sendPing:[@"" dataUsingEncoding:NSUTF8StringEncoding]];
    }
}

- (BOOL)isOpen {
    return _webSocket.readyState == AVIM_OPEN;
}

#pragma mark - SRWebSocketDelegate
- (void)webSocketDidOpen:(AVIMWebSocket *)webSocket {
    AVLoggerInfo(AVLoggerDomainIM, @"Websocket connection opened.");
    
    [self callDelegateMethod:@selector(connectionDidOpen:) withArguments:self];
    
    [_reconnectTimer invalidate];
    
    [_pingTimer invalidate];
    _pingTimer = [NSTimer scheduledTimerWithTimeInterval:PING_INTERVAL target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
}

- (void)webSocket:(AVIMWebSocket *)webSocket didReceiveMessage:(id)message {
    _reconnectInterval = 1;
    NSError *error = nil;
    /* message for server which is in accordance with protobuf protocol must be data type, there is no need to convert string to data. */
    AVIMGenericCommand *command = [AVIMGenericCommand parseFromData:message error:&error];
    AVLoggerInfo(AVLoggerDomainIM, LCIM_IN_COMMAND_LOG_FORMAT, [command avim_description]);

    if (!command) {
        AVLoggerError(AVLoggerDomainIM, @"Not handled data.");
        return;
    }
    if (command.i > 0) {
        NSNumber *num = @(command.i);
        AVIMGenericCommand *outCommand = [self dequeueCommandWithId:num];
        if (outCommand) {
            [_serialIdArray removeObject:num];
            if ([command avim_hasError]) {
                error = [command avim_errorObject];
            }
            AVIMCommandResultBlock callback = outCommand.callback;
            if (callback) {
                callback(outCommand, command, error);
                if (command.hasSessionMessage && error) {
                    [self notifyCommand:command];
                }
            } else {
                [self notifyCommand:command];
            }
        } else {
            AVLoggerError(AVLoggerDomainIM, @"No out message matched the in message %@", message);
        }
    } else {
        [self notifyCommand:command];
    }
}

- (void)notifyCommand:(AVIMGenericCommand *)command {
    [self callDelegateMethod:@selector(connection:didReceiveCommand:) withArguments:self, command];
}

- (void)webSocket:(AVIMWebSocket *)webSocket didReceivePong:(id)data {
    AVLoggerInfo(AVLoggerDomainIM, @"Websocket receive pong.");
    _lastPongTimestamp = [[NSDate date] timeIntervalSince1970];
    _waitingForPong = NO;
    if (_pingTimeoutCheckTimer) {
        [_pingTimeoutCheckTimer invalidate];
        _pingTimeoutCheckTimer = nil;
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    AVLoggerDebug(AVLoggerDomainIM, @"Websocket closed with code:%ld, reason:%@.", (long)code, reason);
    
    NSError *error = [AVIMErrorUtil errorWithCode:code reason:reason];
    for (NSNumber *num in _serialIdArray) {
        AVIMGenericCommand *outCommand = [self dequeueCommandWithId:num];
        if (outCommand) {
            AVIMCommandResultBlock callback = outCommand.callback;
            if (callback) {
                callback(outCommand, nil, error);
            }
        } else {
            AVLoggerError(AVLoggerDomainIM, @"No out message matched serial id %@", num);
        }
    }
    [_serialIdArray removeAllObjects];
    if (_webSocket.readyState != AVIM_CLOSED) {
        [self callDelegateMethod:@selector(connection:didCloseWithError:) withArguments:self, error];
    }
    if ([self isReachable]) {
        [self retryIfNeeded];
    }
}

- (void)forwardError:(NSError *)error forWebSocket:(AVIMWebSocket *)webSocket {
    AVLoggerError(AVLoggerDomainIM, @"Websocket open failed with error:%@.", error);

    _useSecondary = YES;

    for (NSNumber *num in _serialIdArray) {
        AVIMGenericCommand *outCommand = [self dequeueCommandWithId:num];
        if (outCommand) {
            AVIMCommandResultBlock callback = outCommand.callback;
            if (callback) {
                callback(outCommand, nil, error);
            }
        } else {
            AVLoggerError(AVLoggerDomainIM, @"No out message matched serial id %@", num);
        }
    }

    [_serialIdArray removeAllObjects];
    
    [self callDelegateMethod:@selector(connection:didReceiveError:) withArguments:self, error];
    
    if (self.openCallback) {
        [AVIMBlockHelper callBooleanResultBlock:self.openCallback error:error];
        self.openCallback = nil;
    } else {
        if ([self isReachable]) {
            [self retryIfNeeded];
        }
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didFailWithError:(NSError *)error {
    [self forwardError:error forWebSocket:webSocket];
}

- (NSMutableDictionary *)IPTable {
    return _IPTable ?: (_IPTable = [NSMutableDictionary dictionary]);
}

#pragma mark - reconnect

- (void)reconnect {
    AVLoggerDebug(AVLoggerDomainIM, @"Websocket connection reconnect in %ld seconds.", (long)_reconnectInterval);
    dispatch_async(dispatch_get_main_queue(), ^{
        _reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:_reconnectInterval target:self selector:@selector(openWebSocketConnection) userInfo:nil repeats:NO];
    });
    _reconnectInterval *= 2;
}

- (void)retryIfNeeded {
    if (!_needRetry) {
        return;
    }
    [self reconnect];
}

@end
