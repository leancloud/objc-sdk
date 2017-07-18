//
//  AVConnection.m
//  AVOS
//
//  Created by Tang Tianyong on 09/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVConnection.h"
#import "LCMethodDispatcher.h"
#import "SRWebSocket.h"
#import "AVRESTClient+Internal.h"
#import "LCFoundation.h"
#import "AFNetworkReachabilityManager.h"
#import <pthread.h>

static const NSTimeInterval AVConnectionOpenBackoffInitialTime   = 0.5;
static const NSTimeInterval AVConnectionOpenBackoffMaximumTime   = 60;
static const double         AVConnectionOpenBackoffGrowingFactor = 2;

static const NSTimeInterval AVConnectionPingBackoffInterval      = 180;

@interface AVConnection ()

<SRWebSocketDelegate, LCExponentialBackoffDelegate>

@property (nonatomic, strong) SRWebSocket *webSocket;
@property (nonatomic, assign) pthread_mutex_t openLock;
@property (nonatomic, strong) NSOperationQueue *openQueue;
@property (nonatomic, strong) NSOperationQueue *workQueue;
@property (nonatomic, strong) AVRESTClient *RESTClient;
@property (nonatomic, strong) NSHashTable *delegates;
@property (nonatomic, strong) LCExponentialBackoff *openBackoff;
@property (nonatomic, strong) LCExponentialBackoff *pingBackoff;
@property (nonatomic, assign) NSUInteger lastPingId;
@property (nonatomic, assign) NSUInteger maximumPongId;
@property (nonatomic, strong) AFNetworkReachabilityManager *reachabilityManager;
@property (nonatomic, assign) AVConnectionState state;

@end

@implementation AVConnectionOptions

@end

@implementation AVConnection

- (instancetype)initWithApplication:(AVApplication *)application
                            options:(AVConnectionOptions *)options
{
    self = [super init];

    if (self) {
        _application = [application copy];
        _options = [options copy];

        _RESTClient = [[AVRESTClient alloc] initWithApplication:application
                                                  configuration:nil];

        [self doInitialize];
    }

    return self;
}

- (void)doInitialize {
    pthread_mutex_init(&_openLock, NULL);
    _openQueue = [[NSOperationQueue alloc] init];
    _workQueue = [[NSOperationQueue alloc] init];
    _workQueue.maxConcurrentOperationCount = 1;
    _delegates = [NSHashTable weakObjectsHashTable];

    _openBackoff = [[LCExponentialBackoff alloc] initWithInitialTime:AVConnectionOpenBackoffInitialTime
                                                         maximumTime:AVConnectionOpenBackoffMaximumTime
                                                          growFactor:AVConnectionOpenBackoffGrowingFactor
                                                              jitter:LCExponentialBackoffDefaultJitter];
    _openBackoff.delegate = self;

    _pingBackoff = [[LCExponentialBackoff alloc] initWithInitialTime:AVConnectionPingBackoffInterval
                                                         maximumTime:AVConnectionPingBackoffInterval
                                                          growFactor:1
                                                              jitter:0];
    _pingBackoff.delegate = self;

    _reachabilityManager = [AFNetworkReachabilityManager manager];

    @weakify(self, weakSelf);
    [_reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        [weakSelf reachabilityStatusDidChange:status];
    }];

    [_reachabilityManager startMonitoring];

#if LC_TARGET_OS_IOS
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:)   name:UIApplicationDidEnterBackgroundNotification    object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)      name:UIApplicationDidBecomeActiveNotification       object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)        name:UIApplicationWillTerminateNotification         object:nil];
#endif
}

- (void)addOperation:(void(^)(AVConnection *connection))operation {
    @weakify(self, connection);
    [self.workQueue addOperationWithBlock:^{
        operation(connection);
    }];
}

- (void)changeState:(AVConnectionState)state {
    @synchronized (self) {
        if (state == _state)
            return;

        _state = state;
        [self callDelegateMethod:@selector(connection:stateDidChangeTo:)
                   withArguments:(__bridge void *)self, state];
    }
}

- (void)addDelegate:(id<AVConnectionDelegate>)delegate {
    @synchronized(_delegates) {
        [_delegates addObject:delegate];
    }
}

