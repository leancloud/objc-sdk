//
//  LCIMMessage.m
//  LeanCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMMessage.h"
#import "LCIMMessageObject.h"
#import "LCIMMessage_Internal.h"
#import "LCIMConversation_Internal.h"
#import "LCIMTypedMessage_Internal.h"

/*
 {
 "cmd": "direct",
 "cid": "549bc8a5e4b0606024ec1677",
 "r": false,
 "transient": false,
 "i": 5343,
 "msg": "hello, world",
 "appId": "appid",
 "peerId": "Tom"
 }
 */

@implementation LCIMMessage

+ (instancetype)messageWithContent:(NSString *)content {
    LCIMMessage *message = [[self alloc] init];
    message.content = content;
    return message;
}

- (id)copyWithZone:(NSZone *)zone {
    LCIMMessage *message = [[self class] allocWithZone:zone];
    if (message) {
        message.status = _status;
        message.messageId = _messageId;
        message.clientId = _clientId;
        message.conversationId = _conversationId;
        message.content = _content;
        message.sendTimestamp = _sendTimestamp;
        message.deliveredTimestamp = _deliveredTimestamp;
        message.readTimestamp = _readTimestamp;
    }
    return message;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    LCIMMessageObject *object = [[LCIMMessageObject alloc] init];
    object.ioType = self.ioType;
    object.status = self.status;
    object.messageId = self.messageId;
    object.clientId = self.clientId;
    object.conversationId = self.conversationId;
    object.content = self.content;
    if (self.sendTimestamp != 0) {
        object.sendTimestamp = self.sendTimestamp;
    }
    if (self.deliveredTimestamp != 0) {
        object.deliveredTimestamp = self.deliveredTimestamp;
    }
    if (self.readTimestamp != 0) {
        object.readTimestamp = self.readTimestamp;
    }
    object.updatedAt = self.updatedAt;
    NSData *data = [object messagePack];
    [coder encodeObject:data forKey:@"data"];
    [coder encodeObject:self.localClientId forKey:NSStringFromSelector(@selector(localClientId))];
}

- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [self init])) {
        NSData *data = [coder decodeObjectForKey:@"data"];
        LCIMMessageObject *object = [[LCIMMessageObject alloc] initWithMessagePack:data];
        self.status = object.status;
        self.messageId = object.messageId;
        self.clientId = object.clientId;
        self.conversationId = object.conversationId;
        self.content = object.content;
        self.sendTimestamp = object.sendTimestamp;
        self.deliveredTimestamp = object.deliveredTimestamp;
        self.readTimestamp = object.readTimestamp;
        self.updatedAt = object.updatedAt;
        self.localClientId = [coder decodeObjectForKey:NSStringFromSelector(@selector(localClientId))];
    }
    return self;
}

- (NSString *)payload {
    return self.content;
}

- (LCIMMessageIOType)ioType {
    if (!self.clientId || !self.localClientId) {
        return LCIMMessageIOTypeOut;
    }

    if ([self.clientId isEqualToString:self.localClientId]) {
        return LCIMMessageIOTypeOut;
    } else {
        return LCIMMessageIOTypeIn;
    }
}

- (BOOL)mentioned {
    if (self.ioType == LCIMMessageIOTypeOut)
        return NO;

    if (self.mentionAll || [self.mentionList containsObject:self.localClientId])
        return YES;

    return NO;
}

@end
