//
//  AVIMConversation_Internal.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/12/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMConversation.h"
#import "MessagesProtoOrig.pbobjc.h"



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
- (NSInteger)process_unread:(AVIMUnreadTuple *)unreadTuple;
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
