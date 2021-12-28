//
//  LCIMMessage.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMCommon.h"

typedef int32_t LCIMMessageMediaType NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT const LCIMMessageMediaType LCIMMessageMediaTypeNone;
FOUNDATION_EXPORT const LCIMMessageMediaType LCIMMessageMediaTypeText;
FOUNDATION_EXPORT const LCIMMessageMediaType LCIMMessageMediaTypeImage;
FOUNDATION_EXPORT const LCIMMessageMediaType LCIMMessageMediaTypeAudio;
FOUNDATION_EXPORT const LCIMMessageMediaType LCIMMessageMediaTypeVideo;
FOUNDATION_EXPORT const LCIMMessageMediaType LCIMMessageMediaTypeLocation;
FOUNDATION_EXPORT const LCIMMessageMediaType LCIMMessageMediaTypeFile;
FOUNDATION_EXPORT const LCIMMessageMediaType LCIMMessageMediaTypeRecalled;

typedef NS_ENUM(int32_t, kLCIMMessageMediaType) {
    kLCIMMessageMediaTypeNone = 0,
    kLCIMMessageMediaTypeText = -1,
    kLCIMMessageMediaTypeImage = -2,
    kLCIMMessageMediaTypeAudio = -3,
    kLCIMMessageMediaTypeVideo = -4,
    kLCIMMessageMediaTypeLocation = -5,
    kLCIMMessageMediaTypeFile = -6,
    kLCIMMessageMediaTypeRecalled = -127
} __deprecated_enum_msg("Deprecated! please use `LCIMMessageMediaType` instead, this ENUM may be removed in the future.");

typedef NS_ENUM(int8_t, LCIMMessageIOType) {
    LCIMMessageIOTypeIn = 1,
    LCIMMessageIOTypeOut,
};

typedef NS_ENUM(int8_t, LCIMMessageStatus) {
    LCIMMessageStatusNone = 0,
    LCIMMessageStatusSending = 1,
    LCIMMessageStatusSent,
    LCIMMessageStatusDelivered,
    LCIMMessageStatusFailed,
    LCIMMessageStatusRead
};

NS_ASSUME_NONNULL_BEGIN

@interface LCIMMessagePatchedReason : NSObject

@property (nonatomic) NSInteger code;
@property (nonatomic, nullable) NSString *reason;

@end

@interface LCIMMessage : NSObject <NSCopying, NSCoding>

@property (nonatomic, assign, readonly) LCIMMessageMediaType mediaType;

/*!
 * 表示接收和发出的消息
 */
@property (nonatomic, assign, readonly) LCIMMessageIOType ioType;

/*!
 * 表示消息状态
 */
@property (nonatomic, assign, readonly) LCIMMessageStatus status;

/*!
 * 消息 id
 */
@property (nonatomic, strong, readonly, nullable) NSString *messageId;

/*!
 * 消息发送/接收方 id
 */
@property (nonatomic, strong, readonly, nullable) NSString *clientId;

/*!
 * A flag indicates whether this message mentions all members in conversation or not.
 */
@property (nonatomic, assign, readwrite) BOOL mentionAll;

/*!
 * An ID list of clients who mentioned by this message.
 */
@property (nonatomic, strong, readwrite, nullable) NSArray<NSString *> *mentionList;

/*!
 * Whether current client is mentioned by this message.
 */
@property (nonatomic, assign, readonly) BOOL mentioned;

/*!
 * 消息所属对话的 id
 */
@property (nonatomic, strong, readonly, nullable) NSString *conversationId;

/*!
 * 消息文本
 */
@property (nonatomic, strong, readonly, nullable) NSString *content;

/*!
 * 发送时间（精确到毫秒）
 */
@property (nonatomic, assign, readonly) int64_t sendTimestamp;

/*!
 * 接收时间（精确到毫秒）
 */
@property (nonatomic, assign, readonly) int64_t deliveredTimestamp;

/*!
 * 被标记为已读的时间（精确到毫秒）
 */
@property (nonatomic, assign, readonly) int64_t readTimestamp;

/*!
 The message update time.
 */
@property (nonatomic, strong, readonly, nullable) NSDate *updatedAt;

- (NSString * _Nullable)payload;

/*!
 创建文本消息。
 @param content － 消息文本.
 */
+ (instancetype)messageWithContent:(NSString *)content;

@end

NS_ASSUME_NONNULL_END
