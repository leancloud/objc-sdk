//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  LCRTMWebSocket.m
//
//  Created by Austin and Dalton Cherry on on 5/13/14.
//  Copyright (c) 2014-2017 Austin Cherry.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

#import "LCRTMWebSocket.h"

#import "AVErrorUtils.h"

//get the opCode from the packet
typedef NS_ENUM(NSUInteger, LCRTMOpCode) {
    LCRTMOpCodeContinueFrame = 0x0,
    LCRTMOpCodeTextFrame = 0x1,
    LCRTMOpCodeBinaryFrame = 0x2,
    //3-7 are reserved.
    LCRTMOpCodeConnectionClose = 0x8,
    LCRTMOpCodePing = 0x9,
    LCRTMOpCodePong = 0xA,
    //B-F reserved.
};

typedef NS_ENUM(NSUInteger, LCRTMCloseCode) {
    LCRTMCloseCodeNormal                 = 1000,
    LCRTMCloseCodeGoingAway              = 1001,
    LCRTMCloseCodeProtocolError          = 1002,
    LCRTMCloseCodeProtocolUnhandledType  = 1003,
    // 1004 reserved.
    LCRTMCloseCodeNoStatusReceived       = 1005,
    // 1006 reserved.
    LCRTMCloseCodeEncoding               = 1007,
    LCRTMCloseCodePolicyViolated         = 1008,
    LCRTMCloseCodeMessageTooBig          = 1009
};

typedef NS_ENUM(NSUInteger, LCRTMInternalErrorCode) {
    // 0-999 WebSocket status codes not used
    LCRTMOutputStreamWriteError = 1, //Output stream error during write
    LCRTMInvalidSSLError        = 2, //Invalid SSL certificate
    LCRTMWriteTimeoutError      = 3, //The socket timed out waiting to be ready to write
    LCRTMUpgradeError           = 4, //There was an error during the HTTP upgrade
    LCRTMCloseError             = 5  //There was an error during the close (socket probably has been dereferenced)
};

#define kLCRTMInternalHTTPStatusWebSocket 101

//holds the responses in our read stack to properly process messages
@interface LCRTMResponse : NSObject

@property(nonatomic, assign)BOOL isFin;
@property(nonatomic, assign)LCRTMOpCode code;
@property(nonatomic, assign)NSInteger bytesLeft;
@property(nonatomic, assign)NSInteger frameCount;
@property(nonatomic, strong)NSMutableData *buffer;

@end

@interface LCRTMWebSocket ()<NSStreamDelegate>

@property(nonatomic, strong, nonnull)NSURL *url;
@property(nonatomic, strong, nonnull)NSOperationQueue *writeQueue;
@property(nonatomic, strong, nonnull)dispatch_queue_t streamQueue;
@property(nonatomic, strong)NSInputStream *inputStream;
@property(nonatomic, strong)NSOutputStream *outputStream;
@property(nonatomic, assign)BOOL isRunLoop;
@property(nonatomic, strong, nonnull)NSMutableArray *readStack;
@property(nonatomic, strong, nonnull)NSMutableArray *inputQueue;
@property(nonatomic, strong, nullable)NSData *fragBuffer;
@property(nonatomic, strong, nullable)NSMutableDictionary *headers;
@property(nonatomic, strong, nullable)NSArray *optProtocols;
@property(atomic, assign)BOOL isConnected;
@property(nonatomic, assign)BOOL isCreated;
@property(nonatomic, assign)BOOL didDisconnect;
@property(nonatomic, assign)BOOL certValidated;

@end

//Constant Header Values.
NS_ASSUME_NONNULL_BEGIN
static NSString *const headerWSUpgradeName     = @"Upgrade";
static NSString *const headerWSUpgradeValue    = @"websocket";
static NSString *const headerWSHostName        = @"Host";
static NSString *const headerWSConnectionName  = @"Connection";
static NSString *const headerWSConnectionValue = @"Upgrade";
static NSString *const headerWSProtocolName    = @"Sec-WebSocket-Protocol";
static NSString *const headerWSVersionName     = @"Sec-Websocket-Version";
static NSString *const headerWSVersionValue    = @"13";
static NSString *const headerWSKeyName         = @"Sec-WebSocket-Key";
static NSString *const headerOriginName        = @"Origin";
static NSString *const headerWSAcceptName      = @"Sec-WebSocket-Accept";
NS_ASSUME_NONNULL_END

//Class Constants
static char CRLFBytes[] = {'\r', '\n', '\r', '\n'};
static int BUFFER_MAX = 4096;

// This get the correct bits out by masking the bytes of the buffer.
static const uint8_t LCRTMFinMask             = 0x80;
static const uint8_t LCRTMOpCodeMask          = 0x0F;
static const uint8_t LCRTMRSVMask             = 0x70;
static const uint8_t LCRTMMaskMask            = 0x80;
static const uint8_t LCRTMPayloadLenMask      = 0x7F;
static const size_t  LCRTMMaxFrameSize        = 32;

