//
//  AVIMConversation_Internal.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/12/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMConversation.h"
#import "AVConstants.h"
#import "MessagesProtoOrig.pbobjc.h"

// conversation
static NSString * const kLCIMConv_objectId = @"objectId";
static NSString * const kLCIMConv_uniqueId = @"uniqueId";
static NSString * const kLCIMConv_name = @"name";
static NSString * const kLCIMConv_creator = @"c";
static NSString * const kLCIMConv_createdAt = @"createdAt";
static NSString * const kLCIMConv_updatedAt = @"updatedAt";
static NSString * const kLCIMConv_lastMessageAt = @"lm";
static NSString * const kLCIMConv_attributes = @"attr";
static NSString * const kLCIMConv_members = @"m";
static NSString * const kLCIMConv_mutedMembers = @"mu";
static NSString * const kLCIMConv_unique = @"unique";
static NSString * const kLCIMConv_transient = @"tr";
static NSString * const kLCIMConv_system = @"sys";
static NSString * const kLCIMConv_temporary = @"temp";
static NSString * const kLCIMConv_temporaryTTL = @"ttl";
// message
static NSString * const kLCIMConv_convType = @"conv_type";
static NSString * const kLCIMConv_lastMessage = @"msg";
static NSString * const kLCIMConv_lastMessageId = @"msg_mid";
static NSString * const kLCIMConv_lastMessageFrom = @"msg_from";
static NSString * const kLCIMConv_lastMessageTimestamp = @"msg_timestamp";
static NSString * const kLCIMConv_lastMessagePatchTimestamp = @"patch_timestamp";
static NSString * const kLCIMConv_lastMessageBinary = @"bin";
static NSString * const kLCIMConv_lastMessageMentionAll = @"mention_all";
static NSString * const kLCIMConv_lastMessageMentionPids = @"mention_pids";

/// it's a key. the value from dic, True: 开启未读通知; False: 关闭离线消息推送。
static NSString *const kAVIMUserOptionUseUnread = @"AVIMUserOptionUseUnread";

/* Use this enum to match command's value(`convType`) */
typedef NS_ENUM(NSUInteger, LCIMConvType) {
    LCIMConvTypeNormal = 1,
    LCIMConvTypeTransient = 2,
    LCIMConvTypeSystem = 3,
    LCIMConvTypeTemporary = 4
};

@interface AVIMConversation ()

+ (instancetype)conversationWithRawJSONData:(NSMutableDictionary *)rawJSONData
                                     client:(AVIMClient *)client;

- (void)setRawJSONData:(NSMutableDictionary *)rawJSONData;
- (void)updateRawJSONDataWith:(NSDictionary *)dictionary;
- (NSDictionary *)rawJSONDataCopy LC_WARN_UNUSED_RESULT;

- (void)addMembers:(NSArray<NSString *> *)members;
- (void)removeMembers:(NSArray<NSString *> *)members;

- (AVIMMessage *)process_direct:(AVIMDirectCommand *)directCommand messageId:(NSString *)messageId isTransientMsg:(BOOL)isTransientMsg;
- (AVIMMessage *)process_rcp:(AVIMRcpCommand *)rcpCommand isReadRcp:(BOOL)isReadRcp;
- (NSUInteger)process_unread:(AVIMUnreadTuple *)unreadTuple;
- (AVIMMessage *)process_patch_modified:(AVIMPatchItem *)patchItem;
- (void)process_conv_updated_attr:(NSDictionary *)attr attrModified:(NSDictionary *)attrModified;
- (void)process_member_info_changed:(NSString *)memberId role:(NSString *)role;

@end

@interface AVIMChatRoom ()
@end

@interface AVIMServiceConversation ()
@end

@interface AVIMTemporaryConversation ()
@end
