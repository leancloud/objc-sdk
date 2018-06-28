//
//  AVIMGenericCommand+AVIMMessagesAdditions.m
//  AVOS
//
//  Created by 陈宜龙 on 15/11/18.
//  Copyright © 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVIMGenericCommand+AVIMMessagesAdditions.h"
#import "AVIMCommon.h"
#import "AVIMErrorUtil.h"
#import "AVIMConversationOutCommand.h"
#import <objc/runtime.h>
#import "AVIMMessage.h"
#import "AVErrorUtils.h"

NSString *const kAVIMConversationOperationQuery = @"query";

@implementation AVIMGenericCommand (AVIMMessagesAdditions)

- (AVIMCommandResultBlock)callback {
    return objc_getAssociatedObject(self, @selector(callback));
}

- (void)setCallback:(AVIMCommandResultBlock)callback {
    objc_setAssociatedObject(self, @selector(callback), callback, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)needResponse {
    NSNumber *needResponseObject = objc_getAssociatedObject(self, @selector(needResponse));
    return [needResponseObject boolValue];
}

- (void)setNeedResponse:(BOOL)needResponse {
    NSNumber *needResponseObject = [NSNumber numberWithBool:needResponse];
    objc_setAssociatedObject(self, @selector(needResponse), needResponseObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)avim_addRequiredKeyWithCommand:(LCIMMessage *)command {
    AVIMCommandType commandType = self.cmd;
    switch (commandType) {
            
        case AVIMCommandType_Session:
            self.sessionMessage = (AVIMSessionCommand *)command;
            break;
            
        case AVIMCommandType_Conv:
            self.convMessage = (AVIMConvCommand *)command;
            break;
            
        case AVIMCommandType_Direct:
            self.directMessage = (AVIMDirectCommand *)command;
            break;
            
        case AVIMCommandType_Ack:
            self.ackMessage = (AVIMAckCommand *)command;
            self.needResponse = NO;
            break;
            
        case AVIMCommandType_Rcp:
            self.rcpMessage = (AVIMRcpCommand *)command;
            break;
            
        case AVIMCommandType_Unread:
            self.unreadMessage = (AVIMUnreadCommand *)command;
            break;
            
        case AVIMCommandType_Logs:
            self.logsMessage = (AVIMLogsCommand *)command;
            break;
            
        case AVIMCommandType_Error:
            self.errorMessage = (AVIMErrorCommand *)command;
            break;
            
        case AVIMCommandType_Data:
            self.dataMessage = (AVIMDataCommand *)command;
            break;
            
        case AVIMCommandType_Room:
            self.roomMessage = (AVIMRoomCommand *)command;
            break;
            
        case AVIMCommandType_Read:
            self.readMessage = (AVIMReadCommand *)command;
            break;
            
        case AVIMCommandType_Presence :
            self.presenceMessage = (AVIMPresenceCommand *)command;
            break;
            
        case AVIMCommandType_Report:
            self.reportMessage = (AVIMReportCommand *)command;
            break;
            
        default:
            break;
    }
}

- (void)avim_addRequiredKeyForConvMessageWithSignature:(AVIMSignature *)signature {
    NSAssert(self.hasConvMessage, ([NSString stringWithFormat:@"before call %@, make sure you have called `-avim_addRequiredKey`", NSStringFromSelector(_cmd)]));
    if (signature) {
        self.convMessage.s = signature.signature;
        self.convMessage.t = signature.timestamp;
        self.convMessage.n = signature.nonce;
    }
}

- (void)avim_addRequiredKeyForSessionMessageWithSignature:(AVIMSignature *)signature {
    NSAssert(self.hasSessionMessage, ([NSString stringWithFormat:@"before call %@, make sure you have called `-avim_addRequiredKey`", NSStringFromSelector(_cmd)]));
    if (signature) {
        /* `st` and `s t n` are The mutex relationship, If you want `s t n` there is no need to add `st`. Otherwise, it will case SESSION_TOKEN_EXPIRED error, and this may cause an error whose code is 1001(Stream end encountered), 4108(LOGIN_TIMEOUT) */
        if (self.sessionMessage.hasSt) {
            self.sessionMessage.st = nil;
        }
        self.sessionMessage.s = signature.signature;
        self.sessionMessage.t = signature.timestamp;
        self.sessionMessage.n = signature.nonce;
    }
}

- (void)avim_addRequiredKeyForDirectMessageWithMessage:(AVIMMessage *)message transient:(BOOL)transient {
    NSAssert(self.hasDirectMessage, ([NSString stringWithFormat:@"before call %@, make sure you have called `-avim_addRequiredKey`", NSStringFromSelector(_cmd)]));
    if (message) {
        self.peerId = message.clientId;
        self.directMessage.cid = message.conversationId;
        self.directMessage.msg = message.payload;
        self.directMessage.transient = transient;
        self.directMessage.message = message;
    }
}

- (NSInvocation *)avim_invocation:(SEL)selector target:(id)target {
    NSMethodSignature* signature = [target methodSignatureForSelector:selector];
    //FIXME:Crash
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:target];
    [invocation setSelector:selector];
    return invocation;
}

- (NSArray *)avim_requiredConditions {
    NSMutableArray *requiredKeys = [NSMutableArray array];
    AVIMCommandType commandType = self.cmd;
    switch (commandType) {
            
        case AVIMCommandType_Session:
            [requiredKeys addObjectsFromArray:({
                NSArray *array = @[
                                   [self avim_invocation:@selector(hasCmd) target:self],
                                   [self avim_invocation:@selector(hasOp) target:self],
                                   [self avim_invocation:@selector(hasPeerId) target:self]
                                   ];
                array;
            })];
            
            break;
            
        case AVIMCommandType_Conv:
            //@[@"cmd", @"op", @"peerId"];
            [requiredKeys addObjectsFromArray:({
                NSArray *array = @[
                                   [self avim_invocation:@selector(hasCmd) target:self],
                                   [self avim_invocation:@selector(hasOp) target:self],
                                   [self avim_invocation:@selector(hasPeerId) target:self]
                                   ];
                array;
            })];
            
            if (self.op == AVIMOpType_Add || self.op == AVIMOpType_Remove) {
                [requiredKeys addObjectsFromArray:({
                    NSArray *array = @[
                                       [self avim_invocation:@selector(hasCid) target:self.convMessage],
                                       [self avim_invocation:@selector(mArray_Count) target:self.convMessage],
                                       ];
                    array;
                })];
                
            } else if (self.op == AVIMOpType_Update) {
                [requiredKeys addObjectsFromArray:({
                    NSArray *array = @[
                                       [self avim_invocation:@selector(hasCid) target:self.convMessage],
                                       [self avim_invocation:@selector(hasAttr) target:self.convMessage],
                                       ];
                    array;
                })];
            }
            
            
            break;
            
        case AVIMCommandType_Direct:
            // @[@"cmd", @"peerId", @"cid", @"msg"];
            [requiredKeys addObjectsFromArray:({
                NSArray *array = @[
                                   [self avim_invocation:@selector(hasCmd) target:self],
                                   [self avim_invocation:@selector(hasPeerId) target:self],
                                   [self avim_invocation:@selector(hasCid) target:self.directMessage],
                                   [self avim_invocation:@selector(hasMsg) target:self.directMessage]
                                   ];
                array;
            })];
            break;
            
        case AVIMCommandType_Ack:
            //@[@"cmd", @"peerId", @"cid"];
            [requiredKeys addObjectsFromArray:({
                NSArray *array = @[
                                   [self avim_invocation:@selector(hasCmd) target:self],
                                   [self avim_invocation:@selector(hasPeerId) target:self],
                                   [self avim_invocation:@selector(hasCid) target:self.ackMessage]
                                   ];
                array;
            })];
            
            break;
            
        case AVIMCommandType_Logs:
            //    return @[@"cmd", @"peerId", @"cid"];
            [requiredKeys addObjectsFromArray:({
                NSArray *array = @[
                                   [self avim_invocation:@selector(hasCmd) target:self],
                                   [self avim_invocation:@selector(hasPeerId) target:self],
                                   [self avim_invocation:@selector(hasCid) target:self.logsMessage]
                                   ];
                array;
            })];
            break;
            
            // AVIMCommandType_Rcp = 4,
            // AVIMCommandType_Unread = 5,
            // AVIMCommandType_Logs = 6,
            // AVIMCommandType_Error = 7,
            // AVIMCommandType_Login = 8,
            // AVIMCommandType_Data = 9,
            // AVIMCommandType_Room = 10,
            // AVIMCommandType_Read = 11,
        default:
            break;
    }
    return [requiredKeys copy];
}

- (LCIMMessage *)avim_messageCommand {
    LCIMMessage *result = nil;
    AVIMCommandType commandType = self.cmd;
    switch (commandType) {
            
        case AVIMCommandType_Session:
            result = self.sessionMessage;
            break;
            
        case AVIMCommandType_Conv:
            result = self.convMessage;
            break;
            
        case AVIMCommandType_Direct:
            result = self.directMessage;
            break;
            
        case AVIMCommandType_Ack:
            result = self.ackMessage;
            break;
            
        case AVIMCommandType_Rcp:
            result = self.rcpMessage;
            break;
            
        case AVIMCommandType_Unread:
            result = self.unreadMessage;
            break;
            
        case AVIMCommandType_Logs:
            result = self.logsMessage;
            break;
            
        case AVIMCommandType_Error:
            result = self.errorMessage;
            break;
            
        case AVIMCommandType_Data:
            result = self.dataMessage;
            break;
            
        case AVIMCommandType_Room:
            result = self.roomMessage;
            break;
            
        case AVIMCommandType_Read:
            result = self.readMessage;
            break;
            
        case AVIMCommandType_Presence:
            result = self.presenceMessage;
            break;
            
        case AVIMCommandType_Report:
            result = self.reportMessage;
            break;
            
        default:
            break;
    }
    return result;
}

- (AVIMConversationOutCommand *)avim_conversationForCache {
    AVIMConversationOutCommand *command = [[AVIMConversationOutCommand alloc] init];
    [command setObject:self.peerId forKey:@"peerId"];
    [command setObject:kAVIMConversationOperationQuery forKey:@"op"];

    NSData *data = [self.convMessage.where.data_p dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:NULL];
    [command setObject:[NSMutableDictionary dictionaryWithDictionary:json] forKey:@"where"];
    [command setObject:self.convMessage.sort forKey:@"sort"];
    [command setObject:@(self.convMessage.flag) forKey:@"option"];
    
    if (self.convMessage.hasSkip) {
        [command setObject:@(self.convMessage.skip) forKey:@"skip"];
    }
    [command setObject:@(self.convMessage.limit) forKey:@"limit"];

    //there is no need to add signature for AVIMConversationOutCommand because we won't cache it ,  please go to `- (AVIMGenericCommand *)queryCommand` for more detail
    return command;
}

- (NSString *)avim_messageClass {
    LCIMMessage *command = [self avim_messageCommand];
    Class class = [command class];
    NSString *avim_messageClass = NSStringFromClass(class);
    return avim_messageClass;
}

- (NSString *)avim_description {
    NSString *descriptionString = [self description];
    descriptionString = [descriptionString stringByReplacingOccurrencesOfString:@"\\" withString:@""];
    return descriptionString;
}

@end
