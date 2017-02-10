// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: messages.proto.orig

// This CPP symbol can be defined to use imports that match up to the framework
// imports needed when using CocoaPods.
#if !defined(LCIM_USE_PROTOBUF_FRAMEWORK_IMPORTS)
 #define LCIM_USE_PROTOBUF_FRAMEWORK_IMPORTS 0
#endif

#if LCIM_USE_PROTOBUF_FRAMEWORK_IMPORTS
 #import <Protobuf/LCIMProtocolBuffers.h>
#else
#import "LCIMProtocolBuffers.h"
#endif

#if GOOGLE_PROTOBUF_OBJC_VERSION < 30002
#error This file was generated by a newer version of protoc which is incompatible with your Protocol Buffer library sources.
#endif
#if 30002 < GOOGLE_PROTOBUF_OBJC_MIN_SUPPORTED_VERSION
#error This file was generated by an older version of protoc which is incompatible with your Protocol Buffer library sources.
#endif

// @@protoc_insertion_point(imports)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

CF_EXTERN_C_BEGIN

@class AVIMAckCommand;
@class AVIMConvCommand;
@class AVIMDataCommand;
@class AVIMDirectCommand;
@class AVIMErrorCommand;
@class AVIMJsonObjectMessage;
@class AVIMLogItem;
@class AVIMLoginCommand;
@class AVIMLogsCommand;
@class AVIMPresenceCommand;
@class AVIMRcpCommand;
@class AVIMReadCommand;
@class AVIMReadTuple;
@class AVIMReportCommand;
@class AVIMRoomCommand;
@class AVIMSessionCommand;
@class AVIMUnreadCommand;
@class AVIMUnreadTuple;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Enum AVIMCommandType

typedef GPB_ENUM(AVIMCommandType) {
  AVIMCommandType_Session = 0,
  AVIMCommandType_Conv = 1,
  AVIMCommandType_Direct = 2,
  AVIMCommandType_Ack = 3,
  AVIMCommandType_Rcp = 4,
  AVIMCommandType_Unread = 5,
  AVIMCommandType_Logs = 6,
  AVIMCommandType_Error = 7,
  AVIMCommandType_Login = 8,
  AVIMCommandType_Data = 9,
  AVIMCommandType_Room = 10,
  AVIMCommandType_Read = 11,
  AVIMCommandType_Presence = 12,
  AVIMCommandType_Report = 13,
  AVIMCommandType_Echo = 14,
};

LCIMEnumDescriptor *AVIMCommandType_EnumDescriptor(void);

/**
 * Checks to see if the given value is defined by the enum or was not known at
 * the time this source was generated.
 **/
BOOL AVIMCommandType_IsValidValue(int32_t value);

#pragma mark - Enum AVIMOpType

typedef GPB_ENUM(AVIMOpType) {
  /** session */
  AVIMOpType_Open = 1,
  AVIMOpType_Add = 2,
  AVIMOpType_Remove = 3,
  AVIMOpType_Close = 4,
  AVIMOpType_Opened = 5,
  AVIMOpType_Closed = 6,
  AVIMOpType_Query = 7,
  AVIMOpType_QueryResult = 8,
  AVIMOpType_Conflict = 9,
  AVIMOpType_Added = 10,
  AVIMOpType_Removed = 11,

  /** conv */
  AVIMOpType_Start = 30,
  AVIMOpType_Started = 31,
  AVIMOpType_Joined = 32,
  AVIMOpType_MembersJoined = 33,

  /**
   * add = 34; reuse session.add
   * added = 35; reuse session.added
   * remove = 37; reuse session.remove
   * removed = 38; reuse session.removed
   **/
  AVIMOpType_Left = 39,
  AVIMOpType_MembersLeft = 40,

  /**  query = 41; reuse session.query */
  AVIMOpType_Results = 42,
  AVIMOpType_Count = 43,
  AVIMOpType_Result = 44,
  AVIMOpType_Update = 45,
  AVIMOpType_Updated = 46,
  AVIMOpType_Mute = 47,
  AVIMOpType_Unmute = 48,
  AVIMOpType_Status = 49,
  AVIMOpType_Members = 50,
  AVIMOpType_MaxRead = 51,

  /** room */
  AVIMOpType_Join = 80,
  AVIMOpType_Invite = 81,
  AVIMOpType_Leave = 82,
  AVIMOpType_Kick = 83,
  AVIMOpType_Reject = 84,
  AVIMOpType_Invited = 85,

  /**
   *  joined = 32; reuse the value in conv section
   *  left = 39; reuse the value in conv section
   **/
  AVIMOpType_Kicked = 86,

  /** report */
  AVIMOpType_Upload = 100,
  AVIMOpType_Uploaded = 101,
};

LCIMEnumDescriptor *AVIMOpType_EnumDescriptor(void);

/**
 * Checks to see if the given value is defined by the enum or was not known at
 * the time this source was generated.
 **/
BOOL AVIMOpType_IsValidValue(int32_t value);

#pragma mark - Enum AVIMStatusType

typedef GPB_ENUM(AVIMStatusType) {
  AVIMStatusType_On = 1,
  AVIMStatusType_Off = 2,
};