- (void)removeDelegate:(id<AVConnectionDelegate>)delegate {
    @synchronized(_delegates) {
        [_delegates removeObject:delegate];
    }
}

- (void)callDelegateMethod:(SEL)selector
             withArguments:(void *)argument1, ...
{
    NSArray *delegates = nil;

    /* NOTE: We convert the hash table to an array
             to avoid some quirks of hash table. */
    @synchronized(_delegates) {
        delegates = [_delegates allObjects];
    }

    if (!delegates.count)
        return;

    va_list args;
    va_start(args, argument1);

    for (id delegate in delegates) {
        LCMethodDispatcher *dispatcher = [[LCMethodDispatcher alloc] initWithTarget:delegate selector:selector];
        [dispatcher callWithArgument:argument1 vaList:args];
    }

    va_end(args);
}

- (void)resetOpenBackoff {
    [self.openBackoff reset];
}

- (void)resumeOpenBackoff {
    if ([self canOpen])
        [self.openBackoff resume];
}

- (void)resetPingBackoff {
    [self.pingBackoff reset];
}

- (void)resumePingBackoff {
    [self.pingBackoff resume];
}

- (void)restartPingBackoff {
    [self resetPingBackoff];
    [self resumePingBackoff];
}

- (void)exponentialBackoffDidReach:(LCExponentialBackoff *)backoff {
    [self addOperation:^(AVConnection *connection) {
        if (backoff == connection.openBackoff)
            [connection openBackoffDidReach:backoff];
        else if (backoff == connection.pingBackoff)
            [connection pingBackoffDidReach:backoff];
    }];
}

- (void)openBackoffDidReach:(LCExponentialBackoff *)backoff {
    if ([self canOpen])
        [self open];

    if (self.webSocket.readyState == SR_OPEN)
        [self resetOpenBackoff];
}

- (void)pingBackoffDidReach:(LCExponentialBackoff *)backoff {
    [self sendPing];
}

- (void)sendPing {
    if (self.webSocket.readyState != SR_OPEN)
        return;

    _lastPingId += 1;
    NSData *data = [NSData dataWithBytes:&_lastPingId length:sizeof(_lastPingId)];
    [self.webSocket sendPing:data];
}

- (void)reachabilityStatusDidChange:(AFNetworkReachabilityStatus)status {
    [self addOperation:^(AVConnection *connection) {
        switch (status) {
        case AFNetworkReachabilityStatusUnknown:
        case AFNetworkReachabilityStatusNotReachable:
            [connection close];
            break;
        case AFNetworkReachabilityStatusReachableViaWiFi:
        case AFNetworkReachabilityStatusReachableViaWWAN:
            [connection resetOpenBackoff];
            [connection open];
            break;
        }
    }];
}

- (void)applicationDidEnterBackground:(id)sender {
    [self addOperation:^(AVConnection *connection) {
        [connection close];
    }];
}

- (void)applicationDidBecomeActive:(id)sender {
    [self addOperation:^(AVConnection *connection) {
        [connection resetOpenBackoff];
        [connection open];
    }];
}

- (void)applicationWillTerminate:(id)sender {
    [self addOperation:^(AVConnection *connection) {
        [connection close];
    }];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    [self addOperation:^(AVConnection *connection) {
        [connection resetOpenBackoff];
        [connection changeState:AVConnectionStateOpen];

        [connection restartPingBackoff];
    }];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    [self addOperation:^(AVConnection *connection) {
        [connection resetOpenBackoff];
    }];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    [self addOperation:^(AVConnection *connection) {
        [connection resetOpenBackoff];

        typeof(connection.maximumPongId) pongId = 0;
        [pongPayload getBytes:&pongId length:sizeof(pongId)];

        if (pongId > connection.maximumPongId)
            connection.maximumPongId = pongId;
    }];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    [self addOperation:^(AVConnection *connection) {
        [connection close];
        [connection resumeOpenBackoff];
    }];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    [self addOperation:^(AVConnection *connection) {
        [connection close];
        [connection resumeOpenBackoff];
    }];
}

- (void)webSocketDidCreate:(SRWebSocket *)webSocket {
    if (![self canOpen])
        return;

    _webSocket = webSocket;

    webSocket.delegate = self;
    [webSocket open];
}

