//
//  AVIMConversation_Internal.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/12/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMConversation.h"
#import "AVIMCommon_Internal.h"
#import "MessagesProtoOrig.pbobjc.h"

@interface AVIMConversation ()

+ (instancetype)conversationWithRawJSONData:(NSMutableDictionary *)rawJSONData
                                     client:(AVIMClient *)client;

- (void)setRawJSONData:(NSMutableDictionary *)rawJSONData;
- (void)updateRawJSONDataWith:(NSDictionary *)dictionary;
- (NSDictionary *)rawJSONDataCopy LC_WARN_UNUSED_RESULT;

- (void)addMembers:(NSArray<NSString *> *)members;
- (void)removeMembers:(NSArray<NSString *> *)members;

- (AVIMMessage *)process_direct:(AVIMDirectCommand *)directCommand messageId:(NSString *)messageId isTransientMsg:(BOOL)isTransientMsg LC_WARN_UNUSED_RESULT;
- (AVIMMessage *)process_rcp:(AVIMRcpCommand *)rcpCommand isReadRcp:(BOOL)isReadRcp LC_WARN_UNUSED_RESULT;
- (NSInteger)process_unread:(AVIMUnreadTuple *)unreadTuple LC_WARN_UNUSED_RESULT;
- (AVIMMessage *)process_patch_modified:(AVIMPatchItem *)patchItem LC_WARN_UNUSED_RESULT;
- (void)process_conv_updated_attr:(NSDictionary *)attr attrModified:(NSDictionary *)attrModified;
- (void)process_member_info_changed:(NSString *)memberId role:(NSString *)role;

- (void)queryMessagesFromServerBeforeId:(NSString *)messageId
                              timestamp:(int64_t)timestamp
                                  limit:(NSUInteger)limit
                               callback:(void (^)(NSArray<AVIMMessage *> * messages, NSError * error))callback;

- (void)queryMessagesFromServerBeforeId:(NSString *)messageId
                              timestamp:(int64_t)timestamp
                            toMessageId:(NSString *)toMessageId
                            toTimestamp:(int64_t)toTimestamp
                                  limit:(NSUInteger)limit
                               callback:(void (^)(NSArray<AVIMMessage *> * messages, NSError * error))callback;



@end

@interface AVIMChatRoom ()

@end

@interface AVIMServiceConversation ()

@end

@interface AVIMTemporaryConversation ()

@end