LCIMEnumDescriptor *AVIMStatusType_EnumDescriptor(void);

/**
 * Checks to see if the given value is defined by the enum or was not known at
 * the time this source was generated.
 **/
BOOL AVIMStatusType_IsValidValue(int32_t value);

#pragma mark - AVIMMessagesProtoOrigRoot

/**
 * Exposes the extension registry for this file.
 *
 * The base class provides:
 * @code
 *   + (LCIMExtensionRegistry *)extensionRegistry;
 * @endcode
 * which is a @c LCIMExtensionRegistry that includes all the extensions defined by
 * this file and all files that it depends on.
 **/
@interface AVIMMessagesProtoOrigRoot : LCIMRootObject
@end

#pragma mark - AVIMJsonObjectMessage

typedef GPB_ENUM(AVIMJsonObjectMessage_FieldNumber) {
  AVIMJsonObjectMessage_FieldNumber_Data_p = 1,
};

@interface AVIMJsonObjectMessage : LCIMMessage

@property(nonatomic, readwrite, copy, null_resettable) NSString *data_p;
/** Test to see if @c data_p has been set. */
@property(nonatomic, readwrite) BOOL hasData_p;

@end

#pragma mark - AVIMUnreadTuple

typedef GPB_ENUM(AVIMUnreadTuple_FieldNumber) {
  AVIMUnreadTuple_FieldNumber_Cid = 1,
  AVIMUnreadTuple_FieldNumber_Unread = 2,
  AVIMUnreadTuple_FieldNumber_Mid = 3,
  AVIMUnreadTuple_FieldNumber_Timestamp = 4,
  AVIMUnreadTuple_FieldNumber_From = 5,
  AVIMUnreadTuple_FieldNumber_Data_p = 6,
};

@interface AVIMUnreadTuple : LCIMMessage

@property(nonatomic, readwrite, copy, null_resettable) NSString *cid;
/** Test to see if @c cid has been set. */
@property(nonatomic, readwrite) BOOL hasCid;

@property(nonatomic, readwrite) int32_t unread;

@property(nonatomic, readwrite) BOOL hasUnread;
@property(nonatomic, readwrite, copy, null_resettable) NSString *mid;
/** Test to see if @c mid has been set. */
@property(nonatomic, readwrite) BOOL hasMid;

@property(nonatomic, readwrite) int64_t timestamp;

@property(nonatomic, readwrite) BOOL hasTimestamp;
@property(nonatomic, readwrite, copy, null_resettable) NSString *from;
/** Test to see if @c from has been set. */
@property(nonatomic, readwrite) BOOL hasFrom;

@property(nonatomic, readwrite, copy, null_resettable) NSString *data_p;
/** Test to see if @c data_p has been set. */
@property(nonatomic, readwrite) BOOL hasData_p;

@end

#pragma mark - AVIMLogItem

typedef GPB_ENUM(AVIMLogItem_FieldNumber) {
  AVIMLogItem_FieldNumber_From = 1,
  AVIMLogItem_FieldNumber_Data_p = 2,
  AVIMLogItem_FieldNumber_Timestamp = 3,
  AVIMLogItem_FieldNumber_MsgId = 4,
  AVIMLogItem_FieldNumber_AckAt = 5,
  AVIMLogItem_FieldNumber_ReadAt = 6,
};

@interface AVIMLogItem : LCIMMessage

@property(nonatomic, readwrite, copy, null_resettable) NSString *from;
/** Test to see if @c from has been set. */
@property(nonatomic, readwrite) BOOL hasFrom;

@property(nonatomic, readwrite, copy, null_resettable) NSString *data_p;
/** Test to see if @c data_p has been set. */
@property(nonatomic, readwrite) BOOL hasData_p;

@property(nonatomic, readwrite) int64_t timestamp;

@property(nonatomic, readwrite) BOOL hasTimestamp;
@property(nonatomic, readwrite, copy, null_resettable) NSString *msgId;
/** Test to see if @c msgId has been set. */
@property(nonatomic, readwrite) BOOL hasMsgId;

@property(nonatomic, readwrite) int64_t ackAt;

@property(nonatomic, readwrite) BOOL hasAckAt;
@property(nonatomic, readwrite) int64_t readAt;

@property(nonatomic, readwrite) BOOL hasReadAt;
@end

#pragma mark - AVIMLoginCommand

@interface AVIMLoginCommand : LCIMMessage

@end

#pragma mark - AVIMDataCommand

typedef GPB_ENUM(AVIMDataCommand_FieldNumber) {
  AVIMDataCommand_FieldNumber_IdsArray = 1,
  AVIMDataCommand_FieldNumber_MsgArray = 2,
  AVIMDataCommand_FieldNumber_Offline = 3,
};

@interface AVIMDataCommand : LCIMMessage

