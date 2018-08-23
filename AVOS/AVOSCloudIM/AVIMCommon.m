//
//  AVIMCommon.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/26/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon_Internal.h"

// MARK: - Error

NSString * const kAVIMCodeKey = @"code";
NSString * const kAVIMAppCodeKey = @"appCode";
NSString * const kAVIMReasonKey  = @"reason";
NSString * const kAVIMDetailKey  = @"detail";

// MARK: - Conversation

AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastMessage = @"lastMessage";
AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastMessageAt = @"lastMessageAt";
AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastReadAt = @"lastReadAt";
AVIMConversationUpdatedKey AVIMConversationUpdatedKeyLastDeliveredAt = @"lastDeliveredAt";
AVIMConversationUpdatedKey AVIMConversationUpdatedKeyUnreadMessagesCount = @"unreadMessagesCount";
AVIMConversationUpdatedKey AVIMConversationUpdatedKeyUnreadMessagesMentioned = @"unreadMessagesMentioned";

// MARK: - Signature

AVIMSignatureAction AVIMSignatureActionOpen = @"open";
AVIMSignatureAction AVIMSignatureActionStart = @"start";
AVIMSignatureAction AVIMSignatureActionAdd = @"invite";
AVIMSignatureAction AVIMSignatureActionRemove = @"kick";
AVIMSignatureAction AVIMSignatureActionBlock = @"block";
AVIMSignatureAction AVIMSignatureActionUnblock = @"unblock";

// MARK: - Deprecated

NSString * const AVIMUserOptionUseUnread = @"AVIMUserOptionUseUnread";
NSString * const AVIMUserOptionCustomProtocols = @"AVIMUserOptionCustomProtocols";