@implementation LCRTMWebSocket

/////////////////////////////////////////////////////////////////////////////
//Default initializer
- (instancetype)initWithURL:(NSURL *)url protocols:(NSArray*)protocols
{
    self = [super init];
    if (self) {
        self.certValidated = NO;
        self.voipEnabled = NO;
        self.selfSignedSSL = NO;
        self.queue = dispatch_get_main_queue();
        self.streamQueue = dispatch_queue_create("LCRTMWebSocket.streamQueue", DISPATCH_QUEUE_SERIAL);
        self.url = url;
        self.readStack = [NSMutableArray new];
        self.inputQueue = [NSMutableArray new];
        self.optProtocols = protocols;
    }
    return self;
}
/////////////////////////////////////////////////////////////////////////////
//Exposed method for connecting to URL provided in init method.
- (void)connect {
    if(self.isCreated) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        weakSelf.didDisconnect = NO;
    });

    //everything is on a background thread.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        weakSelf.isCreated = YES;
        [weakSelf createHTTPRequest];
        weakSelf.isCreated = NO;
    });
}
/////////////////////////////////////////////////////////////////////////////
- (void)disconnect {
    [self writeError:LCRTMCloseCodeNormal];
}
/////////////////////////////////////////////////////////////////////////////
- (void)writeString:(NSString*)string {
    if(string) {
        [self dequeueWrite:[string dataUsingEncoding:NSUTF8StringEncoding]
                  withCode:LCRTMOpCodeTextFrame];
    }
}
/////////////////////////////////////////////////////////////////////////////
- (void)writePing:(NSData*)data {
    [self dequeueWrite:data withCode:LCRTMOpCodePing];
}
/////////////////////////////////////////////////////////////////////////////
- (void)writeData:(NSData*)data {
    [self dequeueWrite:data withCode:LCRTMOpCodeBinaryFrame];
}
/////////////////////////////////////////////////////////////////////////////
- (void)addHeader:(NSString*)value forKey:(NSString*)key {
    if(!self.headers) {
        self.headers = [[NSMutableDictionary alloc] init];
    }
    [self.headers setObject:value forKey:key];
}
/////////////////////////////////////////////////////////////////////////////

#pragma mark - connect's internal supporting methods

/////////////////////////////////////////////////////////////////////////////

- (NSString *)origin;
{
    NSString *scheme = [self.url.scheme lowercaseString];
    
    if ([scheme isEqualToString:@"wss"]) {
        scheme = @"https";
    } else if ([scheme isEqualToString:@"ws"]) {
        scheme = @"http";
    }
    
    if (self.url.port) {
        return [NSString stringWithFormat:@"%@://%@:%@/", scheme, self.url.host, self.url.port];
    } else {
        return [NSString stringWithFormat:@"%@://%@/", scheme, self.url.host];
    }
}


//Uses CoreFoundation to build a HTTP request to send over TCP stream.
- (void)createHTTPRequest {
    CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)self.url.absoluteString, NULL);
    CFStringRef requestMethod = CFSTR("GET");
    CFHTTPMessageRef urlRequest = CFHTTPMessageCreateRequest(kCFAllocatorDefault,
                                                             requestMethod,
                                                             url,
                                                             kCFHTTPVersion1_1);
    CFRelease(url);
    
    NSNumber *port = self.url.port;
    if (!port) {
        if([self.url.scheme isEqualToString:@"wss"] || [self.url.scheme isEqualToString:@"https"]){
            port = @(443);
        } else {
            port = @(80);
        }
    }
    NSString *protocols = nil;
    if([self.optProtocols count] > 0) {
        protocols = [self.optProtocols componentsJoinedByString:@","];
    }
    CFHTTPMessageSetHeaderFieldValue(urlRequest,
                                     (__bridge CFStringRef)headerWSHostName,
                                     (__bridge CFStringRef)[NSString stringWithFormat:@"%@:%@",self.url.host,port]);
    CFHTTPMessageSetHeaderFieldValue(urlRequest,
                                     (__bridge CFStringRef)headerWSVersionName,
                                     (__bridge CFStringRef)headerWSVersionValue);
    CFHTTPMessageSetHeaderFieldValue(urlRequest,
                                     (__bridge CFStringRef)headerWSKeyName,
                                     (__bridge CFStringRef)[self generateWebSocketKey]);
    CFHTTPMessageSetHeaderFieldValue(urlRequest,
                                     (__bridge CFStringRef)headerWSUpgradeName,
                                     (__bridge CFStringRef)headerWSUpgradeValue);
    CFHTTPMessageSetHeaderFieldValue(urlRequest,
                                     (__bridge CFStringRef)headerWSConnectionName,
                                     (__bridge CFStringRef)headerWSConnectionValue);
    if (protocols.length > 0) {
        CFHTTPMessageSetHeaderFieldValue(urlRequest,
                                         (__bridge CFStringRef)headerWSProtocolName,
                                         (__bridge CFStringRef)protocols);
    }
   
    /// Objc SDK should not set Origin Header.
    /*
    CFHTTPMessageSetHeaderFieldValue(urlRequest,
                                     (__bridge CFStringRef)headerOriginName,
                                     (__bridge CFStringRef)[self origin]);
    */
    
    for(NSString *key in self.headers) {
        CFHTTPMessageSetHeaderFieldValue(urlRequest,
                                         (__bridge CFStringRef)key,
                                         (__bridge CFStringRef)self.headers[key]);
    }
    