@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<NSString*> *idsArray;
/** The number of items in @c idsArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger idsArray_Count;

@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<AVIMJsonObjectMessage*> *msgArray;
/** The number of items in @c msgArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger msgArray_Count;

@property(nonatomic, readwrite) BOOL offline;

@property(nonatomic, readwrite) BOOL hasOffline;
@end

#pragma mark - AVIMSessionCommand

typedef GPB_ENUM(AVIMSessionCommand_FieldNumber) {
  AVIMSessionCommand_FieldNumber_T = 1,
  AVIMSessionCommand_FieldNumber_N = 2,
  AVIMSessionCommand_FieldNumber_S = 3,
  AVIMSessionCommand_FieldNumber_Ua = 4,
  AVIMSessionCommand_FieldNumber_R = 5,
  AVIMSessionCommand_FieldNumber_Tag = 6,
  AVIMSessionCommand_FieldNumber_DeviceId = 7,
  AVIMSessionCommand_FieldNumber_SessionPeerIdsArray = 8,
  AVIMSessionCommand_FieldNumber_OnlineSessionPeerIdsArray = 9,
  AVIMSessionCommand_FieldNumber_St = 10,
  AVIMSessionCommand_FieldNumber_StTtl = 11,
  AVIMSessionCommand_FieldNumber_Code = 12,
  AVIMSessionCommand_FieldNumber_Reason = 13,
  AVIMSessionCommand_FieldNumber_DeviceToken = 14,
  AVIMSessionCommand_FieldNumber_Sp = 15,
  AVIMSessionCommand_FieldNumber_Detail = 16,
  AVIMSessionCommand_FieldNumber_LastUnreadNotifTime = 17,
};

@interface AVIMSessionCommand : LCIMMessage

@property(nonatomic, readwrite) int64_t t;

@property(nonatomic, readwrite) BOOL hasT;
@property(nonatomic, readwrite, copy, null_resettable) NSString *n;
/** Test to see if @c n has been set. */
@property(nonatomic, readwrite) BOOL hasN;

@property(nonatomic, readwrite, copy, null_resettable) NSString *s;
/** Test to see if @c s has been set. */
@property(nonatomic, readwrite) BOOL hasS;

@property(nonatomic, readwrite, copy, null_resettable) NSString *ua;
/** Test to see if @c ua has been set. */
@property(nonatomic, readwrite) BOOL hasUa;

@property(nonatomic, readwrite) BOOL r;

@property(nonatomic, readwrite) BOOL hasR;
@property(nonatomic, readwrite, copy, null_resettable) NSString *tag;
/** Test to see if @c tag has been set. */
@property(nonatomic, readwrite) BOOL hasTag;

@property(nonatomic, readwrite, copy, null_resettable) NSString *deviceId;
/** Test to see if @c deviceId has been set. */
@property(nonatomic, readwrite) BOOL hasDeviceId;

@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<NSString*> *sessionPeerIdsArray;
/** The number of items in @c sessionPeerIdsArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger sessionPeerIdsArray_Count;

@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<NSString*> *onlineSessionPeerIdsArray;
/** The number of items in @c onlineSessionPeerIdsArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger onlineSessionPeerIdsArray_Count;

@property(nonatomic, readwrite, copy, null_resettable) NSString *st;
/** Test to see if @c st has been set. */
@property(nonatomic, readwrite) BOOL hasSt;

@property(nonatomic, readwrite) int32_t stTtl;

@property(nonatomic, readwrite) BOOL hasStTtl;
@property(nonatomic, readwrite) int32_t code;

@property(nonatomic, readwrite) BOOL hasCode;
@property(nonatomic, readwrite, copy, null_resettable) NSString *reason;
/** Test to see if @c reason has been set. */
@property(nonatomic, readwrite) BOOL hasReason;

@property(nonatomic, readwrite, copy, null_resettable) NSString *deviceToken;
/** Test to see if @c deviceToken has been set. */
@property(nonatomic, readwrite) BOOL hasDeviceToken;

@property(nonatomic, readwrite) BOOL sp;

@property(nonatomic, readwrite) BOOL hasSp;
@property(nonatomic, readwrite, copy, null_resettable) NSString *detail;
/** Test to see if @c detail has been set. */
@property(nonatomic, readwrite) BOOL hasDetail;

@property(nonatomic, readwrite) int64_t lastUnreadNotifTime;

@property(nonatomic, readwrite) BOOL hasLastUnreadNotifTime;
@end

#pragma mark - AVIMErrorCommand

typedef GPB_ENUM(AVIMErrorCommand_FieldNumber) {
  AVIMErrorCommand_FieldNumber_Code = 1,
  AVIMErrorCommand_FieldNumber_Reason = 2,
  AVIMErrorCommand_FieldNumber_AppCode = 3,
  AVIMErrorCommand_FieldNumber_Detail = 4,
};

@interface AVIMErrorCommand : LCIMMessage

@property(nonatomic, readwrite) int32_t code;

@property(nonatomic, readwrite) BOOL hasCode;
@property(nonatomic, readwrite, copy, null_resettable) NSString *reason;
/** Test to see if @c reason has been set. */
@property(nonatomic, readwrite) BOOL hasReason;

@property(nonatomic, readwrite) int32_t appCode;

@property(nonatomic, readwrite) BOOL hasAppCode;
@property(nonatomic, readwrite, copy, null_resettable) NSString *detail;
/** Test to see if @c detail has been set. */
@property(nonatomic, readwrite) BOOL hasDetail;

@end

#pragma mark - AVIMDirectCommand

