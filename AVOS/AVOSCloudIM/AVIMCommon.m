//
//  AVIMCommon.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/26/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon_Internal.h"

// MARK: Error

NSString * const kAVIMCodeKey       = @"code";
NSString * const kAVIMAppCodeKey    = @"appCode";
NSString * const kAVIMAppMsgKey     = @"appMsg";
NSString * const kAVIMReasonKey     = @"reason";
NSString * const kAVIMDetailKey     = @"detail";

// MARK: Conversation

AVIMConversationUpdatedKey const AVIMConversationUpdatedKeyLastMessage              = @"lastMessage";
AVIMConversationUpdatedKey const AVIMConversationUpdatedKeyLastMessageAt            = @"lastMessageAt";
AVIMConversationUpdatedKey const AVIMConversationUpdatedKeyLastReadAt               = @"lastReadAt";
AVIMConversationUpdatedKey const AVIMConversationUpdatedKeyLastDeliveredAt          = @"lastDeliveredAt";
AVIMConversationUpdatedKey const AVIMConversationUpdatedKeyUnreadMessagesCount      = @"unreadMessagesCount";
AVIMConversationUpdatedKey const AVIMConversationUpdatedKeyUnreadMessagesMentioned  = @"unreadMessagesMentioned";

// MARK: Signature

AVIMSignatureAction const AVIMSignatureActionOpen       = @"open";
AVIMSignatureAction const AVIMSignatureActionStart      = @"start";
AVIMSignatureAction const AVIMSignatureActionAdd        = @"invite";
AVIMSignatureAction const AVIMSignatureActionRemove     = @"kick";
AVIMSignatureAction const AVIMSignatureActionBlock      = @"block";
AVIMSignatureAction const AVIMSignatureActionUnblock    = @"unblock";

// MARK: Deprecated

NSString * const AVIMUserOptionUseUnread = @"AVIMUserOptionUseUnread";
NSString * const AVIMUserOptionCustomProtocols = @"AVIMUserOptionCustomProtocols";