#if defined(DEBUG)
    NSLog(@"urlRequest = \"%@\"", urlRequest);
#endif
    NSData *serializedRequest = (__bridge_transfer NSData *)(CFHTTPMessageCopySerializedMessage(urlRequest));
    [self initStreamsWithData:serializedRequest port:port];
    CFRelease(urlRequest);
}
/////////////////////////////////////////////////////////////////////////////
//Random String of 16 lowercase chars, SHA1 and base64 encoded.
- (NSString*)generateWebSocketKey {
    NSInteger seed = 16;
    NSMutableString *string = [NSMutableString stringWithCapacity:seed];
    for (int i = 0; i < seed; i++) {
        [string appendFormat:@"%C", (unichar)('a' + arc4random_uniform(25))];
    }
    return [[string dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
}
/////////////////////////////////////////////////////////////////////////////
//Sets up our reader/writer for the TCP stream.
- (void)initStreamsWithData:(NSData*)data port:(NSNumber*)port {
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)self.url.host, [port intValue], &readStream, &writeStream);
    
    self.inputStream = (__bridge_transfer NSInputStream *)readStream;
    self.inputStream.delegate = self;
    NSOutputStream *outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    self.outputStream = outputStream;
    self.outputStream.delegate = self;
    if([self.url.scheme isEqualToString:@"wss"] || [self.url.scheme isEqualToString:@"https"]) {
        [self.inputStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
        [self.outputStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
    } else {
        self.certValidated = YES; //not a https session, so no need to check SSL pinning
    }
    if(self.voipEnabled) {
        [self.inputStream setProperty:NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
        [self.outputStream setProperty:NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
    }
    if(self.selfSignedSSL) {
        NSString *chain = (__bridge_transfer NSString *)kCFStreamSSLValidatesCertificateChain;
        NSString *peerName = (__bridge_transfer NSString *)kCFStreamSSLValidatesCertificateChain;
        NSString *key = (__bridge_transfer NSString *)kCFStreamPropertySSLSettings;
        NSDictionary *settings = @{chain: [[NSNumber alloc] initWithBool:NO],
                                   peerName: [NSNull null]};
        [self.inputStream setProperty:settings forKey:key];
        [self.outputStream setProperty:settings forKey:key];
    }
    CFReadStreamSetDispatchQueue((__bridge CFReadStreamRef)self.inputStream, self.streamQueue);
    CFWriteStreamSetDispatchQueue((__bridge CFWriteStreamRef)self.outputStream, self.streamQueue);
    [self.inputStream open];
    [self.outputStream open];
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.streamQueue, ^{
        NSTimeInterval timeout = (60 * 1000000);
        while (!outputStream.hasSpaceAvailable) {
            usleep(100);
            timeout -= 100;
            if (timeout < 0) {
                NSError *error = [LCRTMWebSocket errorWithDetail:@"Timed out waiting for the socket to be ready for a write" code:LCRTMWriteTimeoutError];
                [weakSelf disconnectStream:error];
                return;
            } else if (outputStream.streamError) {
                [weakSelf disconnectStream:outputStream.streamError];
                return;
            } else if (!weakSelf) {
                return;
            }
        }
        NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
            [outputStream write:[data bytes] maxLength:[data length]];
        }];
        [weakSelf.writeQueue addOperation:op];
    });
    
    self.isRunLoop = YES;
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    while (self.isRunLoop) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}
/////////////////////////////////////////////////////////////////////////////

#pragma mark - NSStreamDelegate

/////////////////////////////////////////////////////////////////////////////
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    if(self.security && !self.certValidated && (eventCode == NSStreamEventHasBytesAvailable || eventCode == NSStreamEventHasSpaceAvailable)) {
        SecTrustRef trust = (__bridge SecTrustRef)([aStream propertyForKey:(__bridge_transfer NSString *)kCFStreamPropertySSLPeerTrust]);
        NSString *domain = [aStream propertyForKey:(__bridge_transfer NSString *)kCFStreamSSLPeerName];
        if([self.security isValid:trust domain:domain]) {
            self.certValidated = YES;
        } else {
            [self disconnectStream:[LCRTMWebSocket errorWithDetail:@"Invalid SSL certificate" code:1]];
            return;
        }
    }
    switch (eventCode) {
        case NSStreamEventNone:
            break;
            
        case NSStreamEventOpenCompleted:
            break;
            
        case NSStreamEventHasBytesAvailable:
            if(aStream == self.inputStream) {
                [self processInputStream];
            }
            break;
            
        case NSStreamEventHasSpaceAvailable:
            break;
            
        case NSStreamEventErrorOccurred:
            [self disconnectStream:[aStream streamError]];
            break;
            
        case NSStreamEventEndEncountered:
            [self disconnectStream:nil];
            break;
            
        default:
            break;
    }
}
/////////////////////////////////////////////////////////////////////////////
- (void)disconnectStream:(NSError*)error {
    if (error) {
        [self.writeQueue cancelAllOperations];
    } else {
        [self.writeQueue waitUntilAllOperationsAreFinished];
    }
    if (self.inputStream) {
        self.inputStream.delegate = nil;
        CFReadStreamSetDispatchQueue((__bridge CFReadStreamRef)self.inputStream, NULL);
        [self.inputStream close];
        self.inputStream = nil;
    }
    if (self.outputStream) {
        self.outputStream.delegate = nil;
        CFWriteStreamSetDispatchQueue((__bridge CFWriteStreamRef)self.outputStream, NULL);
        [self.outputStream close];
        self.outputStream = nil;
    }
    
    self.isRunLoop = NO;
    self.isConnected = NO;
    self.certValidated = NO;
    
    [self doDisconnect:error];
}
/////////////////////////////////////////////////////////////////////////////