typedef GPB_ENUM(AVIMDirectCommand_FieldNumber) {
  AVIMDirectCommand_FieldNumber_Msg = 1,
  AVIMDirectCommand_FieldNumber_Uid = 2,
  AVIMDirectCommand_FieldNumber_FromPeerId = 3,
  AVIMDirectCommand_FieldNumber_Timestamp = 4,
  AVIMDirectCommand_FieldNumber_Offline = 5,
  AVIMDirectCommand_FieldNumber_HasMore = 6,
  AVIMDirectCommand_FieldNumber_ToPeerIdsArray = 7,
  AVIMDirectCommand_FieldNumber_R = 10,
  AVIMDirectCommand_FieldNumber_Cid = 11,
  AVIMDirectCommand_FieldNumber_Id_p = 12,
  AVIMDirectCommand_FieldNumber_Transient = 13,
  AVIMDirectCommand_FieldNumber_Dt = 14,
  AVIMDirectCommand_FieldNumber_RoomId = 15,
  AVIMDirectCommand_FieldNumber_PushData = 16,
  AVIMDirectCommand_FieldNumber_Will = 17,
};

@interface AVIMDirectCommand : LCIMMessage

@property(nonatomic, readwrite, copy, null_resettable) NSString *msg;
/** Test to see if @c msg has been set. */
@property(nonatomic, readwrite) BOOL hasMsg;

@property(nonatomic, readwrite, copy, null_resettable) NSString *uid;
/** Test to see if @c uid has been set. */
@property(nonatomic, readwrite) BOOL hasUid;

@property(nonatomic, readwrite, copy, null_resettable) NSString *fromPeerId;
/** Test to see if @c fromPeerId has been set. */
@property(nonatomic, readwrite) BOOL hasFromPeerId;

@property(nonatomic, readwrite) int64_t timestamp;

@property(nonatomic, readwrite) BOOL hasTimestamp;
@property(nonatomic, readwrite) BOOL offline;

@property(nonatomic, readwrite) BOOL hasOffline;
@property(nonatomic, readwrite) BOOL hasMore;

@property(nonatomic, readwrite) BOOL hasHasMore;
@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<NSString*> *toPeerIdsArray;
/** The number of items in @c toPeerIdsArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger toPeerIdsArray_Count;

@property(nonatomic, readwrite) BOOL r;

@property(nonatomic, readwrite) BOOL hasR;
@property(nonatomic, readwrite, copy, null_resettable) NSString *cid;
/** Test to see if @c cid has been set. */
@property(nonatomic, readwrite) BOOL hasCid;

@property(nonatomic, readwrite, copy, null_resettable) NSString *id_p;
/** Test to see if @c id_p has been set. */
@property(nonatomic, readwrite) BOOL hasId_p;

@property(nonatomic, readwrite) BOOL transient;

@property(nonatomic, readwrite) BOOL hasTransient;
@property(nonatomic, readwrite, copy, null_resettable) NSString *dt;
/** Test to see if @c dt has been set. */
@property(nonatomic, readwrite) BOOL hasDt;

@property(nonatomic, readwrite, copy, null_resettable) NSString *roomId;
/** Test to see if @c roomId has been set. */
@property(nonatomic, readwrite) BOOL hasRoomId;

@property(nonatomic, readwrite, copy, null_resettable) NSString *pushData;
/** Test to see if @c pushData has been set. */
@property(nonatomic, readwrite) BOOL hasPushData;

@property(nonatomic, readwrite) BOOL will;

@property(nonatomic, readwrite) BOOL hasWill;
@end

#pragma mark - AVIMAckCommand

typedef GPB_ENUM(AVIMAckCommand_FieldNumber) {
  AVIMAckCommand_FieldNumber_Code = 1,
  AVIMAckCommand_FieldNumber_Reason = 2,
  AVIMAckCommand_FieldNumber_Mid = 3,
  AVIMAckCommand_FieldNumber_Cid = 4,
  AVIMAckCommand_FieldNumber_T = 5,
  AVIMAckCommand_FieldNumber_Uid = 6,
  AVIMAckCommand_FieldNumber_Fromts = 7,
  AVIMAckCommand_FieldNumber_Tots = 8,
  AVIMAckCommand_FieldNumber_Type = 9,
  AVIMAckCommand_FieldNumber_IdsArray = 10,
  AVIMAckCommand_FieldNumber_AppCode = 11,
};

@interface AVIMAckCommand : LCIMMessage

@property(nonatomic, readwrite) int32_t code;

@property(nonatomic, readwrite) BOOL hasCode;
@property(nonatomic, readwrite, copy, null_resettable) NSString *reason;
/** Test to see if @c reason has been set. */
@property(nonatomic, readwrite) BOOL hasReason;

@property(nonatomic, readwrite, copy, null_resettable) NSString *mid;
/** Test to see if @c mid has been set. */
@property(nonatomic, readwrite) BOOL hasMid;

@property(nonatomic, readwrite, copy, null_resettable) NSString *cid;
/** Test to see if @c cid has been set. */
@property(nonatomic, readwrite) BOOL hasCid;

@property(nonatomic, readwrite) int64_t t;

@property(nonatomic, readwrite) BOOL hasT;
@property(nonatomic, readwrite, copy, null_resettable) NSString *uid;
/** Test to see if @c uid has been set. */
@property(nonatomic, readwrite) BOOL hasUid;

