//
//  LCIMCommon.m
//  LeanCloudIM
//
//  Created by Qihe Bian on 12/26/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMCommon_Internal.h"

// MARK: Error

NSString * const kLCIMCodeKey       = @"code";
NSString * const kLCIMAppCodeKey    = @"appCode";
NSString * const kLCIMAppMsgKey     = @"appMsg";
NSString * const kLCIMReasonKey     = @"reason";
NSString * const kLCIMDetailKey     = @"detail";

// MARK: Conversation

LCIMConversationUpdatedKey const LCIMConversationUpdatedKeyLastMessage              = @"lastMessage";
LCIMConversationUpdatedKey const LCIMConversationUpdatedKeyLastMessageAt            = @"lastMessageAt";
LCIMConversationUpdatedKey const LCIMConversationUpdatedKeyLastReadAt               = @"lastReadAt";
LCIMConversationUpdatedKey const LCIMConversationUpdatedKeyLastDeliveredAt          = @"lastDeliveredAt";
LCIMConversationUpdatedKey const LCIMConversationUpdatedKeyUnreadMessagesCount      = @"unreadMessagesCount";
LCIMConversationUpdatedKey const LCIMConversationUpdatedKeyUnreadMessagesMentioned  = @"unreadMessagesMentioned";

// MARK: Signature

LCIMSignatureAction const LCIMSignatureActionOpen       = @"open";
LCIMSignatureAction const LCIMSignatureActionStart      = @"start";
LCIMSignatureAction const LCIMSignatureActionAdd        = @"invite";
LCIMSignatureAction const LCIMSignatureActionRemove     = @"kick";
LCIMSignatureAction const LCIMSignatureActionBlock      = @"block";
LCIMSignatureAction const LCIMSignatureActionUnblock    = @"unblock";