#pragma mark - Stream Processing Methods

/////////////////////////////////////////////////////////////////////////////
- (void)processInputStream {
    @autoreleasepool {
        uint8_t buffer[BUFFER_MAX];
        NSInteger length = [self.inputStream read:buffer maxLength:BUFFER_MAX];
        if(length > 0) {
            if(!self.isConnected) {
                CFIndex responseStatusCode;
                BOOL status = [self processHTTP:buffer length:length responseStatusCode:&responseStatusCode];
#if defined(DEBUG)
                if (length < BUFFER_MAX) {
                    buffer[length] = 0x00;
                } else {
                    buffer[BUFFER_MAX - 1] = 0x00;
                }
                NSLog(@"response (%ld) = \"%s\"", responseStatusCode, buffer);
#endif
                if(status == NO) {
                    [self doDisconnect:[LCRTMWebSocket errorWithDetail:@"Invalid HTTP upgrade" code:1 userInfo:@{@"HTTPResponseStatusCode" : @(responseStatusCode)}]];
                }
            } else {
                BOOL process = NO;
                if(self.inputQueue.count == 0) {
                    process = YES;
                }
                [self.inputQueue addObject:[NSData dataWithBytes:buffer length:length]];
                if(process) {
                    [self dequeueInput];
                }
            }
        }
    }
}
/////////////////////////////////////////////////////////////////////////////
- (void)dequeueInput {
    if(self.inputQueue.count > 0) {
        NSData *data = [self.inputQueue objectAtIndex:0];
        NSData *work = data;
        if(self.fragBuffer) {
            NSMutableData *combine = [NSMutableData dataWithData:self.fragBuffer];
            [combine appendData:data];
            work = combine;
            self.fragBuffer = nil;
        }
        [self processRawMessage:(uint8_t*)work.bytes length:work.length];
        [self.inputQueue removeObject:data];
        [self dequeueInput];
    }
}
/////////////////////////////////////////////////////////////////////////////
//Finds the HTTP Packet in the TCP stream, by looking for the CRLF.
- (BOOL)processHTTP:(uint8_t*)buffer length:(NSInteger)bufferLen responseStatusCode:(CFIndex*)responseStatusCode {
    int k = 0;
    NSInteger totalSize = 0;
    for(int i = 0; i < bufferLen; i++) {
        if(buffer[i] == CRLFBytes[k]) {
            k++;
            if(k == 3) {
                totalSize = i + 1;
                break;
            }
        } else {
            k = 0;
        }
    }
    if(totalSize > 0) {
        BOOL status = [self validateResponse:buffer length:totalSize responseStatusCode:responseStatusCode];
        if (status == YES) {
            self.isConnected = YES;
            __weak typeof(self) weakSelf = self;
            dispatch_async(self.queue,^{
                LCRTMWebSocket *strongSelf = weakSelf;
                if (!strongSelf) { return; }
                if([strongSelf.delegate respondsToSelector:@selector(websocketDidConnect:)]) {
                    [strongSelf.delegate websocketDidConnect:strongSelf];
                }
            });
            totalSize += 1; //skip the last \n
            NSInteger  restSize = bufferLen-totalSize;
            if(restSize > 0) {
                [self processRawMessage:(buffer+totalSize) length:restSize];
            }
        }
        return status;
    }
    return NO;
}
/////////////////////////////////////////////////////////////////////////////
//Validate the HTTP is a 101, as per the RFC spec.
- (BOOL)validateResponse:(uint8_t *)buffer length:(NSInteger)bufferLen responseStatusCode:(CFIndex*)responseStatusCode {
    CFHTTPMessageRef response = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, NO);
    CFHTTPMessageAppendBytes(response, buffer, bufferLen);
    *responseStatusCode = CFHTTPMessageGetResponseStatusCode(response);
    BOOL status = ((*responseStatusCode) == kLCRTMInternalHTTPStatusWebSocket)?(YES):(NO);
    if(status == NO) {
        CFRelease(response);
        return NO;
    }
    NSDictionary *headers = (__bridge_transfer NSDictionary *)(CFHTTPMessageCopyAllHeaderFields(response));
    NSString *acceptKey = headers[headerWSAcceptName];
    CFRelease(response);
    if(acceptKey.length > 0) {
        return YES;
    }
    return NO;
}
/////////////////////////////////////////////////////////////////////////////
-(void)processRawMessage:(uint8_t*)buffer length:(NSInteger)bufferLen {
    LCRTMResponse *response = [self.readStack lastObject];
    if(response && bufferLen < 2) {
        self.fragBuffer = [NSData dataWithBytes:buffer length:bufferLen];
        return;
    }
    if(response.bytesLeft > 0) {
        NSInteger len = response.bytesLeft;
        NSInteger extra =  bufferLen - response.bytesLeft;
        if(response.bytesLeft > bufferLen) {
            len = bufferLen;
            extra = 0;
        }
        response.bytesLeft -= len;
        [response.buffer appendData:[NSData dataWithBytes:buffer length:len]];
        [self processResponse:response];
        NSInteger offset = bufferLen - extra;
        if(extra > 0) {
            [self processExtra:(buffer+offset) length:extra];
        }
        return;
    } else {
        if(bufferLen < 2) { // we need at least 2 bytes for the header
            self.fragBuffer = [NSData dataWithBytes:buffer length:bufferLen];
            return;
        }
        BOOL isFin = (LCRTMFinMask & buffer[0]);
        uint8_t receivedOpcode = (LCRTMOpCodeMask & buffer[0]);
        BOOL isMasked = (LCRTMMaskMask & buffer[1]);
        uint8_t payloadLen = (LCRTMPayloadLenMask & buffer[1]);
        NSInteger offset = 2; //how many bytes do we need to skip for the header
        if((isMasked  || (LCRTMRSVMask & buffer[0])) && receivedOpcode != LCRTMOpCodePong) {
            [self doDisconnect:[LCRTMWebSocket errorWithDetail:@"masked and rsv data is not currently supported" code:LCRTMCloseCodeProtocolError]];
            [self writeError:LCRTMCloseCodeProtocolError];
            return;
        }
        BOOL isControlFrame = (receivedOpcode == LCRTMOpCodeConnectionClose || receivedOpcode == LCRTMOpCodePing);
        if(!isControlFrame && (receivedOpcode != LCRTMOpCodeBinaryFrame && receivedOpcode != LCRTMOpCodeContinueFrame && receivedOpcode != LCRTMOpCodeTextFrame && receivedOpcode != LCRTMOpCodePong)) {
            [self doDisconnect:[LCRTMWebSocket errorWithDetail:[NSString stringWithFormat:@"unknown opcode: 0x%x",receivedOpcode] code:LCRTMCloseCodeProtocolError]];
            [self writeError:LCRTMCloseCodeProtocolError];
            return;
        }
        if(isControlFrame && !isFin) {
            [self doDisconnect:[LCRTMWebSocket errorWithDetail:@"control frames can't be fragmented" code:LCRTMCloseCodeProtocolError]];
            [self writeError:LCRTMCloseCodeProtocolError];
            return;
        }
        if(receivedOpcode == LCRTMOpCodeConnectionClose) {
            //the server disconnected us
            uint16_t code = LCRTMCloseCodeNormal;
            if(payloadLen == 1) {
                code = LCRTMCloseCodeProtocolError;
            }
            else if(payloadLen > 1) {
                code = CFSwapInt16BigToHost(*(uint16_t *)(buffer+offset) );
                if(code < 1000 || (code > 1003 && code < 1007) || (code > 1011 && code < 3000)) {
                    code = LCRTMCloseCodeProtocolError;
                }
                offset += 2;
            }
            
            if(payloadLen > 2) {
                NSInteger len = payloadLen-2;
                if(len > 0) {
                    NSData *data = [NSData dataWithBytes:(buffer+offset) length:len];
                    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    if(!str) {
                        code = LCRTMCloseCodeProtocolError;
                    }
                }
            }
            [self writeError:code];
            [self doDisconnect:[LCRTMWebSocket errorWithDetail:@"continue frame before a binary or text frame" code:code]];
            return;
        }
        if(isControlFrame && payloadLen > 125) {
            [self writeError:LCRTMCloseCodeProtocolError];
            return;
        }
        NSInteger dataLength = payloadLen;
        if(payloadLen == 127) {
            dataLength = (NSInteger)CFSwapInt64BigToHost(*(uint64_t *)(buffer+offset));
            offset += sizeof(uint64_t);
        } else if(payloadLen == 126) {
            dataLength = CFSwapInt16BigToHost(*(uint16_t *)(buffer+offset) );
            offset += sizeof(uint16_t);
        }
        if(bufferLen < offset) { // we cannot process this yet, nead more header data
            self.fragBuffer = [NSData dataWithBytes:buffer length:bufferLen];
            return;
        }
        NSInteger len = dataLength;
        if(dataLength > (bufferLen-offset) || (bufferLen - offset) < dataLength) {
            len = bufferLen-offset;
        }
        NSData *data = nil;
        if(len < 0) {
            len = 0;
            data = [NSData data];
        } else {
            data = [NSData dataWithBytes:(buffer+offset) length:len];
        }
        if(receivedOpcode == LCRTMOpCodePong) {
            __weak typeof(self) weakSelf = self;
            dispatch_async(self.queue,^{
                LCRTMWebSocket *strongSelf = weakSelf;
                if (!strongSelf) { return; }
                if([strongSelf.delegate respondsToSelector:@selector(websocket:didReceivePong:)]) {
                    [strongSelf.delegate websocket:strongSelf didReceivePong:data];
                }
            });
            NSInteger step = (offset+len);
            NSInteger extra = bufferLen-step;
            if(extra > 0) {
                [self processRawMessage:(buffer+step) length:extra];
            }
            return;
        }
        LCRTMResponse *response = [self.readStack lastObject];
        if(isControlFrame) {
            response = nil; //don't append pings
        }
        if(!isFin && receivedOpcode == LCRTMOpCodeContinueFrame && !response) {
            [self doDisconnect:[LCRTMWebSocket errorWithDetail:@"continue frame before a binary or text frame" code:LCRTMCloseCodeProtocolError]];
            [self writeError:LCRTMCloseCodeProtocolError];
            return;
        }
        BOOL isNew = NO;
        if(!response) {
            if(receivedOpcode == LCRTMOpCodeContinueFrame) {
                [self doDisconnect:[LCRTMWebSocket errorWithDetail:@"first frame can't be a continue frame" code:LCRTMCloseCodeProtocolError]];
                [self writeError:LCRTMCloseCodeProtocolError];
                return;
            }
            isNew = YES;
            response = [LCRTMResponse new];
            response.code = receivedOpcode;
            response.bytesLeft = dataLength;
            response.buffer = [NSMutableData dataWithData:data];
        } else {
            if(receivedOpcode == LCRTMOpCodeContinueFrame) {
                response.bytesLeft = dataLength;
            } else {
                [self doDisconnect:[LCRTMWebSocket errorWithDetail:@"second and beyond of fragment message must be a continue frame" code:LCRTMCloseCodeProtocolError]];
                [self writeError:LCRTMCloseCodeProtocolError];
                return;
            }
            [response.buffer appendData:data];
        }
        response.bytesLeft -= len;
        response.frameCount++;
        response.isFin = isFin;
        if(isNew) {
            [self.readStack addObject:response];
        }
        [self processResponse:response];
        
        NSInteger step = (offset+len);
        NSInteger extra = bufferLen-step;
        if(extra > 0) {
            [self processExtra:(buffer+step) length:extra];
        }
    }
    
}
/////////////////////////////////////////////////////////////////////////////
- (void)processExtra:(uint8_t*)buffer length:(NSInteger)bufferLen {
    if(bufferLen < 2) {
        self.fragBuffer = [NSData dataWithBytes:buffer length:bufferLen];
    } else {
        [self processRawMessage:buffer length:bufferLen];
    }
}
/////////////////////////////////////////////////////////////////////////////
- (BOOL)processResponse:(LCRTMResponse*)response {
    if(response.isFin && response.bytesLeft <= 0) {
        NSData *data = response.buffer;
        if(response.code == LCRTMOpCodePing) {
            [self dequeueWrite:response.buffer withCode:LCRTMOpCodePong];
        } else if(response.code == LCRTMOpCodeTextFrame) {
            NSString *str = [[NSString alloc] initWithData:response.buffer encoding:NSUTF8StringEncoding];
            if(!str) {
                [self writeError:LCRTMCloseCodeEncoding];
                return NO;
            }
            __weak typeof(self) weakSelf = self;
            dispatch_async(self.queue,^{
                LCRTMWebSocket *strongSelf = weakSelf;
                if (!strongSelf) { return; }
                if([strongSelf.delegate respondsToSelector:@selector(websocket:didReceiveMessage:)]) {
                    [strongSelf.delegate websocket:strongSelf didReceiveMessage:str];
                }
            });
        } else if(response.code == LCRTMOpCodeBinaryFrame) {
            __weak typeof(self) weakSelf = self;
            dispatch_async(self.queue,^{
                LCRTMWebSocket *strongSelf = weakSelf;
                if (!strongSelf) { return; }
                if([strongSelf.delegate respondsToSelector:@selector(websocket:didReceiveData:)]) {
                    [strongSelf.delegate websocket:strongSelf didReceiveData:data];
                }
            });
        }
        [self.readStack removeLastObject];
        return YES;
    }
    return NO;
}
/////////////////////////////////////////////////////////////////////////////
-(void)dequeueWrite:(NSData*)data withCode:(LCRTMOpCode)code {
    if(!self.isConnected) {
        return;
    }
    if(!self.writeQueue) {
        self.writeQueue = [[NSOperationQueue alloc] init];
        self.writeQueue.maxConcurrentOperationCount = 1;
    }
    
    __weak typeof(self) weakSelf = self;
    [self.writeQueue addOperationWithBlock:^{
        LCRTMWebSocket *strongSelf = weakSelf;
        if(!strongSelf || !strongSelf.isConnected) {
            return;
        }
        uint64_t offset = 2; //how many bytes do we need to skip for the header
        uint8_t *bytes = (uint8_t*)[data bytes];
        uint64_t dataLength = data.length;
        NSMutableData *frame = [[NSMutableData alloc] initWithLength:(NSInteger)(dataLength + LCRTMMaxFrameSize)];
        uint8_t *buffer = (uint8_t*)[frame mutableBytes];
        buffer[0] = LCRTMFinMask | code;
        if(dataLength < 126) {
            buffer[1] |= dataLength;
        } else if(dataLength <= UINT16_MAX) {
            buffer[1] |= 126;
            *((uint16_t *)(buffer + offset)) = CFSwapInt16BigToHost((uint16_t)dataLength);
            offset += sizeof(uint16_t);
        } else {
            buffer[1] |= 127;
            *((uint64_t *)(buffer + offset)) = CFSwapInt64BigToHost((uint64_t)dataLength);
            offset += sizeof(uint64_t);
        }
        BOOL isMask = YES;
        if(isMask) {
            buffer[1] |= LCRTMMaskMask;
            uint8_t *mask_key = (buffer + offset);
            (void)SecRandomCopyBytes(kSecRandomDefault, sizeof(uint32_t), (uint8_t *)mask_key);
            offset += sizeof(uint32_t);
            
            for (size_t i = 0; i < dataLength; i++) {
                buffer[offset] = bytes[i] ^ mask_key[i % sizeof(uint32_t)];
                offset += 1;
            }
        } else {
            for(size_t i = 0; i < dataLength; i++) {
                buffer[offset] = bytes[i];
                offset += 1;
            }
        }
        uint64_t total = 0;
        while (true) {
            if(!strongSelf.isConnected || !strongSelf.outputStream) {
                break;
            }
            NSInteger len = [strongSelf.outputStream write:([frame bytes]+total) maxLength:(NSInteger)(offset-total)];
            if(len < 0 || len == NSNotFound) {
                NSError *error = strongSelf.outputStream.streamError;
                if(!error) {
                    error = [LCRTMWebSocket errorWithDetail:@"output stream error during write" code:LCRTMOutputStreamWriteError];
                }
                [strongSelf doDisconnect:error];
                break;
            } else {
                total += len;
            }
            if(total >= offset) {
                break;
            }
        }
    }];
}
/////////////////////////////////////////////////////////////////////////////
- (void)doDisconnect:(NSError*)error {
    if(!self.didDisconnect) {
        self.didDisconnect = YES;
        __weak typeof(self) weakSelf = self;
        dispatch_async(self.queue, ^{
            LCRTMWebSocket *strongSelf = weakSelf;
            if (!strongSelf) { return; }
            
            [strongSelf disconnect];
            
            if([strongSelf.delegate respondsToSelector:@selector(websocketDidDisconnect:error:)]) {
                [strongSelf.delegate websocketDidDisconnect:strongSelf error:error];
            }
        });
    }
}
/////////////////////////////////////////////////////////////////////////////
+ (NSError *)errorWithDetail:(NSString *)detail code:(NSInteger)code {
    return [self errorWithDetail:detail code:code userInfo:nil];
}
+ (NSError *)errorWithDetail:(NSString *)detail code:(NSInteger)code userInfo:(NSDictionary *)userInfo {
    NSMutableDictionary *info;
    if (userInfo) {
        info = [NSMutableDictionary dictionaryWithDictionary:userInfo];
    } else {
        info = [NSMutableDictionary dictionary];
    }
    info[NSLocalizedFailureReasonErrorKey] = detail;
    return [NSError errorWithDomain:@"LCRTMWebSocket" code:code userInfo:info];
}
/////////////////////////////////////////////////////////////////////////////
- (void)writeError:(uint16_t)code {
    uint16_t buffer[1];
    buffer[0] = CFSwapInt16BigToHost(code);
    [self dequeueWrite:[NSData dataWithBytes:buffer length:sizeof(uint16_t)] withCode:LCRTMOpCodeConnectionClose];
}
/////////////////////////////////////////////////////////////////////////////
- (void)dealloc {
    if(self.isConnected) {
        [self disconnect];
    }
}
/////////////////////////////////////////////////////////////////////////////
@end

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
@implementation LCRTMResponse