@property(nonatomic, readwrite) int64_t fromts;

@property(nonatomic, readwrite) BOOL hasFromts;
@property(nonatomic, readwrite) int64_t tots;

@property(nonatomic, readwrite) BOOL hasTots;
@property(nonatomic, readwrite, copy, null_resettable) NSString *type;
/** Test to see if @c type has been set. */
@property(nonatomic, readwrite) BOOL hasType;

@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<NSString*> *idsArray;
/** The number of items in @c idsArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger idsArray_Count;

@property(nonatomic, readwrite) int32_t appCode;

@property(nonatomic, readwrite) BOOL hasAppCode;
@end

#pragma mark - AVIMUnreadCommand

typedef GPB_ENUM(AVIMUnreadCommand_FieldNumber) {
  AVIMUnreadCommand_FieldNumber_ConvsArray = 1,
  AVIMUnreadCommand_FieldNumber_NotifTime = 2,
};

@interface AVIMUnreadCommand : LCIMMessage

@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<AVIMUnreadTuple*> *convsArray;
/** The number of items in @c convsArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger convsArray_Count;

@property(nonatomic, readwrite) int64_t notifTime;

@property(nonatomic, readwrite) BOOL hasNotifTime;
@end

#pragma mark - AVIMConvCommand

typedef GPB_ENUM(AVIMConvCommand_FieldNumber) {
  AVIMConvCommand_FieldNumber_MArray = 1,
  AVIMConvCommand_FieldNumber_Transient = 2,
  AVIMConvCommand_FieldNumber_Unique = 3,
  AVIMConvCommand_FieldNumber_Cid = 4,
  AVIMConvCommand_FieldNumber_Cdate = 5,
  AVIMConvCommand_FieldNumber_InitBy = 6,
  AVIMConvCommand_FieldNumber_Sort = 7,
  AVIMConvCommand_FieldNumber_Limit = 8,
  AVIMConvCommand_FieldNumber_Skip = 9,
  AVIMConvCommand_FieldNumber_Flag = 10,
  AVIMConvCommand_FieldNumber_Count = 11,
  AVIMConvCommand_FieldNumber_Udate = 12,
  AVIMConvCommand_FieldNumber_T = 13,
  AVIMConvCommand_FieldNumber_N = 14,
  AVIMConvCommand_FieldNumber_S = 15,
  AVIMConvCommand_FieldNumber_StatusSub = 16,
  AVIMConvCommand_FieldNumber_StatusPub = 17,
  AVIMConvCommand_FieldNumber_StatusTtl = 18,
  AVIMConvCommand_FieldNumber_TargetClientId = 20,
  AVIMConvCommand_FieldNumber_MaxReadTimestamp = 21,
  AVIMConvCommand_FieldNumber_MaxAckTimestamp = 22,
  AVIMConvCommand_FieldNumber_Results = 100,
  AVIMConvCommand_FieldNumber_Where = 101,
  AVIMConvCommand_FieldNumber_Attr = 103,
};

@interface AVIMConvCommand : LCIMMessage

@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<NSString*> *mArray;
/** The number of items in @c mArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger mArray_Count;

@property(nonatomic, readwrite) BOOL transient;

@property(nonatomic, readwrite) BOOL hasTransient;
@property(nonatomic, readwrite) BOOL unique;

@property(nonatomic, readwrite) BOOL hasUnique;
@property(nonatomic, readwrite, copy, null_resettable) NSString *cid;
/** Test to see if @c cid has been set. */
@property(nonatomic, readwrite) BOOL hasCid;

@property(nonatomic, readwrite, copy, null_resettable) NSString *cdate;
/** Test to see if @c cdate has been set. */
@property(nonatomic, readwrite) BOOL hasCdate;

@property(nonatomic, readwrite, copy, null_resettable) NSString *initBy;
/** Test to see if @c initBy has been set. */
@property(nonatomic, readwrite) BOOL hasInitBy;
- (NSString *)initBy GPB_METHOD_FAMILY_NONE;

@property(nonatomic, readwrite, copy, null_resettable) NSString *sort;
/** Test to see if @c sort has been set. */
@property(nonatomic, readwrite) BOOL hasSort;

@property(nonatomic, readwrite) int32_t limit;

@property(nonatomic, readwrite) BOOL hasLimit;
@property(nonatomic, readwrite) int32_t skip;

@property(nonatomic, readwrite) BOOL hasSkip;
@property(nonatomic, readwrite) int32_t flag;

@property(nonatomic, readwrite) BOOL hasFlag;
@property(nonatomic, readwrite) int32_t count;

@property(nonatomic, readwrite) BOOL hasCount;
@property(nonatomic, readwrite, copy, null_resettable) NSString *udate;
/** Test to see if @c udate has been set. */
@property(nonatomic, readwrite) BOOL hasUdate;

@property(nonatomic, readwrite) int64_t t;

@property(nonatomic, readwrite) BOOL hasT;
@property(nonatomic, readwrite, copy, null_resettable) NSString *n;
/** Test to see if @c n has been set. */
@property(nonatomic, readwrite) BOOL hasN;

