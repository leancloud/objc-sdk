//
//  AVConnection.m
//  AVOS
//
//  Created by Tang Tianyong on 09/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVConnection.h"
#import "AVMethodDispatcher.h"
#import "SRWebSocket.h"
#import "AVRESTClient+Internal.h"
#import "LCFoundation.h"
#import "AFNetworkReachabilityManager.h"

static const NSTimeInterval AVConnectionExponentialBackoffInitialTime = 0.618;
static const NSTimeInterval AVConnectionExponentialBackoffMaximumTime = 60;

@interface AVConnection ()

<SRWebSocketDelegate, LCExponentialBackoffDelegate>

@property (nonatomic, strong) SRWebSocket *webSocket;
@property (nonatomic, strong) NSRecursiveLock *openLock;
@property (nonatomic, strong) NSOperationQueue *openOperationQueue;
@property (nonatomic, strong) AVRESTClient *RESTClient;
@property (nonatomic, strong) NSHashTable *delegates;
@property (nonatomic, strong) LCExponentialBackoff *exponentialBackoff;
@property (nonatomic, strong) AFNetworkReachabilityManager *reachabilityManager;

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
    _openLock = [[NSRecursiveLock alloc] init];
    _openOperationQueue = [[NSOperationQueue alloc] init];
    _delegates = [NSHashTable weakObjectsHashTable];

    _exponentialBackoff = [[LCExponentialBackoff alloc] initWithInitialTime:AVConnectionExponentialBackoffInitialTime
                                                                maximumTime:AVConnectionExponentialBackoffMaximumTime
                                                                 growFactor:2
                                                                     jitter:LCExponentialBackoffDefaultJitter];
    _exponentialBackoff.delegate = self;

    _reachabilityManager = [AFNetworkReachabilityManager manager];

    @weakify(self, weakSelf);
    [_reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        [weakSelf reachabilityStatusDidChange:status];
    }];

#if LC_TARGET_OS_IOS
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:)   name:UIApplicationDidEnterBackgroundNotification    object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)      name:UIApplicationDidBecomeActiveNotification       object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)        name:UIApplicationWillTerminateNotification         object:nil];
#endif
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
             withArguments:(id)argument1, ...
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
        AVMethodDispatcher *dispatcher = [[AVMethodDispatcher alloc] initWithTarget:delegate selector:selector];
        [dispatcher callWithArgument:argument1 vaList:args];
    }

    va_end(args);
}

- (void)resetExponentialBackoff {
    [self.exponentialBackoff reset];
}

- (void)resumeExponentialBackoff {
    if ([self shouldOpen])
        [self.exponentialBackoff resume];
}

- (void)exponentialBackoffDidReach:(LCExponentialBackoff *)exponentialBackoff {
    [self tryOpen];
}

- (void)reachabilityStatusDidChange:(AFNetworkReachabilityStatus)status {
    switch (status) {
    case AFNetworkReachabilityStatusUnknown:
    case AFNetworkReachabilityStatusNotReachable:
        [self close];
        break;
    case AFNetworkReachabilityStatusReachableViaWiFi:
    case AFNetworkReachabilityStatusReachableViaWWAN:
        [self resetExponentialBackoff];
        [self tryOpen];
        break;
    }
}

- (void)applicationDidEnterBackground:(id)sender {
    [self close];
}

- (void)applicationDidBecomeActive:(id)sender {
    [self resetExponentialBackoff];
    [self tryOpen];
}

- (void)applicationWillTerminate:(id)sender {
    [self close];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    [self resetExponentialBackoff];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    [self resetExponentialBackoff];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    [self resetExponentialBackoff];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    [self resumeExponentialBackoff];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    [self resumeExponentialBackoff];
}

- (BOOL)isConnectingOrOpen {
    SRWebSocket *webSocket = self.webSocket;

    if (!webSocket)
        return NO;

    if (webSocket.readyState == SR_CONNECTING ||
        webSocket.readyState == SR_OPEN)
    {
        return YES;
    }

    return NO;
}

- (void)webSocketDidCreate:(SRWebSocket *)webSocket {
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
    [self.RESTClient getRTMServerTableWithBlock:^(NSDictionary *serverTable, NSError *error) {
        if (serverTable) {
            SRWebSocket *webSocket = [self webSocketWithServerTable:serverTable];
            block(webSocket, nil);
        } else {
            block(nil, error);
        }
    }];
}

- (BOOL)shouldOpen {
    BOOL result = YES;

    if (strcmp(getenv("LCIM_BACKGROUND_CONNECT_ENABLED"), "1"))
        return YES;

#if TARGET_OS_IOS
    UIApplicationState state = [UIApplication sharedApplication].applicationState;

    if (state == UIApplicationStateBackground)
        result = NO;
#endif

    return result;
}

- (void)tryOpen {
    if (![self shouldOpen])
        return;

    if (![self.openLock tryLock])
        return;

    if ([self isConnectingOrOpen]) {
        [self.openLock unlock];
        return;
    }

    [self invalidateWebSocket];

    [self createWebSocketWithBlock:^(SRWebSocket *webSocket, NSError *error) {
        if (webSocket) {
            [self webSocketDidCreate:webSocket];
            [self.openLock unlock];
        } else {
            LC_ERROR(AVSomethingWrongCodeUnderlying, @"Cannot initialize WebSocket.", error);
            [self.openLock unlock];
            [self resumeExponentialBackoff];
        }
    }];
}

- (void)open {
    [self.openOperationQueue addOperationWithBlock:^{
        [self tryOpen];
    }];
}

- (void)sendFrame:(id<AVConnectionFrame>)frame {
    /* TODO */
}

- (void)invalidateWebSocket {
    if (!_webSocket)
        return;

    _webSocket.delegate = nil;
    [_webSocket close];
}

- (void)close {
    [self invalidateWebSocket];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self close];
}

@end
