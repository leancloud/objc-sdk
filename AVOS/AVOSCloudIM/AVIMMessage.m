//
//  AVIMMessage.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMMessage.h"
#import "AVMPMessagePack.h"
#import "AVIMMessageObject.h"
#import "AVIMMessage_Internal.h"
#import "AVIMConversation_Internal.h"
#import "AVIMTypedMessage_Internal.h"

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

@implementation AVIMMessage

+ (instancetype)messageWithContent:(NSString *)content {
    AVIMMessage *message = [[self alloc] init];
    message.content = content;
    return message;
}

- (id)copyWithZone:(NSZone *)zone {
    AVIMMessage *message = [[self class] allocWithZone:zone];
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
    AVIMMessageObject *object = [[AVIMMessageObject alloc] init];
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
        AVIMMessageObject *object = [[AVIMMessageObject alloc] initWithMessagePack:data];
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

- (AVIMMessageIOType)ioType {
    if (!self.clientId || !self.localClientId) {
        return AVIMMessageIOTypeOut;
    }

    if ([self.clientId isEqualToString:self.localClientId]) {
        return AVIMMessageIOTypeOut;
    } else {
        return AVIMMessageIOTypeIn;
    }
}

- (BOOL)mentioned {
    if (self.ioType == AVIMMessageIOTypeOut)
        return NO;

    if (self.mentionAll || [self.mentionList containsObject:self.localClientId])
        return YES;

    return NO;
}

/*!
 * 
 "msg":"{"_lctype":-1,"_lctext":"1620318941"}",
 "msg_from":"a"
 "msg_mid":"2USGXPmbTEWjt9WnNRZpWQ",
 "msg_timestamp":1480325615220,
 */
+ (instancetype)parseMessageWithConversationId:(NSString *)conversationId result:(NSDictionary *)result {
    id messageContent = result[KEY_LAST_MESSAGE];
    if((!messageContent) || (messageContent == [NSNull null])) { return nil; }
    
    NSString *from = result[KEY_LAST_MESSAGE_FROM];
    NSString *content = (NSString *)messageContent;
    NSTimeInterval timestamp = [result[KEY_LAST_MESSAGE_TIMESTAMP] doubleValue];
    NSString *messageId = result[KEY_LAST_MESSAGE_MID];
    
    AVIMMessage *message = nil;
    AVIMTypedMessageObject *messageObject = [[AVIMTypedMessageObject alloc] initWithJSON:content];
    if ([messageObject isValidTypedMessageObject]) {
        message = [AVIMTypedMessage messageWithMessageObject:messageObject];
    } else {
        message = [[AVIMMessage alloc] init];
    }
    message.content = content;
    message.sendTimestamp = timestamp;
    message.conversationId = conversationId;
    message.clientId = from;
    message.messageId = messageId;
    message.status = AVIMMessageStatusDelivered;

    NSNumber *patchTimestamp = result[@"patch_timestamp"];

    if (patchTimestamp)
        message.updatedAt = [NSDate dateWithTimeIntervalSince1970:[patchTimestamp doubleValue] / 1000.0];

    return message;
}

@end