@property(nonatomic, readwrite, copy, null_resettable) NSString *s;
/** Test to see if @c s has been set. */
@property(nonatomic, readwrite) BOOL hasS;

@property(nonatomic, readwrite) BOOL statusSub;

@property(nonatomic, readwrite) BOOL hasStatusSub;
@property(nonatomic, readwrite) BOOL statusPub;

@property(nonatomic, readwrite) BOOL hasStatusPub;
@property(nonatomic, readwrite) int32_t statusTtl;

@property(nonatomic, readwrite) BOOL hasStatusTtl;
@property(nonatomic, readwrite, copy, null_resettable) NSString *targetClientId;
/** Test to see if @c targetClientId has been set. */
@property(nonatomic, readwrite) BOOL hasTargetClientId;

@property(nonatomic, readwrite) int64_t maxReadTimestamp;

@property(nonatomic, readwrite) BOOL hasMaxReadTimestamp;
@property(nonatomic, readwrite) int64_t maxAckTimestamp;

@property(nonatomic, readwrite) BOOL hasMaxAckTimestamp;
@property(nonatomic, readwrite, strong, null_resettable) AVIMJsonObjectMessage *results;
/** Test to see if @c results has been set. */
@property(nonatomic, readwrite) BOOL hasResults;

@property(nonatomic, readwrite, strong, null_resettable) AVIMJsonObjectMessage *where;
/** Test to see if @c where has been set. */
@property(nonatomic, readwrite) BOOL hasWhere;

@property(nonatomic, readwrite, strong, null_resettable) AVIMJsonObjectMessage *attr;
/** Test to see if @c attr has been set. */
@property(nonatomic, readwrite) BOOL hasAttr;

@end

#pragma mark - AVIMRoomCommand

typedef GPB_ENUM(AVIMRoomCommand_FieldNumber) {
  AVIMRoomCommand_FieldNumber_RoomId = 1,
  AVIMRoomCommand_FieldNumber_S = 2,
  AVIMRoomCommand_FieldNumber_T = 3,
  AVIMRoomCommand_FieldNumber_N = 4,
  AVIMRoomCommand_FieldNumber_Transient = 5,
  AVIMRoomCommand_FieldNumber_RoomPeerIdsArray = 6,
  AVIMRoomCommand_FieldNumber_ByPeerId = 7,
};

@interface AVIMRoomCommand : LCIMMessage

@property(nonatomic, readwrite, copy, null_resettable) NSString *roomId;
/** Test to see if @c roomId has been set. */
@property(nonatomic, readwrite) BOOL hasRoomId;

@property(nonatomic, readwrite, copy, null_resettable) NSString *s;
/** Test to see if @c s has been set. */
@property(nonatomic, readwrite) BOOL hasS;

@property(nonatomic, readwrite) int64_t t;

@property(nonatomic, readwrite) BOOL hasT;
@property(nonatomic, readwrite, copy, null_resettable) NSString *n;
/** Test to see if @c n has been set. */
@property(nonatomic, readwrite) BOOL hasN;

@property(nonatomic, readwrite) BOOL transient;

@property(nonatomic, readwrite) BOOL hasTransient;
@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<NSString*> *roomPeerIdsArray;
/** The number of items in @c roomPeerIdsArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger roomPeerIdsArray_Count;

@property(nonatomic, readwrite, copy, null_resettable) NSString *byPeerId;
/** Test to see if @c byPeerId has been set. */
@property(nonatomic, readwrite) BOOL hasByPeerId;

@end

#pragma mark - AVIMLogsCommand

typedef GPB_ENUM(AVIMLogsCommand_FieldNumber) {
  AVIMLogsCommand_FieldNumber_Cid = 1,
  AVIMLogsCommand_FieldNumber_L = 2,
  AVIMLogsCommand_FieldNumber_Limit = 3,
  AVIMLogsCommand_FieldNumber_T = 4,
  AVIMLogsCommand_FieldNumber_Tt = 5,
  AVIMLogsCommand_FieldNumber_Tmid = 6,
  AVIMLogsCommand_FieldNumber_Mid = 7,
  AVIMLogsCommand_FieldNumber_Checksum = 8,
  AVIMLogsCommand_FieldNumber_Stored = 9,
  AVIMLogsCommand_FieldNumber_Reversed = 10,
  AVIMLogsCommand_FieldNumber_LogsArray = 105,
};

@interface AVIMLogsCommand : LCIMMessage

@property(nonatomic, readwrite, copy, null_resettable) NSString *cid;
/** Test to see if @c cid has been set. */
@property(nonatomic, readwrite) BOOL hasCid;

@property(nonatomic, readwrite) int32_t l;

@property(nonatomic, readwrite) BOOL hasL;
@property(nonatomic, readwrite) int32_t limit;

@property(nonatomic, readwrite) BOOL hasLimit;
@property(nonatomic, readwrite) int64_t t;

@property(nonatomic, readwrite) BOOL hasT;
@property(nonatomic, readwrite) int64_t tt;

@property(nonatomic, readwrite) BOOL hasTt;
@property(nonatomic, readwrite, copy, null_resettable) NSString *tmid;
/** Test to see if @c tmid has been set. */
@property(nonatomic, readwrite) BOOL hasTmid;