@end
/////////////////////////////////////////////////////////////////////////////

@protocol LCRTMFoundationTransportDelegate <NSObject>

- (void)connected;
- (void)cancelled;
- (void)failedWithError:(NSError *)error;
- (void)receive:(NSData *)data;

@end

@interface LCRTMFoundationTransport : NSObject <NSStreamDelegate>

@property (nonatomic, weak) id <LCRTMFoundationTransportDelegate> delegate;
@property (nonatomic, strong) dispatch_queue_t delegateQueue;
@property (nonatomic, strong) dispatch_queue_t workQueue;
@property (nonatomic, strong) dispatch_queue_t writeQueue;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, assign) BOOL isOpened;

@end

@implementation LCRTMFoundationTransport

- (instancetype)init
{
    self = [super init];
    if (self) {
        _delegateQueue = dispatch_get_main_queue();
        _workQueue = dispatch_queue_create("LCRTMFoundationTransport.workQueue", NULL);
        _writeQueue = dispatch_queue_create("LCRTMFoundationTransport.writeQueue", NULL);
        _isOpened = false;
    }
    return self;
}

- (void)connectURL:(NSURL *)URL timeout:(NSTimeInterval)timeout
{
    if (!URL.host) {
        dispatch_async(self.delegateQueue, ^{
            [self.delegate failedWithError:LCError(9976, @"Invalid request.", @{
                @"URL": (URL ?: @"nil"),
            })];
        });
        return;
    }
    NSNumber *port = URL.port;
    if (!port) {
        if (URL.scheme && [@[@"wss", @"https"] containsObject:URL.scheme]) {
            port = @443;
        } else {
            port = @80;
        }
    }
    CFReadStreamRef readStreamRef;
    CFWriteStreamRef writeStreamRef;
    CFStreamCreatePairWithSocketToHost(NULL,
                                       (__bridge CFStringRef)(URL.host),
                                       port.unsignedIntValue,
                                       &readStreamRef,
                                       &writeStreamRef);
    self.inputStream = (__bridge_transfer NSInputStream *)(readStreamRef);
    self.outputStream = (__bridge_transfer NSOutputStream *)(writeStreamRef);
    if (!self.inputStream || !self.outputStream) {
        dispatch_async(self.delegateQueue, ^{
            [self.delegate failedWithError:LCError(9976, @"Socket creating failed.", @{
                @"host": URL.host,
                @"port": port,
            })];
        });
        return;
    }
    self.inputStream.delegate = self;
    self.outputStream.delegate = self;
    self.isOpened = false;
    CFReadStreamSetDispatchQueue((__bridge CFReadStreamRef)self.inputStream, self.workQueue);
    CFWriteStreamSetDispatchQueue((__bridge CFWriteStreamRef)self.outputStream, self.workQueue);
    [self.inputStream open];
    [self.outputStream open];
    __weak typeof(self) ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), self.workQueue, ^{
        LCRTMFoundationTransport *ss = ws;
        if (!ss) {
            return;
        }
        if (!ss.isOpened) {
            dispatch_async(self.delegateQueue, ^{
                [ss.delegate failedWithError:LCError(9001, @"Socket opening timeout.", @{
                    @"host": URL.host,
                    @"port": port,
                })];
            });
            return;
        }
    });
}

- (void)disconnect
{
    dispatch_async(self.workQueue, ^{
        [self _disconnect];
    });
}

- (void)_disconnect
{
    if (self.inputStream) {
        self.inputStream.delegate = nil;
        CFReadStreamSetDispatchQueue((__bridge CFReadStreamRef)self.inputStream, NULL);
        [self.inputStream close];
        self.inputStream = nil;
    }
    if (self.outputStream) {
        self.outputStream.delegate = nil;
        CFWriteStreamSetDispatchQueue((__bridge CFWriteStreamRef)self.outputStream, NULL);
        [self.outputStream close];
        self.outputStream = nil;
    }
    self.isOpened = false;
}

- (void)write:(NSData *)data error:(NSError * __autoreleasing *)errPtr
{
    
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    
}

@end