/**
 Select a RTM server from RTM server table.
 RTM server table may contain both primary server and secondary server.
 It will randomly select one between them.
 */
- (NSString *)selectServerFromServerTable:(NSDictionary *)serverTable {
    NSString *server = nil;

    NSString *primary   = serverTable[@"server"];
    NSString *secondary = serverTable[@"secondary"];

    if (primary && secondary)
        server = (arc4random() % 2) ? primary : secondary;
    else
        server = primary ?: secondary;

    return server;
}

- (SRWebSocket *)webSocketWithServerTable:(NSDictionary *)serverTable {
    SRWebSocket *websocket = nil;
    NSString *server = [self selectServerFromServerTable:serverTable];

    if (!server)
        return nil;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:server]];
    NSArray *protocols = self.options.protocols;

    if (protocols.count)
        websocket = [[SRWebSocket alloc] initWithURLRequest:request protocols:protocols];
    else
        websocket = [[SRWebSocket alloc] initWithURLRequest:request];

    return websocket;
}

- (void)createWebSocketWithBlock:(void(^)(SRWebSocket *webSocket, NSError *error))block {
    @weakify(self, connection);
    [self.RESTClient getRTMServerTableWithBlock:^(NSDictionary *serverTable, NSError *error) {
        [connection addOperation:^(AVConnection *connection) {
            if (serverTable) {
                SRWebSocket *webSocket = [connection webSocketWithServerTable:serverTable];
                block(webSocket, nil);
            } else {
                block(nil, error);
            }
        }];
    }];
}

- (BOOL)isNetworkReachable {
    return self.reachabilityManager.isReachable;
}

- (BOOL)isApplicationStateNormal {
    BOOL result = YES;

    if (strcmp(getenv("LCIM_BACKGROUND_CONNECT_ENABLED") ?: "", "1"))
        return YES;

#if TARGET_OS_IOS
    UIApplicationState state = [UIApplication sharedApplication].applicationState;

    if (state == UIApplicationStateBackground)
        result = NO;
#endif

    return result;
}

- (BOOL)isConnectionBroken {
    SRWebSocket *webSocket = self.webSocket;

    if (!webSocket)
        return YES;

    if (webSocket.readyState == SR_CONNECTING ||
        webSocket.readyState == SR_OPEN)
    {
        return NO;
    }

    return YES;
}

- (BOOL)canOpen {
    return (
        [self isNetworkReachable] &&
        [self isApplicationStateNormal] &&
        [self isConnectionBroken]
    );
}

- (void)tryOpen {
    pthread_mutex_t *lock = &_openLock;

    if (pthread_mutex_trylock(lock))
        return;

    if (![self canOpen]) {
        pthread_mutex_unlock(lock);
        return;
    }

    [self addOperation:^(AVConnection *connection) {
        [connection closeWebSocketWithStateChange:NO];
        [connection changeState:AVConnectionStateConnecting];
    }];

    @weakify(self, connection);
    [self createWebSocketWithBlock:^(SRWebSocket *webSocket, NSError *error) {
        if (webSocket) {
            [connection webSocketDidCreate:webSocket];
            pthread_mutex_unlock(lock);
        } else {
            LC_ERROR(AVSomethingWrongCodeUnderlying, @"Cannot initialize WebSocket.", error);
            pthread_mutex_unlock(lock);
            [connection resumeOpenBackoff];
        }
    }];
}

- (void)open {
    @weakify(self, connection);
    [self.openQueue addOperationWithBlock:^{
        [connection tryOpen];
    }];
}

- (void)sendFrame:(id<AVConnectionFrame>)frame {
    /* TODO */
}

- (void)closeWebSocketWithStateChange:(BOOL)stateChange {
    [self addOperation:^(AVConnection *connection) {
        [connection resetPingBackoff];

        if (stateChange)
            [connection changeState:AVConnectionStateClosed];

        SRWebSocket *webSocket = connection.webSocket;

        if (webSocket) {
            webSocket.delegate = nil;
            [webSocket close];
        }
    }];
}

- (void)closeWebSocket {
    [self closeWebSocketWithStateChange:YES];
}

- (void)close {
    [self closeWebSocket];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    pthread_mutex_destroy(&_openLock);
    [self close];
}

@end