@property(nonatomic, readwrite, copy, null_resettable) NSString *mid;
/** Test to see if @c mid has been set. */
@property(nonatomic, readwrite) BOOL hasMid;

@property(nonatomic, readwrite, copy, null_resettable) NSString *checksum;
/** Test to see if @c checksum has been set. */
@property(nonatomic, readwrite) BOOL hasChecksum;

@property(nonatomic, readwrite) BOOL stored;

@property(nonatomic, readwrite) BOOL hasStored;
@property(nonatomic, readwrite) BOOL reversed;

@property(nonatomic, readwrite) BOOL hasReversed;
@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<AVIMLogItem*> *logsArray;
/** The number of items in @c logsArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger logsArray_Count;

@end

#pragma mark - AVIMRcpCommand

typedef GPB_ENUM(AVIMRcpCommand_FieldNumber) {
  AVIMRcpCommand_FieldNumber_Id_p = 1,
  AVIMRcpCommand_FieldNumber_Cid = 2,
  AVIMRcpCommand_FieldNumber_T = 3,
  AVIMRcpCommand_FieldNumber_Read = 4,
};

@interface AVIMRcpCommand : LCIMMessage

@property(nonatomic, readwrite, copy, null_resettable) NSString *id_p;
/** Test to see if @c id_p has been set. */
@property(nonatomic, readwrite) BOOL hasId_p;

@property(nonatomic, readwrite, copy, null_resettable) NSString *cid;
/** Test to see if @c cid has been set. */
@property(nonatomic, readwrite) BOOL hasCid;

@property(nonatomic, readwrite) int64_t t;

@property(nonatomic, readwrite) BOOL hasT;
@property(nonatomic, readwrite) BOOL read;

@property(nonatomic, readwrite) BOOL hasRead;
@end

#pragma mark - AVIMReadTuple

typedef GPB_ENUM(AVIMReadTuple_FieldNumber) {
  AVIMReadTuple_FieldNumber_Cid = 1,
  AVIMReadTuple_FieldNumber_Timestamp = 2,
  AVIMReadTuple_FieldNumber_Mid = 3,
};

@interface AVIMReadTuple : LCIMMessage

@property(nonatomic, readwrite, copy, null_resettable) NSString *cid;
/** Test to see if @c cid has been set. */
@property(nonatomic, readwrite) BOOL hasCid;

@property(nonatomic, readwrite) int64_t timestamp;

@property(nonatomic, readwrite) BOOL hasTimestamp;
@property(nonatomic, readwrite, copy, null_resettable) NSString *mid;
/** Test to see if @c mid has been set. */
@property(nonatomic, readwrite) BOOL hasMid;

@end

#pragma mark - AVIMReadCommand

typedef GPB_ENUM(AVIMReadCommand_FieldNumber) {
  AVIMReadCommand_FieldNumber_Cid = 1,
  AVIMReadCommand_FieldNumber_CidsArray = 2,
  AVIMReadCommand_FieldNumber_ConvsArray = 3,
};

@interface AVIMReadCommand : LCIMMessage

@property(nonatomic, readwrite, copy, null_resettable) NSString *cid;
/** Test to see if @c cid has been set. */
@property(nonatomic, readwrite) BOOL hasCid;

@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<NSString*> *cidsArray;
/** The number of items in @c cidsArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger cidsArray_Count;

@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<AVIMReadTuple*> *convsArray;
/** The number of items in @c convsArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger convsArray_Count;

@end

#pragma mark - AVIMPresenceCommand

typedef GPB_ENUM(AVIMPresenceCommand_FieldNumber) {
  AVIMPresenceCommand_FieldNumber_Status = 1,
  AVIMPresenceCommand_FieldNumber_SessionPeerIdsArray = 2,
  AVIMPresenceCommand_FieldNumber_Cid = 3,
};

@interface AVIMPresenceCommand : LCIMMessage

@property(nonatomic, readwrite) AVIMStatusType status;

@property(nonatomic, readwrite) BOOL hasStatus;
@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<NSString*> *sessionPeerIdsArray;
/** The number of items in @c sessionPeerIdsArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger sessionPeerIdsArray_Count;

@property(nonatomic, readwrite, copy, null_resettable) NSString *cid;
/** Test to see if @c cid has been set. */
@property(nonatomic, readwrite) BOOL hasCid;

@end

#pragma mark - AVIMReportCommand

typedef GPB_ENUM(AVIMReportCommand_FieldNumber) {
  AVIMReportCommand_FieldNumber_Initiative = 1,
  AVIMReportCommand_FieldNumber_Type = 2,
  AVIMReportCommand_FieldNumber_Data_p = 3,
};

@interface AVIMReportCommand : LCIMMessage

@property(nonatomic, readwrite) BOOL initiative;

@property(nonatomic, readwrite) BOOL hasInitiative;
@property(nonatomic, readwrite, copy, null_resettable) NSString *type;
/** Test to see if @c type has been set. */
@property(nonatomic, readwrite) BOOL hasType;

@property(nonatomic, readwrite, copy, null_resettable) NSString *data_p;
/** Test to see if @c data_p has been set. */
@property(nonatomic, readwrite) BOOL hasData_p;

