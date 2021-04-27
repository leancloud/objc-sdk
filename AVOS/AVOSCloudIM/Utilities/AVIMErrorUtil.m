//
//  AVIMErrorUtil.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/20/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMErrorUtil.h"
#import "LCErrorUtils.h"

NSString *AVIMErrorMessage(LCIMErrorCode code)
{
    switch (code) {
            // 90xx
        case LCIMErrorCodeCommandTimeout:
            return @"Web Socket command timeout.";
        case LCIMErrorCodeConnectionLost:
            return @"Web Socket connection lost.";
        case LCIMErrorCodeClientNotOpen:
            return @"IM client not open.";
        case LCIMErrorCodeInvalidCommand:
            return @"Web Socket command received from server is invalid.";
        case LCIMErrorCodeCommandDataLengthTooLong:
            return @"Web socket command data length is too long.";
            // 91XX
        case LCIMErrorCodeConversationNotFound:
            return @"Conversation not found.";
        case LCIMErrorCodeUpdatingMessageNotAllowed:
            return @"Updating message from others is not allowed.";
        case LCIMErrorCodeUpdatingMessageNotSent:
            return @"Message is not sent.";
        case LCIMErrorCodeOwnerPromotionNotAllowed:
            return @"Updating a member's role to owner is not allowed.";
        default:
            return nil;
    }
}

NSError *LCErrorFromErrorCommand(AVIMErrorCommand *command)
{
    NSError *error;
    if (command) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        if (command.hasAppCode) {
            userInfo[kLCIMAppCodeKey] = @(command.appCode);
        }
        if (command.hasAppMsg) {
            userInfo[kLCIMAppMsgKey] = command.appMsg;
        }
        if (command.hasDetail) {
            userInfo[kLCIMDetailKey] = command.detail;
        }
        error = LCError(command.code,
                        command.hasReason ? command.reason : nil,
                        userInfo);
    }
    return error;
}

NSError *LCErrorFromSessionCommand(AVIMSessionCommand *command)
{
    NSError *error;
    if (command.hasCode) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        if (command.hasDetail) {
            userInfo[kLCIMDetailKey] = command.detail;
        }
        error = LCError(command.code,
                        command.hasReason ? command.reason : nil,
                        userInfo);
    }
    return error;
}

NSError *LCErrorFromAckCommand(AVIMAckCommand *command)
{
    NSError *error;
    if (command.hasCode ||
        command.hasAppCode) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        if (command.hasAppCode) {
            userInfo[kLCIMAppCodeKey] = @(command.appCode);
        }
        if (command.hasAppMsg) {
            userInfo[kLCIMAppMsgKey] = command.appMsg;
        }
        error = LCError(command.code,
                        command.hasReason ? command.reason : nil,
                        userInfo);
    }
    return error;
}
