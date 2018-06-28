//
//  AVIMErrorUtil.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/20/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMErrorUtil.h"

NSString *AVIMErrorMessage(AVIMErrorCode code)
{
    switch (code) {
        case AVIMErrorCodeCommandTimeout:
            return @"Web Socket command timeout.";
        case AVIMErrorCodeConnectionLost:
            return @"Web Socket connection lost.";
        case AVIMErrorCodeClientNotOpen:
            return @"IM client not open.";
        case AVIMErrorCodeInvalidCommand:
            return @"Web Socket command received from server is invalid.";
        case AVIMErrorCodeCommandDataLengthTooLong:
            return @"Web socket command data length is too long.";
        case AVIMErrorCodeUpdatingMessageNotAllowed:
            return @"Updating message from others is not allowed.";
        case AVIMErrorCodeUpdatingMessageNotSent:
            return @"Message is not sent.";
        case AVIMErrorCodeOwnerPromotionNotAllowed:
            return @"Updating a member's role to owner is not allowed.";
        default:
            return nil;
    }
}