@end

#pragma mark - AVIMGenericCommand

typedef GPB_ENUM(AVIMGenericCommand_FieldNumber) {
  AVIMGenericCommand_FieldNumber_Cmd = 1,
  AVIMGenericCommand_FieldNumber_Op = 2,
  AVIMGenericCommand_FieldNumber_AppId = 3,
  AVIMGenericCommand_FieldNumber_PeerId = 4,
  AVIMGenericCommand_FieldNumber_I = 5,
  AVIMGenericCommand_FieldNumber_InstallationId = 6,
  AVIMGenericCommand_FieldNumber_Priority = 7,
  AVIMGenericCommand_FieldNumber_LoginMessage = 100,
  AVIMGenericCommand_FieldNumber_DataMessage = 101,
  AVIMGenericCommand_FieldNumber_SessionMessage = 102,
  AVIMGenericCommand_FieldNumber_ErrorMessage = 103,
  AVIMGenericCommand_FieldNumber_DirectMessage = 104,
  AVIMGenericCommand_FieldNumber_AckMessage = 105,
  AVIMGenericCommand_FieldNumber_UnreadMessage = 106,
  AVIMGenericCommand_FieldNumber_ReadMessage = 107,
  AVIMGenericCommand_FieldNumber_RcpMessage = 108,
  AVIMGenericCommand_FieldNumber_LogsMessage = 109,
  AVIMGenericCommand_FieldNumber_ConvMessage = 110,
  AVIMGenericCommand_FieldNumber_RoomMessage = 111,
  AVIMGenericCommand_FieldNumber_PresenceMessage = 112,
  AVIMGenericCommand_FieldNumber_ReportMessage = 113,
};

@interface AVIMGenericCommand : LCIMMessage

@property(nonatomic, readwrite) AVIMCommandType cmd;

@property(nonatomic, readwrite) BOOL hasCmd;
@property(nonatomic, readwrite) AVIMOpType op;

@property(nonatomic, readwrite) BOOL hasOp;
@property(nonatomic, readwrite, copy, null_resettable) NSString *appId;
/** Test to see if @c appId has been set. */
@property(nonatomic, readwrite) BOOL hasAppId;

@property(nonatomic, readwrite, copy, null_resettable) NSString *peerId;
/** Test to see if @c peerId has been set. */
@property(nonatomic, readwrite) BOOL hasPeerId;

@property(nonatomic, readwrite) int32_t i;

@property(nonatomic, readwrite) BOOL hasI;
@property(nonatomic, readwrite, copy, null_resettable) NSString *installationId;
/** Test to see if @c installationId has been set. */
@property(nonatomic, readwrite) BOOL hasInstallationId;

@property(nonatomic, readwrite) int32_t priority;

@property(nonatomic, readwrite) BOOL hasPriority;
@property(nonatomic, readwrite, strong, null_resettable) AVIMLoginCommand *loginMessage;
/** Test to see if @c loginMessage has been set. */
@property(nonatomic, readwrite) BOOL hasLoginMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMDataCommand *dataMessage;
/** Test to see if @c dataMessage has been set. */
@property(nonatomic, readwrite) BOOL hasDataMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMSessionCommand *sessionMessage;
/** Test to see if @c sessionMessage has been set. */
@property(nonatomic, readwrite) BOOL hasSessionMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMErrorCommand *errorMessage;
/** Test to see if @c errorMessage has been set. */
@property(nonatomic, readwrite) BOOL hasErrorMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMDirectCommand *directMessage;
/** Test to see if @c directMessage has been set. */
@property(nonatomic, readwrite) BOOL hasDirectMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMAckCommand *ackMessage;
/** Test to see if @c ackMessage has been set. */
@property(nonatomic, readwrite) BOOL hasAckMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMUnreadCommand *unreadMessage;
/** Test to see if @c unreadMessage has been set. */
@property(nonatomic, readwrite) BOOL hasUnreadMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMReadCommand *readMessage;
/** Test to see if @c readMessage has been set. */
@property(nonatomic, readwrite) BOOL hasReadMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMRcpCommand *rcpMessage;
/** Test to see if @c rcpMessage has been set. */
@property(nonatomic, readwrite) BOOL hasRcpMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMLogsCommand *logsMessage;
/** Test to see if @c logsMessage has been set. */
@property(nonatomic, readwrite) BOOL hasLogsMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMConvCommand *convMessage;
/** Test to see if @c convMessage has been set. */
@property(nonatomic, readwrite) BOOL hasConvMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMRoomCommand *roomMessage;
/** Test to see if @c roomMessage has been set. */
@property(nonatomic, readwrite) BOOL hasRoomMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMPresenceCommand *presenceMessage;
/** Test to see if @c presenceMessage has been set. */
@property(nonatomic, readwrite) BOOL hasPresenceMessage;

@property(nonatomic, readwrite, strong, null_resettable) AVIMReportCommand *reportMessage;
/** Test to see if @c reportMessage has been set. */
@property(nonatomic, readwrite) BOOL hasReportMessage;

@end

NS_ASSUME_NONNULL_END

CF_EXTERN_C_END

#pragma clang diagnostic pop

// @@protoc_insertion_point(global_scope)
