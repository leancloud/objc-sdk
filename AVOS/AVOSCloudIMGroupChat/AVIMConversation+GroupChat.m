//
//  AVIMConversation+GroupChat.m
//  AVOSCloudIMExtension
//
//  Created by Tang Tianyong on 19/07/2017.
//  Copyright © 2017 LeanCloud. All rights reserved.
//

#import "AVIMConversation+GroupChat.h"
#import "AVIMConversation_Internal.h"
#import "AVIMClient_Internal.h"
#import "AVIMReadReceiptMessage.h"
#import "AVUtils.h"

#import <objc/runtime.h>

#define _SetNSErrorFor(FUNC, ERROR_VAR, FORMAT,...)    \
if (ERROR_VAR) {    \
NSString *errStr = [NSString stringWithFormat:@"%s: " FORMAT,FUNC,##__VA_ARGS__]; \
*ERROR_VAR = [NSError errorWithDomain:@"NSCocoaErrorDomain" \
code:-1    \
userInfo:[NSDictionary dictionaryWithObject:errStr forKey:NSLocalizedDescriptionKey]]; \
}
#define _SetNSError(ERROR_VAR, FORMAT,...) _SetNSErrorFor(__func__, ERROR_VAR, FORMAT, ##__VA_ARGS__)

@interface AVIMConversation ()

- (void)didReceiveMessage:(AVIMMessage *)message;
- (void)callDelegateMethod:(SEL)method withArguments:(NSArray *)arguments;

@end

@implementation AVIMConversation (GroupChat)

+ (void)load {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        swizzleMethodsForGroupChat(self);
    });
}

NS_INLINE
void swizzleMethodsForGroupChat(Class aClass) {
    
    BOOL (^swizzleMethod_block)(SEL, SEL, NSError **) = ^BOOL(SEL origSel_, SEL altSel_, NSError **error_) {
        
        Method origMethod = class_getInstanceMethod(aClass, origSel_);
        if (!origMethod) {
#if TARGET_OS_IPHONE
            _SetNSError(error_, @"original method %@ not found for class %@", NSStringFromSelector(origSel_), [aClass class]);
#else
            _SetNSError(error_, @"original method %@ not found for class %@", NSStringFromSelector(origSel_), [aClass className]);
#endif
            return NO;
        }
        
        Method altMethod = class_getInstanceMethod(aClass, altSel_);
        if (!altMethod) {
#if TARGET_OS_IPHONE
            _SetNSError(error_, @"alternate method %@ not found for class %@", NSStringFromSelector(altSel_), [aClass class]);
#else
            _SetNSError(error_, @"alternate method %@ not found for class %@", NSStringFromSelector(altSel_), [aClass className]);
#endif
            return NO;
        }
        
        class_addMethod(aClass,
                        origSel_,
                        class_getMethodImplementation(aClass, origSel_),
                        method_getTypeEncoding(origMethod));
        class_addMethod(aClass,
                        altSel_,
                        class_getMethodImplementation(aClass, altSel_),
                        method_getTypeEncoding(altMethod));
        
        method_exchangeImplementations(class_getInstanceMethod(aClass, origSel_), class_getInstanceMethod(aClass, altSel_));
        
        return YES;
    };
    
    NSError *error = nil;
    BOOL succeeded = (
                      swizzleMethod_block(@selector(readInBackground), @selector(readInBackgroundSwizzledForGroupChat), &error)
                      &&
                      swizzleMethod_block(@selector(didReceiveMessage:), @selector(didReceiveMessageSwizzledForGroupChat:), &error)
                      &&
                      swizzleMethod_block(@selector(fetchReceiptTimestampsInBackground), @selector(fetchReceiptTimestampsInBackgroundSwizzledForGroupChat), &error)
                      );

    if (!succeeded || error)
        AVLoggerError(AVOSCloudIMErrorDomain,
                      @"Cannot extend conversation for group chat, error: %@",
                      error ?: @"unknown");
}

- (NSMutableDictionary *)lastReadTimestamps {
    static const void *key = &key;

    @synchronized (self) {
        NSMutableDictionary *dictionary = objc_getAssociatedObject(self, key);

        if (!dictionary) {
            dictionary = [NSMutableDictionary dictionary];
            objc_setAssociatedObject(self, key, dictionary, OBJC_ASSOCIATION_RETAIN);
        }

        return dictionary;
    }
}

