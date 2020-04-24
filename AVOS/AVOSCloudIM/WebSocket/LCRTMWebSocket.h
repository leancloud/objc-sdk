//
//  LCRTMWebSocket.h
//  AVOS
//
//  Created by zapcannon87 on 2020/4/23.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LCRTMWebSocketCloseCode)
{
    LCRTMWebSocketCloseCodeInvalid =                             0,
    LCRTMWebSocketCloseCodeNormalClosure =                    1000,
    LCRTMWebSocketCloseCodeGoingAway =                        1001,
    LCRTMWebSocketCloseCodeProtocolError =                    1002,
    LCRTMWebSocketCloseCodeUnsupportedData =                  1003,
    LCRTMWebSocketCloseCodeNoStatusReceived =                 1005,
    LCRTMWebSocketCloseCodeAbnormalClosure =                  1006,
    LCRTMWebSocketCloseCodeInvalidFramePayloadData =          1007,
    LCRTMWebSocketCloseCodePolicyViolation =                  1008,
    LCRTMWebSocketCloseCodeMessageTooBig =                    1009,
    LCRTMWebSocketCloseCodeMandatoryExtensionMissing =        1010,
    LCRTMWebSocketCloseCodeInternalServerError =              1011,
    LCRTMWebSocketCloseCodeTLSHandshakeFailure =              1015,
};

typedef NS_ENUM(NSInteger, LCRTMWebSocketMessageType) {
    LCRTMWebSocketMessageTypeData = 0,
    LCRTMWebSocketMessageTypeString = 1,
};

@interface LCRTMWebSocketMessage : NSObject

+ (instancetype)messageWithData:(NSData *)data;
+ (instancetype)messageWithString:(NSString *)string;

- (instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithString:(NSString *)string NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) LCRTMWebSocketMessageType type;
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) NSString *string;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@class LCRTMWebSocket;

@protocol LCRTMWebSocketDelegate <NSObject>

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didOpenWithProtocol:(NSString *)protocol;

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didCloseWithError:(NSError *)error;

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didReceiveMessage:(LCRTMWebSocketMessage *)message;

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didReceivePing:(NSData *)data;

- (void)LCRTMWebSocket:(LCRTMWebSocket *)socket didReceivePong:(NSData *)data;

@end

@interface LCRTMWebSocket : NSObject

@property (nonatomic, weak) id <LCRTMWebSocketDelegate> delegate;
@property (nonatomic) dispatch_queue_t delegateQueue;
@property (nonatomic) NSMutableURLRequest *request;

- (instancetype)initWithURL:(NSURL *)url;
- (instancetype)initWithURL:(NSURL *)url protocols:(NSArray<NSString *> *)protocols;
- (instancetype)initWithRequest:(NSURLRequest *)request;

- (void)open;
- (void)closeWithCloseCode:(LCRTMWebSocketCloseCode)closeCode reason:(NSData *)reason;

- (void)sendMessage:(LCRTMWebSocketMessage *)message completion:(void (^)(void))completion;
- (void)sendPing:(NSData *)data completion:(void (^)(void))completion;
- (void)sendPong:(NSData *)data completion:(void (^)(void))completion;

- (void)safeClean;

@end