- (void)readInBackgroundSwizzledForGroupChat {
    if (self.transient)
        return;

    if (self.members.count > 2) {
        NSDate *readAt = self.lastMessageAt ?: [NSDate date];

        [self readInBackgroundSwizzledForGroupChat];
        /* For group chat, we broadcast read receipt by transient message. */
        [self broadcastReadReceiptForGroupChat:readAt];
    } else {
        /* Call original implementation for one-one chat. */
        [self readInBackgroundSwizzledForGroupChat];
    }
}

- (void)broadcastReadReceiptForGroupChat:(NSDate *)readAt {
    int64_t timestamp = [readAt timeIntervalSince1970] * 1000;

    AVIMReadReceiptMessage *message = [[AVIMReadReceiptMessage alloc] init];
    message.timestamp = timestamp;

    AVIMMessageOption *option = [[AVIMMessageOption alloc] init];
    option.transient = YES;

    [self sendMessage:message option:option callback:^(BOOL succeeded, NSError *error) {
        /* Do nothing after send read receipt. */
    }];
}

- (void)didReceiveMessageSwizzledForGroupChat:(AVIMMessage *)message {
    [self didReceiveMessageSwizzledForGroupChat:message];

    if (message.mediaType != kAVIMMessageMediaTypeReadReceipt)
        return;

    [self didReceiveReadReceiptMessage:(AVIMReadReceiptMessage *)message];
}

- (void)didReceiveReadReceiptMessage:(AVIMReadReceiptMessage *)message {
    NSString *clientId = message.clientId;
    int64_t timestamp = message.timestamp;

    if (!clientId)
        return;
    if (timestamp <= 0)
        return;

    [self updateReadTimestamp:timestamp forClientId:clientId];
}

- (void)fetchReceiptTimestampsInBackgroundSwizzledForGroupChat {
    if (self.members.count <= 2) {
        [self fetchReceiptTimestampsInBackgroundSwizzledForGroupChat];
        return;
    }

    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];

    genericCommand.cmd = AVIMCommandType_Conv;
    genericCommand.op = AVIMOpType_MaxRead;
    genericCommand.peerId = self.imClient.clientId;
    genericCommand.needResponse = YES;

    AVIMConvCommand *convCommand = [[AVIMConvCommand alloc] init];
    convCommand.cid = self.conversationId;
    convCommand.queryAllMembers = YES;

    genericCommand.convMessage = convCommand;

    [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
        if (error)
            return;

        AVIMConvCommand *convCommand = inCommand.convMessage;
        NSArray<AVIMMaxReadTuple*> *maxReadTuples = convCommand.maxReadTuplesArray;

        [self handleMaxReadTuples:maxReadTuples];
    }];

    dispatch_async([AVIMClient imClientQueue], ^{
        [self.imClient sendCommand:genericCommand];
    });
}

- (void)handleMaxReadTuples:(NSArray<AVIMMaxReadTuple*> *)maxReadTuples {
    @synchronized (self) {
        NSMutableArray *clientIds = [NSMutableArray array];

        for (AVIMMaxReadTuple *maxReadTuple in maxReadTuples) {
            NSString *clientId = maxReadTuple.pid;
            self.lastReadTimestamps[clientId] = @(maxReadTuple.maxReadTimestamp);
            [clientIds addObject:clientId];
        }

        [self notifyLastReadTimestampsUpdateForClientIds:clientIds];
    }
}

- (void)updateReadTimestamp:(int64_t)timestamp forClientId:(NSString *)clientId {
    @synchronized (self) {
        self.lastReadTimestamps[clientId] = @(timestamp);
        [self notifyLastReadTimestampsUpdateForClientIds:@[clientId]];
    }
}

- (void)notifyLastReadTimestampsUpdateForClientIds:(NSArray *)clientIds {
    if (!clientIds || !clientIds.count)
        return;

    NSArray *arguments = @[self, clientIds];
    [self callDelegateMethod:@selector(conversation:lastReadTimestampsDidUpdateForClientIds:)
               withArguments:arguments];
}

@end
