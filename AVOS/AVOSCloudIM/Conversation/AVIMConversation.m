//
//  AVIMConversation.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"
#import "AVIMConversation_Internal.h"
#import "AVIMClient.h"
#import "AVIMClient_Internal.h"
#import "AVIMBlockHelper.h"
#import "AVIMTypedMessage_Internal.h"
#import "AVIMGeneralObject.h"
#import "AVIMConversationQuery.h"
#import "LCIMMessageCache.h"
#import "LCIMMessageCacheStore.h"
#import "AVIMKeyedConversation_internal.h"
#import "AVErrorUtils.h"
#import "AVFile_Internal.h"
#import "AVIMUserOptions.h"
#import "AVIMErrorUtil.h"
#import "LCIMConversationCache.h"
#import "MessagesProtoOrig.pbobjc.h"
#import "AVUtils.h"
#import "AVIMRuntimeHelper.h"
#import "AVIMRecalledMessage.h"
#import "AVObjectUtils.h"
#import "AVPaasClient.h"
#import "AVIMConversationMemberInfo_Internal.h"
#import "AVErrorUtils.h"

@implementation AVIMMessageIntervalBound

- (instancetype)initWithMessageId:(NSString *)messageId
                        timestamp:(int64_t)timestamp
                           closed:(BOOL)closed
{
    self = [super init];

    if (self) {
        _messageId = [messageId copy];
        _timestamp = timestamp;
        _closed = closed;
    }

    return self;
}

@end

@implementation AVIMMessageInterval

- (instancetype)initWithStartIntervalBound:(AVIMMessageIntervalBound *)startIntervalBound
                          endIntervalBound:(AVIMMessageIntervalBound *)endIntervalBound
{
    self = [super init];

    if (self) {
        _startIntervalBound = startIntervalBound;
        _endIntervalBound = endIntervalBound;
    }

    return self;
}

@end

@implementation AVIMOperationFailure

@end

@implementation AVIMConversation {
    
    // public immutable
    __weak AVIMClient *_imClient;
    NSString *_clientId;
    NSString *_conversationId;
    LCIMConvType _convType;
    
    // public mutable
    AVIMMessage *_lastMessage;
    int64_t _lastDeliveredTimestamp;
    int64_t _lastReadTimestamp;
    NSUInteger _unreadMessagesCount;
    BOOL _unreadMessagesMentioned;
    
    // lock
    NSLock *_lock;
    
    // raw data
    NSMutableDictionary *_rawJSONData;
    NSMutableDictionary<NSString *, id> *_pendingData;
    BOOL _isUpdating;
    
    // member info
    NSMutableDictionary<NSString *, AVIMConversationMemberInfo *> *_memberInfoTable;
    
    // message cache for rcp
    NSMutableDictionary<NSString *, AVIMMessage *> *_rcpMessageTable;
}

static dispatch_queue_t messageCacheOperationQueue;

+ (void)initialize
{
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        messageCacheOperationQueue = dispatch_queue_create("leancloud.message-cache-operation-queue", DISPATCH_QUEUE_CONCURRENT);
    });
}

+ (NSUInteger)validLimit:(NSUInteger)limit
{
    if (limit <= 0) { limit = 20; }
    
    BOOL useUnread = [AVIMClient._userOptions[kAVIMUserOptionUseUnread] boolValue];
    
    NSUInteger max = useUnread ? 100 : 1000;
    
    if (limit > max) { limit = max; }
    
    return limit;
}

+ (NSTimeInterval)distantFutureTimestamp
{
    return ([[NSDate distantFuture] timeIntervalSince1970] * 1000);
}

+ (int64_t)validTimestamp:(int64_t)timestamp
{
    if (timestamp <= 0) {
        
        timestamp = (int64_t)[self distantFutureTimestamp];
    }
    
    return timestamp;
}

+ (instancetype)new
{
    [NSException raise:NSInternalInconsistencyException format:@"not allow."];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException format:@"not allow."];
    return nil;
}

// MARK: - Init

+ (instancetype)conversationWithRawJSONData:(NSMutableDictionary *)rawJSONData
                                     client:(AVIMClient *)client
{
    NSString *conversationId = [NSString lc__decodingDictionary:rawJSONData key:kLCIMConv_objectId];
    if (!conversationId || !client) {
        return nil;
    }
    
    AVIMConversation *conv = ({
        LCIMConvType convType = [NSNumber lc__decodingDictionary:rawJSONData key:kLCIMConv_convType].unsignedIntegerValue;
        if (!convType) {
            BOOL transient = [NSNumber lc__decodingDictionary:rawJSONData key:kLCIMConv_transient].boolValue;
            BOOL system = [NSNumber lc__decodingDictionary:rawJSONData key:kLCIMConv_system].boolValue;
            BOOL temporary = [NSNumber lc__decodingDictionary:rawJSONData key:kLCIMConv_temporary].boolValue;
            if (transient && !system && !temporary) {
                convType = LCIMConvTypeTransient;
            } else if (system && !transient && !temporary) {
                convType = LCIMConvTypeSystem;
            } else if (temporary && !transient && !system) {
                convType = LCIMConvTypeTemporary;
            } else {
                convType = LCIMConvTypeNormal;
            }
        }
        AVIMConversation *conv = nil;
        switch (convType)
        {
            case LCIMConvTypeTransient:
            {
                conv = [[AVIMChatRoom alloc] initWithRawJSONData:rawJSONData conversationId:conversationId client:client];
            }break;
            case LCIMConvTypeSystem:
            {
                conv = [[AVIMServiceConversation alloc] initWithRawJSONData:rawJSONData conversationId:conversationId client:client];
            }break;
            case LCIMConvTypeTemporary:
            {
                conv = [[AVIMTemporaryConversation alloc] initWithRawJSONData:rawJSONData conversationId:conversationId client:client];
            }break;
            default:
            {
                conv = [[AVIMConversation alloc] initWithRawJSONData:rawJSONData conversationId:conversationId client:client];
            }break;
        }
        conv->_convType = convType;
        conv;
    });
    return conv;
}

- (instancetype)initWithRawJSONData:(NSMutableDictionary *)rawJSONData
                     conversationId:(NSString *)conversationId
                             client:(AVIMClient *)client
{
    self = [super init];
    
    if (self) {
        
        self->_lock = [[NSLock alloc] init];
        
        self->_imClient = client;
        self->_conversationId = conversationId;
        self->_clientId = client.clientId;
        
        self->_rawJSONData = rawJSONData;
        self->_pendingData = [NSMutableDictionary dictionary];
        self->_isUpdating = false;
        self->_memberInfoTable = nil;
        self->_rcpMessageTable = [NSMutableDictionary dictionary];
        
        self->_lastDeliveredTimestamp = 0;
        self->_lastReadTimestamp = 0;
        self->_unreadMessagesCount = 0;
        self->_unreadMessagesMentioned = false;
        self->_lastMessage = [self decodingLastMessageFromRawJSONData:rawJSONData];
    }
    
    return self;
}

// MARK: - Public Property

- (NSString *)clientId
{
    return self->_clientId;
}

- (NSString *)conversationId
{
    return self->_conversationId;
}

- (AVIMClient *)imClient
{
    return self->_imClient;
}

- (NSString *)creator
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_creator];
    }];
    return value;
}

- (NSDate *)createAt
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_createdAt];
    }];
    return LCDateFromString(value);
}

- (NSDate *)updateAt
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_updatedAt];
    }];
    return LCDateFromString(value);
}

- (NSString *)name
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_name];
    }];
    return value;
}

- (NSArray<NSString *> *)members
{
    __block NSArray *value = nil;
    [self internalSyncLock:^{
        value = [NSArray lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_members].copy;
    }];
    return value;
}

- (void)addMembers:(NSArray<NSString *> *)members
{
    if (!members || members.count == 0) {
        return;
    }
    [self internalSyncLock:^{
        NSArray *originMembers = [NSArray lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_members] ?: @[];
        self->_rawJSONData[kLCIMConv_members] = ({
            NSMutableSet *set = [NSMutableSet setWithArray:originMembers];
            [set addObjectsFromArray:members];
            set.allObjects;
        });
    }];
    [self removeCachedConversation];
}

- (void)removeMembers:(NSArray<NSString *> *)members
{
    if (!members || members.count == 0) {
        return;
    }
    [self internalSyncLock:^{
        NSArray *originMembers = [NSArray lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_members] ?: @[];
        self->_rawJSONData[kLCIMConv_members] = ({
            NSMutableSet *set = [NSMutableSet setWithArray:originMembers];
            for (NSString *memberId in members) {
                [set removeObject:memberId];
            }
            set.allObjects;
        });
    }];
    [self removeCachedConversation];
    if ([members containsObject:self->_clientId]) {
        [self removeCachedMessages];
    }
}

- (BOOL)muted
{
    __block NSArray *value = nil;
    [self internalSyncLock:^{
        value = [NSArray lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_mutedMembers].copy;
    }];
    return value ? [value containsObject:self->_clientId] : false;
}

- (NSDictionary *)attributes
{
    __block NSDictionary *value = nil;
    [self internalSyncLock:^{
        value = [NSDictionary lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_attributes].copy;
    }];
    return value;
}

- (NSString *)uniqueId
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_uniqueId];
    }];
    return value;
}

- (BOOL)unique
{
    __block NSNumber *value = nil;
    [self internalSyncLock:^{
        value = [NSNumber lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_unique];
    }];
    return value.boolValue;
}

- (BOOL)transient
{
    __block NSNumber *value = nil;
    [self internalSyncLock:^{
        value = [NSNumber lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_transient];
    }];
    return value.boolValue;
}

- (BOOL)system
{
    __block NSNumber *value = nil;
    [self internalSyncLock:^{
        value = [NSNumber lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_system];
    }];
    return value.boolValue;
}

- (BOOL)temporary
{
    __block NSNumber *value = nil;
    [self internalSyncLock:^{
        value = [NSNumber lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_temporary];
    }];
    return value.boolValue;
}

- (NSUInteger)temporaryTTL
{
    __block NSNumber *value = nil;
    [self internalSyncLock:^{
        value = [NSNumber lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_temporaryTTL];
    }];
    return value.unsignedIntegerValue;
}

- (AVIMMessage *)lastMessage
{
    __block AVIMMessage *lastMessage = nil;
    [self internalSyncLock:^{
        lastMessage = self->_lastMessage;
    }];
    return lastMessage;
}

- (NSDate *)lastMessageAt
{
    __block int64_t timestamp = 0;
    [self internalSyncLock:^{
        if (self->_lastMessage) {
            timestamp = self->_lastMessage.sendTimestamp;
        }
    }];
    return timestamp ? [NSDate dateWithTimeIntervalSince1970:(timestamp / 1000.0)] : nil;
}

- (BOOL)updateLastMessage:(AVIMMessage *)message client:(AVIMClient *)client
{
    AssertRunInInternalSerialQueue(client);
    __block BOOL updated = false;
    __block BOOL newMessageArrived = false;
    [self internalSyncLock:^{
        AVIMMessage *lastMessage = self->_lastMessage;
        if (!lastMessage) {
            // 1. no lastMessage
            updated = true;
            newMessageArrived = true;
        } else {
            if (lastMessage.sendTimestamp < message.sendTimestamp) {
                // 2. lastMessage date earlier than message
                updated = true;
                newMessageArrived = true;
            } else if (lastMessage.sendTimestamp == message.sendTimestamp) {
                if (![lastMessage.messageId isEqualToString:message.messageId]) {
                    // 3. lastMessage date equal to message but id not equal
                    updated = true;
                    newMessageArrived = true;
                } else {
                    if (!lastMessage.updatedAt && message.updatedAt) {
                        // 4. lastMessage date and id equal to message but message modified.
                        updated = true;
                    } else if (lastMessage.updatedAt && message.updatedAt) {
                        if ([lastMessage.updatedAt compare:message.updatedAt] == NSOrderedAscending) {
                            // 5. lastMessage date and id equal to message but lastMessage modified date earlier than message.
                            updated = true;
                        }
                    } else if (!lastMessage.updatedAt && !message.updatedAt) {
                        // 6. lastMessage date and id equal to message and both no modified.
                        updated = true;
                    }
                }
            }
        }
        if (updated) {
            self->_lastMessage = message;
        }
    }];
    if (updated) {
        [client conversation:self didUpdateForKeys:@[AVIMConversationUpdatedKeyLastMessage, AVIMConversationUpdatedKeyLastMessageAt]];
    }
    return newMessageArrived;
}

- (AVIMMessage *)decodingLastMessageFromRawJSONData:(NSMutableDictionary *)rawJSONData
{
    AVIMMessage *lastMessage = nil;
    NSString *msgContent = [NSString lc__decodingDictionary:rawJSONData key:kLCIMConv_lastMessage];
    NSString *msgId = [NSString lc__decodingDictionary:rawJSONData key:kLCIMConv_lastMessageId];
    NSString *msgFrom = [NSString lc__decodingDictionary:rawJSONData key:kLCIMConv_lastMessageFrom];
    int64_t msgTimestamp = [NSNumber lc__decodingDictionary:rawJSONData key:kLCIMConv_lastMessageTimestamp].longLongValue;
    if (msgContent && msgId && msgFrom && msgTimestamp) {
        AVIMTypedMessageObject *typedMessageObject = [[AVIMTypedMessageObject alloc] initWithJSON:msgContent];
        if (typedMessageObject.isValidTypedMessageObject) {
            lastMessage = [AVIMTypedMessage messageWithMessageObject:typedMessageObject];
        } else {
            lastMessage = [[AVIMMessage alloc] init];
        }
        lastMessage.status = AVIMMessageStatusDelivered;
        lastMessage.conversationId = self->_conversationId;
        lastMessage.content = msgContent;
        lastMessage.messageId = msgId;
        lastMessage.clientId = msgFrom;
        lastMessage.localClientId = self->_clientId;
        lastMessage.sendTimestamp = msgTimestamp;
        lastMessage.updatedAt = ({
            NSNumber *patchTimestamp = [NSNumber lc__decodingDictionary:rawJSONData key:kLCIMConv_lastMessagePatchTimestamp];
            NSDate *date = nil;
            if (patchTimestamp) {
                date = [NSDate dateWithTimeIntervalSince1970:(patchTimestamp.doubleValue / 1000.0)];
            }
            date;
        });
        lastMessage.mentionAll = [NSNumber lc__decodingDictionary:rawJSONData key:kLCIMConv_lastMessageMentionAll].boolValue;
        lastMessage.mentionList = [NSArray lc__decodingDictionary:rawJSONData key:kLCIMConv_lastMessageMentionPids];
    }
    return lastMessage;
}

- (NSDate *)lastDeliveredAt
{
    __block int64_t timestamp = 0;
    [self internalSyncLock:^{
        if (self->_lastDeliveredTimestamp) {
            timestamp = self->_lastDeliveredTimestamp;
        }
    }];
    return timestamp ? [NSDate dateWithTimeIntervalSince1970:(timestamp / 1000.0)] : nil;
}

- (NSDate *)lastReadAt
{
    __block int64_t timestamp = 0;
    [self internalSyncLock:^{
        if (self->_lastReadTimestamp) {
            timestamp = self->_lastReadTimestamp;
        }
    }];
    return timestamp ? [NSDate dateWithTimeIntervalSince1970:(timestamp / 1000.0)] : nil;
}

- (NSUInteger)unreadMessagesCount
{
    __block NSUInteger count = 0;
    [self internalSyncLock:^{
        count = self->_unreadMessagesCount;
    }];
    return count;
}

- (BOOL)unreadMessagesMentioned
{
    return self->_unreadMessagesMentioned;
}

- (void)setUnreadMessagesMentioned:(BOOL)unreadMessagesMentioned
{
    self->_unreadMessagesMentioned = unreadMessagesMentioned;
}

// MARK: - Raw JSON Data

- (NSDictionary *)rawJSONDataCopy
{
    __block NSDictionary *value = nil;
    [self internalSyncLock:^{
        value = self->_rawJSONData.copy;
    }];
    return value;
}

- (NSMutableDictionary *)rawJSONDataMutableCopy
{
    __block NSMutableDictionary *value = nil;
    [self internalSyncLock:^{
        value = self->_rawJSONData.mutableCopy;
    }];
    return value;
}

- (void)setRawJSONData:(NSMutableDictionary *)rawJSONData
{
    __block AVIMMessage *lastMessage = nil;
    [self internalSyncLock:^{
        self->_rawJSONData = rawJSONData;
        lastMessage = [self decodingLastMessageFromRawJSONData:rawJSONData];
    }];
    AVIMClient *client = self->_imClient;
    if (client && lastMessage) {
        [client addOperationToInternalSerialQueue:^(AVIMClient *client) {
            [self updateLastMessage:lastMessage client:client];
        }];
    }
}

- (void)updateRawJSONDataWith:(NSDictionary *)dictionary
{
    [self internalSyncLock:^{
        [self->_rawJSONData addEntriesFromDictionary:dictionary];
    }];
}

// MARK: - Misc

- (void)invokeInUserInteractQueue:(void (^)(void))block
{
    dispatch_queue_t queue = self->_imClient.userInteractQueue;
    if (queue) {
        dispatch_async(queue, ^{
            block();
        });
    }
}

- (void)internalSyncLock:(void (^)(void))block
{
    [self->_lock lock];
    block();
    [self->_lock unlock];
}

- (void)setObject:(id)object forKey:(NSString *)key
{
    [self internalSyncLock:^{
        if (object) {
            self->_pendingData[key] = object;
        } else {
            [self->_pendingData removeObjectForKey:key];
        }
    }];
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)key
{
    [self setObject:object forKey:key];
}

- (id)objectForKey:(NSString *)key
{
    __block id object = nil;
    [self internalSyncLock:^{
        object = self->_rawJSONData[key];
    }];
    return object;
}

- (id)objectForKeyedSubscript:(NSString *)key
{
    return [self objectForKey:key];
}

// MARK: - RCP Timestamps

- (void)fetchReceiptTimestampsInBackground
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_MaxRead;
        outCommand.convMessage = convCommand;
        convCommand.cid = self->_conversationId;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
        int64_t lastDeliveredTimestamp = (convCommand.hasMaxAckTimestamp ? convCommand.maxAckTimestamp : 0);
        int64_t lastReadTimestamp = (convCommand.hasMaxReadTimestamp ? convCommand.maxReadTimestamp : 0);
        
        NSMutableArray<AVIMConversationUpdatedKey> *keys = [NSMutableArray array];
        [self internalSyncLock:^{
            if (lastDeliveredTimestamp > self->_lastDeliveredTimestamp) {
                [keys addObject:AVIMConversationUpdatedKeyLastDeliveredAt];
                self->_lastDeliveredTimestamp = lastDeliveredTimestamp;
            }
            if (lastReadTimestamp > self->_lastReadTimestamp) {
                [keys addObject:AVIMConversationUpdatedKeyLastReadAt];
                self->_lastReadTimestamp = lastReadTimestamp;
            }
        }];
        [client conversation:self didUpdateForKeys:keys];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Members

- (void)joinWithCallback:(void (^)(BOOL, NSError *))callback
{
    [self addMembersWithClientIds:@[self->_clientId] callback:callback];
}

- (void)addMembersWithClientIds:(NSArray<NSString *> *)clientIds
                       callback:(void (^)(BOOL, NSError *))callback;
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(false, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    clientIds = ({
        for (NSString *item in clientIds) {
            if (item.length > kLC_ClientId_MaxLength || item.length == 0) {
                [self invokeInUserInteractQueue:^{
                    callback(false, LCErrorInternal([NSString stringWithFormat:@"client id's length should in range [1 %lu].", kLC_ClientId_MaxLength]));
                }];
                return;
            }
        }
        [NSSet setWithArray:clientIds].allObjects;
    });
    
    [client getSignatureWithConversationId:self->_conversationId action:AVIMSignatureActionAdd actionOnClientIds:clientIds callback:^(AVIMSignature *signature) {
        
        AssertRunInInternalSerialQueue(client);
        
        if (signature && signature.error) {
            [self invokeInUserInteractQueue:^{
                callback(false, signature.error);
            }];
            return;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = ({
            
            AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
            AVIMConvCommand *convCommand = [AVIMConvCommand new];
            
            outCommand.cmd = AVIMCommandType_Conv;
            outCommand.op = AVIMOpType_Add;
            outCommand.convMessage = convCommand;
            
            convCommand.cid = self->_conversationId;
            convCommand.mArray = clientIds.mutableCopy;
            if (signature.signature && signature.timestamp && signature.nonce) {
                convCommand.s = signature.signature;
                convCommand.t = signature.timestamp;
                convCommand.n = signature.nonce;
            }
            
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = outCommand;
            commandWrapper;
        });
        
        [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                [self invokeInUserInteractQueue:^{
                    callback(false, commandWrapper.error);
                }];
                return;
            }
            
            AVIMGenericCommand *inCommand = commandWrapper.inCommand;
            AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
            NSArray<NSString *> *allowedPidsArray = convCommand.allowedPidsArray;
            
            [self addMembers:allowedPidsArray];
            
            [self invokeInUserInteractQueue:^{
                callback(true, nil);
            }];
        }];
        
        [client _sendCommandWrapper:commandWrapper];
    }];
}

- (void)quitWithCallback:(void (^)(BOOL, NSError *))callback
{
    [self removeMembersWithClientIds:@[self->_clientId] callback:callback];
}

- (void)removeMembersWithClientIds:(NSArray<NSString *> *)clientIds
                          callback:(void (^)(BOOL, NSError *))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(false, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    clientIds = ({
        for (NSString *item in clientIds) {
            if (item.length > kLC_ClientId_MaxLength || item.length == 0) {
                [self invokeInUserInteractQueue:^{
                    callback(false, LCErrorInternal([NSString stringWithFormat:@"client id's length should in range [1 %lu].", kLC_ClientId_MaxLength]));
                }];
                return;
            }
        }
        [NSSet setWithArray:clientIds].allObjects;
    });
    
    [client getSignatureWithConversationId:self->_conversationId action:AVIMSignatureActionAdd actionOnClientIds:clientIds callback:^(AVIMSignature *signature) {
        
        AssertRunInInternalSerialQueue(client);
        
        if (signature && signature.error) {
            [self invokeInUserInteractQueue:^{
                callback(false, signature.error);
            }];
            return;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = ({
            
            AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
            AVIMConvCommand *convCommand = [AVIMConvCommand new];
            
            outCommand.cmd = AVIMCommandType_Conv;
            outCommand.op = AVIMOpType_Remove;
            outCommand.convMessage = convCommand;
            
            convCommand.cid = self->_conversationId;
            convCommand.mArray = clientIds.mutableCopy;
            if (signature.signature && signature.timestamp && signature.nonce) {
                convCommand.s = signature.signature;
                convCommand.t = signature.timestamp;
                convCommand.n = signature.nonce;
            }
            
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = outCommand;
            commandWrapper;
        });
        
        [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                [self invokeInUserInteractQueue:^{
                    callback(false, commandWrapper.error);
                }];
                return;
            }
            
            AVIMGenericCommand *inCommand = commandWrapper.inCommand;
            AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
            NSArray<NSString *> *allowedPidsArray = convCommand.allowedPidsArray;
            
            [self removeMembers:allowedPidsArray];
            
            [self invokeInUserInteractQueue:^{
                callback(true, nil);
            }];
        }];
        
        [client _sendCommandWrapper:commandWrapper];
    }];
}

- (void)countMembersWithCallback:(void (^)(NSInteger, NSError *))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(0, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_Count;
        outCommand.convMessage = convCommand;
        convCommand.cid = self->_conversationId;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [self invokeInUserInteractQueue:^{
                callback(0, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
        NSInteger count = (convCommand.hasCount ? convCommand.count : 0);
        
        [self invokeInUserInteractQueue:^{
            callback(count, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Attribute

- (void)fetchWithCallback:(void (^)(BOOL, NSError *))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(false, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    AVIMConversationQuery *query = [client conversationQuery];
    query.cachePolicy = kAVCachePolicyNetworkOnly;
    [query getConversationById:self->_conversationId callback:^(AVIMConversation *conversation, NSError *error) {
#if DEBUG
        if (conversation) {
            assert(conversation == self);
        }
#endif
        callback(error ? false : true, error);
    }];
}

- (void)updateWithCallback:(void (^)(BOOL succeeded, NSError *error))callback
{
    NSDictionary<NSString *, id> *pendingData = ({
        __block NSDictionary<NSString *, id> *pendingData = nil;
        [self internalSyncLock:^{
            pendingData = (self->_isUpdating ? nil : self->_pendingData.copy);
        }];
        if (!pendingData) {
            [self invokeInUserInteractQueue:^{
                callback(false, LCErrorInternal(@"can't update before last update done."));
            }];
            return;
        }
        if (pendingData.count == 0) {
            [self invokeInUserInteractQueue:^{
                callback(true, nil);
            }];
            return;
        }
        pendingData;
    });
    
    [self internalSyncLock:^{
        self->_isUpdating = true;
    }];
    
    [self updateWithDictionary:pendingData callback:^(BOOL succeeded, NSError *error) {
        
        [self internalSyncLock:^{
            self->_isUpdating = false;
        }];
        
        [self invokeInUserInteractQueue:^{
            callback(succeeded, error);
        }];
    }];
}

- (void)updateWithDictionary:(NSDictionary<NSString *, id> *)dictionary
                    callback:(void (^)(BOOL succeeded, NSError *error))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        callback(false, LCErrorInternal(@"imClient invalid."));
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *command = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        AVIMJsonObjectMessage *jsonObjectMessage = [AVIMJsonObjectMessage new];
        
        command.cmd = AVIMCommandType_Conv;
        command.op = AVIMOpType_Update;
        command.convMessage = convCommand;
        
        convCommand.cid = self->_conversationId;
        convCommand.attr = jsonObjectMessage;
        
        jsonObjectMessage.data_p = ({
            NSError *error = nil;
            NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
            if (error) {
                callback(false, error);
                return;
            }
            [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        });
        
        LCIMProtobufCommandWrapper *commandWrapper = [[LCIMProtobufCommandWrapper alloc] init];
        commandWrapper.outCommand = command;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        if (commandWrapper.error) {
            callback(false, commandWrapper.error);
            return;
        }
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
        NSDictionary *modifiedAttr = ({
            AVIMJsonObjectMessage *jsonObjectCommand = (convCommand.hasAttrModified ? convCommand.attrModified : nil);
            NSString *jsonString = (jsonObjectCommand.hasData_p ? jsonObjectCommand.data_p : nil);
            NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
            NSError *error = nil;
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error || ![NSDictionary lc__checkingType:dic]) {
                callback(false, error ?: ({
                    AVIMErrorCode code = AVIMErrorCodeInvalidCommand;
                    LCError(code, AVIMErrorMessage(code), nil);
                }));
                return;
            }
            dic;
        });
        [self internalSyncLock:^{
            process_attr_and_attrModified(dictionary, modifiedAttr, self->_rawJSONData);
            [self->_pendingData removeObjectsForKeys:dictionary.allKeys];
        }];
        [self removeCachedConversation];
        callback(true, nil);
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

static void process_attr_and_attrModified(NSDictionary *attr, NSDictionary *attrModified, NSMutableDictionary *rawJSONData)
{
    if (!attr || !attrModified || !rawJSONData) {
        return;
    }
    for (NSString *originKey in attr.allKeys) {
        // get sub-key array
        NSArray<NSString *> *subKeys = [originKey componentsSeparatedByString:@"."];
        // get modified value
        id modifiedValue = ({
            id modifiedValue = nil;
            NSDictionary *subModifiedAttr = attrModified;
            for (NSInteger i = 0; i < subKeys.count; i++) {
                NSString *subKey = subKeys[i];
                if (i == subKeys.count - 1) {
                    modifiedValue = subModifiedAttr[subKey];
                } else {
                    NSDictionary *dic = subModifiedAttr[subKey];
                    if ([NSDictionary lc__checkingType:dic]) {
                        subModifiedAttr = dic;
                    } else {
                        break;
                    }
                }
            }
            modifiedValue;
        });
        // if modified value exist, update it; if not exist, remove it.
        NSMutableDictionary *subOriginAttr = rawJSONData;
        for (NSInteger i = 0; i < subKeys.count; i++) {
            NSString *subKey = subKeys[i];
            if (i == subKeys.count - 1) {
                if (modifiedValue) {
                    subOriginAttr[subKey] = modifiedValue;
                } else {
                    [subOriginAttr removeObjectForKey:subKey];
                }
            } else {
                // for safe, use deep copy.
                NSMutableDictionary *mutableDic = subOriginAttr[subKey];
                if ([NSDictionary lc__checkingType:mutableDic]) {
                    mutableDic = mutableDic.mutableCopy;
                } else {
                    if (modifiedValue) {
                        mutableDic = [NSMutableDictionary dictionary];
                    } else {
                        break;
                    }
                }
                subOriginAttr[subKey] = mutableDic;
                subOriginAttr = mutableDic;
            }
        }
    }
}

// MARK: - Mute

- (void)muteWithCallback:(void (^)(BOOL, NSError *))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(false, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_Mute;
        outCommand.convMessage = convCommand;
        convCommand.cid = self->_conversationId;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [self invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error);
            }];
            return;
        }
        
        [self internalSyncLock:^{
            NSArray *mutedMembers = [NSArray lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_mutedMembers] ?: @[];
            NSMutableSet *mutableSet = [NSMutableSet setWithArray:mutedMembers];
            [mutableSet addObject:self->_clientId];
            self->_rawJSONData[kLCIMConv_mutedMembers] = mutableSet.allObjects;
        }];
        [self removeCachedConversation];
        
        [self invokeInUserInteractQueue:^{
            callback(true, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

- (void)unmuteWithCallback:(void (^)(BOOL, NSError *))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(false, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_Unmute;
        outCommand.convMessage = convCommand;
        convCommand.cid = self->_conversationId;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [self invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error);
            }];
            return;
        }
        
        [self internalSyncLock:^{
            NSArray *mutedMembers = [NSArray lc__decodingDictionary:self->_rawJSONData key:kLCIMConv_mutedMembers] ?: @[];
            NSMutableSet *mutableSet = [NSMutableSet setWithArray:mutedMembers];
            [mutableSet removeObject:self->_clientId];
            self->_rawJSONData[kLCIMConv_mutedMembers] = mutableSet.allObjects;
        }];
        [self removeCachedConversation];
        
        [self invokeInUserInteractQueue:^{
            callback(true, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Message Read

- (void)readInBackground
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        return;
    }
    
    NSString *messageId = nil;
    int64_t timestamp = 0;
    
    __block AVIMMessage *lastMessage = nil;
    [self internalSyncLock:^{
        lastMessage = self->_lastMessage;
    }];
    
    if (lastMessage) {
        messageId = lastMessage.messageId;
        timestamp = lastMessage.sendTimestamp;
    } else {
        return;
    }
    
    [self internalSyncLock:^{
        self->_unreadMessagesCount = 0;
    }];
    [client addOperationToInternalSerialQueue:^(AVIMClient *client) {
        [client conversation:self didUpdateForKeys:@[AVIMConversationUpdatedKeyUnreadMessagesCount]];
    }];
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMReadCommand *readCommand = [AVIMReadCommand new];
        AVIMReadTuple *readTuple = [AVIMReadTuple new];
        
        outCommand.cmd = AVIMCommandType_Read;
        outCommand.readMessage = readCommand;
        
        readCommand.convsArray = [NSMutableArray arrayWithObject:readTuple];
        readTuple.cid = self->_conversationId;
        if (messageId) {
            readTuple.mid = messageId;
        }
        readTuple.timestamp = timestamp;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Message Send

- (void)sendMessage:(AVIMMessage *)message
           callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self sendMessage:message option:nil progressBlock:nil callback:callback];
}

- (void)sendMessage:(AVIMMessage *)message
             option:(AVIMMessageOption *)option
           callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self sendMessage:message option:option progressBlock:nil callback:callback];
}

- (void)sendMessage:(AVIMMessage *)message
      progressBlock:(void (^)(NSInteger))progressBlock
           callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self sendMessage:message option:nil progressBlock:progressBlock callback:callback];
}

- (void)sendMessage:(AVIMMessage *)message
             option:(AVIMMessageOption *)option
      progressBlock:(void (^)(NSInteger))progressBlock
           callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(false, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    if (client.status != AVIMClientStatusOpened) {
        [self invokeInUserInteractQueue:^{
            callback(false, ({
                AVIMErrorCode code = AVIMErrorCodeClientNotOpen;
                LCError(code, AVIMErrorMessage(code), nil);
            }));
        }];
        return;
    }
    
    message.clientId = self->_clientId;
    message.localClientId = self->_clientId;
    message.conversationId = self->_conversationId;
    message.status = AVIMMessageStatusSending;
    
    if ([message isKindOfClass:[AVIMTypedMessage class]]) {
        AVIMTypedMessage *typedMessage = (AVIMTypedMessage *)message;
        AVFile *file = typedMessage.file;
        if (file) {
            [file uploadWithProgress:progressBlock completionHandler:^(BOOL succeeded, NSError * _Nullable error) {
                if (error) {
                    message.status = AVIMMessageStatusFailed;
                    [self invokeInUserInteractQueue:^{
                        callback(false, error);
                    }];
                    return;
                }
                /* If uploading is success, bind file to message */
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self fillTypedMessage:typedMessage withFile:file];
                    [self fillTypedMessageForLocationIfNeeded:typedMessage];
                    [self sendRealMessage:message option:option callback:callback];
                });
            }];
        } else {
            [self fillTypedMessageForLocationIfNeeded:typedMessage];
            [self sendRealMessage:message option:option callback:callback];
        }
    } else {
        [self sendRealMessage:message option:option callback:callback];
    }
}

- (void)fillTypedMessage:(AVIMTypedMessage *)typedMessage withFile:(AVFile *)file
{
    typedMessage.file = file;
    AVIMGeneralObject *object = [[AVIMGeneralObject alloc] init];
    object.url = file.url;
    object.objId = file.objectId;
    switch (typedMessage.mediaType) {
        case kAVIMMessageMediaTypeImage:
        {
            id image = nil;
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH
            image = ({
                UIImage *image = nil;
                NSString *cachedPath = file.persistentCachePath;
                if ([[NSFileManager defaultManager] fileExistsAtPath:cachedPath]) {
                    NSData *data = [NSData dataWithContentsOfFile:cachedPath];
                    image = [UIImage imageWithData:data];
                }
                image;
            });
#else
            image = ({
                NSImage *image = nil;
                NSString *cachedPath = file.persistentCachePath;
                if ([[NSFileManager defaultManager] fileExistsAtPath:cachedPath]) {
                    NSData *data = [NSData dataWithContentsOfFile:cachedPath];
                    image = [[NSImage alloc] initWithData:data];
                }
                image;
            });
#endif
            if (!image) { break; }
            CGFloat width;
            CGFloat height;
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH
            width = [(UIImage *)image size].width;
            height = [(UIImage *)image size].height;
#else
            width = [(NSImage *)image size].width;
            height = [(NSImage *)image size].height;
#endif
            AVIMGeneralObject *metaData = [[AVIMGeneralObject alloc] init];
            metaData.height = height;
            metaData.width = width;
            metaData.size = file.size;
            metaData.format = [file.name pathExtension];
            [file setMetaData:[metaData dictionary].copy];
            object.metaData = metaData;
            typedMessage.messageObject._lcfile = [object dictionary];
        }
            break;
        case kAVIMMessageMediaTypeAudio:
        case kAVIMMessageMediaTypeVideo: {
            NSString *path = file.persistentCachePath;
            /* If audio file not found, no meta data */
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                break;
            }
            NSURL *fileURL = [NSURL fileURLWithPath:path];
            AVURLAsset* audioAsset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
            CMTime audioDuration = audioAsset.duration;
            float audioDurationSeconds = CMTimeGetSeconds(audioDuration);
            AVIMGeneralObject *metaData = [[AVIMGeneralObject alloc] init];
            metaData.duration = audioDurationSeconds;
            metaData.size = file.size;
            metaData.format = [file.name pathExtension];
            file.metaData = [[metaData dictionary] mutableCopy];
            object.metaData = metaData;
            typedMessage.messageObject._lcfile = [object dictionary];
        }
            break;
        case kAVIMMessageMediaTypeFile:
        default: {
            /* 文件消息或扩展的文件消息 */
            object.name = file.name;
            /* Compatibility with IM protocol */
            object.size = file.size;
            /* Compatibility with AVFile implementation, see [AVFile size] method */
            AVIMGeneralObject *metaData = [[AVIMGeneralObject alloc] init];
            metaData.size = file.size;
            object.metaData = metaData;
            typedMessage.messageObject._lcfile = [object dictionary];
        }
            break;
    }
}

- (void)fillTypedMessageForLocationIfNeeded:(AVIMTypedMessage *)typedMessage
{
    AVGeoPoint *location = typedMessage.location;
    if (location) {
        AVIMGeneralObject *object = [[AVIMGeneralObject alloc] init];
        object.latitude = location.latitude;
        object.longitude = location.longitude;
        typedMessage.messageObject._lcloc = [object dictionary];
    }
}

- (void)sendRealMessage:(AVIMMessage *)message
                 option:(AVIMMessageOption *)option
               callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(false, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    BOOL transientConv = (self->_convType == LCIMConvTypeTransient);
    BOOL transientMsg = option.transient;
    BOOL receipt = option.receipt;
    BOOL will = option.will;
    AVIMMessagePriority priority = option.priority;
    NSDictionary *pushData = option.pushData;
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMDirectCommand *directCommand = [AVIMDirectCommand new];
        
        outCommand.cmd = AVIMCommandType_Direct;
        outCommand.directMessage = directCommand;
        if (transientConv && priority) {
            outCommand.priority = priority;
        }
        
        directCommand.cid = self->_conversationId;
        directCommand.msg = message.payload;
        if (message.mentionAll) {
            directCommand.mentionAll = message.mentionAll;
        }
        if (message.mentionList.count > 0) {
            directCommand.mentionPidsArray = message.mentionList.mutableCopy;
        }
        if (transientMsg) {
            directCommand.transient = transientMsg;
        }
        if (will) {
            directCommand.will = will;
        }
        if (receipt) {
            directCommand.r = receipt;
        }
        if (pushData && !transientConv && !transientMsg) {
            NSError *error = nil;
            NSData *data = [NSJSONSerialization dataWithJSONObject:pushData options:0 error:&error];
            if (error) {
                [self invokeInUserInteractQueue:^{
                    callback(false, error);
                }];
                return;
            }
            directCommand.pushData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            message.status = AVIMMessageStatusFailed;
            [self invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMAckCommand *ackCommand = (inCommand.hasAckMessage ? inCommand.ackMessage : nil);
        message.sendTimestamp = (ackCommand.hasT ? ackCommand.t : 0);
        message.messageId = (ackCommand.hasUid ? ackCommand.uid : nil);
        message.transient = (transientConv || transientMsg);
        message.status = AVIMMessageStatusSent;
        if (receipt && message.messageId) {
            [self internalSyncLock:^{
                self->_rcpMessageTable[message.messageId] = message;
            }];
        }
        
        if (!transientConv && !transientMsg && !will) {
            [self updateLastMessage:message client:client];
            if (client.messageQueryCacheEnabled) {
                LCIMMessageCacheStore *messageCacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:self->_clientId conversationId:self->_conversationId];
                [messageCacheStore insertOrUpdateMessage:message withBreakpoint:NO];
            }
        }
        
        [self invokeInUserInteractQueue:^{
            callback(true, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Message Patch

- (void)updateMessage:(AVIMMessage *)oldMessage
         toNewMessage:(AVIMMessage *)newMessage
             callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(false, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    if (!oldMessage.messageId ||
        !oldMessage.sendTimestamp ||
        ![oldMessage.conversationId isEqualToString:self->_conversationId] ||
        ![oldMessage.clientId isEqualToString:self->_clientId]) {
        [self invokeInUserInteractQueue:^{
            callback(false, LCErrorInternal(@"oldMessage invalid."));
        }];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMPatchCommand *patchCommand = [AVIMPatchCommand new];
        AVIMPatchItem *patchItem = [AVIMPatchItem new];
        
        outCommand.cmd = AVIMCommandType_Patch;
        outCommand.op = AVIMOpType_Modify;
        outCommand.patchMessage = patchCommand;
        
        patchCommand.patchesArray = [NSMutableArray arrayWithObject:patchItem];
        patchItem.cid = oldMessage.conversationId;
        patchItem.mid = oldMessage.messageId;
        patchItem.timestamp = oldMessage.sendTimestamp;
        
        patchItem.data_p = newMessage.payload;
        patchItem.mentionAll = newMessage.mentionAll;
        patchItem.mentionPidsArray = newMessage.mentionList.mutableCopy;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [self invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMPatchCommand *patchCommand = (inCommand.hasPatchMessage ? inCommand.patchMessage : nil);
        
        newMessage.messageId = oldMessage.messageId;
        newMessage.clientId = oldMessage.clientId;
        newMessage.localClientId = oldMessage.localClientId;
        newMessage.conversationId = oldMessage.conversationId;
        newMessage.sendTimestamp = oldMessage.sendTimestamp;
        newMessage.readTimestamp = oldMessage.readTimestamp;
        newMessage.deliveredTimestamp = oldMessage.deliveredTimestamp;
        newMessage.offline = oldMessage.offline;
        newMessage.hasMore = oldMessage.hasMore;
        newMessage.status = oldMessage.status;
        if (patchCommand.hasLastPatchTime) {
            newMessage.updatedAt = [NSDate dateWithTimeIntervalSince1970:patchCommand.lastPatchTime / 1000.0];
        }
        
        [self updateLastMessage:newMessage client:client];
        if (client.messageQueryCacheEnabled) {
            LCIMMessageCacheStore *messageCacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:self->_clientId conversationId:self->_conversationId];
            [messageCacheStore insertOrUpdateMessage:newMessage withBreakpoint:NO];
        }
        
        [self invokeInUserInteractQueue:^{
            callback(true, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

- (void)recallMessage:(AVIMMessage *)oldMessage
             callback:(void (^)(BOOL, NSError * _Nullable, AVIMRecalledMessage * _Nullable))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(false, LCErrorInternal(@"imClient invalid."), nil);
        }];
        return;
    }
    
    if (!oldMessage.messageId ||
        !oldMessage.sendTimestamp ||
        ![oldMessage.conversationId isEqualToString:self->_conversationId] ||
        ![oldMessage.clientId isEqualToString:self->_clientId]) {
        [self invokeInUserInteractQueue:^{
            callback(false, LCErrorInternal(@"oldMessage invalid."), nil);
        }];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMPatchCommand *patchCommand = [AVIMPatchCommand new];
        AVIMPatchItem *patchItem = [AVIMPatchItem new];
        
        outCommand.cmd = AVIMCommandType_Patch;
        outCommand.op = AVIMOpType_Modify;
        outCommand.patchMessage = patchCommand;
        
        patchCommand.patchesArray = [NSMutableArray arrayWithObject:patchItem];
        patchItem.cid = oldMessage.conversationId;
        patchItem.mid = oldMessage.messageId;
        patchItem.timestamp = oldMessage.sendTimestamp;
        patchItem.recall = true;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [self invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error, nil);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMPatchCommand *patchCommand = (inCommand.hasPatchMessage ? inCommand.patchMessage : nil);
        
        AVIMRecalledMessage *recalledMessage = [[AVIMRecalledMessage alloc] init];
        recalledMessage.messageId = oldMessage.messageId;
        recalledMessage.clientId = oldMessage.clientId;
        recalledMessage.localClientId = oldMessage.localClientId;
        recalledMessage.conversationId = oldMessage.conversationId;
        recalledMessage.sendTimestamp = oldMessage.sendTimestamp;
        recalledMessage.readTimestamp = oldMessage.readTimestamp;
        recalledMessage.deliveredTimestamp = oldMessage.deliveredTimestamp;
        recalledMessage.offline = oldMessage.offline;
        recalledMessage.hasMore = oldMessage.hasMore;
        recalledMessage.status = oldMessage.status;
        if (patchCommand.hasLastPatchTime) {
            recalledMessage.updatedAt = [NSDate dateWithTimeIntervalSince1970:patchCommand.lastPatchTime / 1000.0];
        }

        [self updateLastMessage:recalledMessage client:client];
        if (client.messageQueryCacheEnabled) {
            LCIMMessageCacheStore *messageCacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:self->_clientId conversationId:self->_conversationId];
            [messageCacheStore insertOrUpdateMessage:recalledMessage withBreakpoint:NO];
        }
        
        [self invokeInUserInteractQueue:^{
            callback(true, nil, recalledMessage);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

#pragma mark -

- (NSArray *)takeContinuousMessages:(NSArray *)messages
{
    NSMutableArray *continuousMessages = [NSMutableArray array];
    
    for (AVIMMessage *message in messages.reverseObjectEnumerator) {
        
        if (message.breakpoint) {
            
            break;
        }
        
        [continuousMessages insertObject:message atIndex:0];
    }
    
    return continuousMessages;
}

- (LCIMMessageCache *)messageCache {
    NSString *clientId = self.clientId;

    return clientId ? [LCIMMessageCache cacheWithClientId:clientId] : nil;
}

- (LCIMMessageCacheStore *)messageCacheStore {
    NSString *clientId = self.clientId;
    NSString *conversationId = self.conversationId;

    return clientId && conversationId ? [[LCIMMessageCacheStore alloc] initWithClientId:clientId conversationId:conversationId] : nil;
}

- (LCIMConversationCache *)conversationCache {
    return self->_imClient.conversationCache;
}

- (void)cacheContinuousMessages:(NSArray *)messages
                    plusMessage:(AVIMMessage *)message
{
    NSMutableArray *cachedMessages = [NSMutableArray array];
    
    if (messages) { [cachedMessages addObjectsFromArray:messages]; }
    
    if (message) { [cachedMessages addObject:message]; }
    
    [self cacheContinuousMessages:cachedMessages withBreakpoint:YES];
}

- (void)cacheContinuousMessages:(NSArray *)messages withBreakpoint:(BOOL)breakpoint {
    if (breakpoint) {
        [[self messageCache] addContinuousMessages:messages forConversationId:self.conversationId];
    } else {
        [[self messageCacheStore] insertOrUpdateMessages:messages];
    }
}

- (void)removeCachedConversation
{
    [[self conversationCache] removeConversationForId:self.conversationId];
}

- (void)removeCachedMessages
{
    [[self messageCacheStore] cleanCache];
}

- (void)addMessageToCache:(AVIMMessage *)message {
    message.clientId = self->_imClient.clientId;
    message.conversationId = _conversationId;

    [[self messageCacheStore] insertOrUpdateMessage:message];
}

- (void)removeMessageFromCache:(AVIMMessage *)message {
    [[self messageCacheStore] deleteMessage:message];
}

#pragma mark - Message Query

- (void)sendACKIfNeeded:(NSArray *)messages
{
    AVIMClient *client = self->_imClient;
    
    if (!client) {
        
        return;
    }
    
    NSDictionary *userOptions = [AVIMClient _userOptions];
    
    BOOL useUnread = [userOptions[kAVIMUserOptionUseUnread] boolValue];
    
    if (useUnread) {
        
        AVIMAckCommand *ackCommand = [[AVIMAckCommand alloc] init];
        
        ackCommand.cid = self.conversationId;
        
        int64_t fromts = [[messages firstObject] sendTimestamp];
        int64_t tots   = [[messages lastObject] sendTimestamp];
        
        ackCommand.fromts = MIN(fromts, tots);
        ackCommand.tots   = MAX(fromts, tots);
        
        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
        
        genericCommand.cmd = AVIMCommandType_Ack;
        genericCommand.ackMessage = ackCommand;
        
        dispatch_async(client.internalSerialQueue, ^{
            
            [client sendCommand:genericCommand];
        });
    }
}

- (void)queryMessagesFromServerWithCommand:(AVIMGenericCommand *)genericCommand
                                  callback:(AVIMArrayResultBlock)callback
{
    AVIMClient *client = self->_imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                LCErrorInternal(reason);
            });
            
            callback(nil, aError);
        });
        
        return;
    }
    
    AVIMLogsCommand *logsOutCommand = genericCommand.logsMessage;
    dispatch_async(client.internalSerialQueue, ^{
        [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
            
            [client addOperationToInternalSerialQueue:^(AVIMClient *client) {
                
                if (!error) {
                    AVIMLogsCommand *logsInCommand = inCommand.logsMessage;
                    AVIMLogsCommand *logsOutCommand = outCommand.logsMessage;
                    NSArray *logs = [logsInCommand.logsArray copy];
                    NSMutableArray *messages = [[NSMutableArray alloc] init];
                    for (AVIMLogItem *logsItem in logs) {
                        AVIMMessage *message = nil;
                        id data = [logsItem data_p];
                        if (![data isKindOfClass:[NSString class]]) {
                            AVLoggerError(AVLoggerDomainIM, @"Received an invalid message.");
                            continue;
                        }
                        AVIMTypedMessageObject *messageObject = [[AVIMTypedMessageObject alloc] initWithJSON:data];
                        if ([messageObject isValidTypedMessageObject]) {
                            AVIMTypedMessage *m = [AVIMTypedMessage messageWithMessageObject:messageObject];
                            message = m;
                        } else {
                            AVIMMessage *m = [[AVIMMessage alloc] init];
                            m.content = data;
                            message = m;
                        }
                        message.conversationId = logsOutCommand.cid;
                        message.sendTimestamp = [logsItem timestamp];
                        message.clientId = [logsItem from];
                        message.messageId = [logsItem msgId];
                        message.mentionAll = logsItem.mentionAll;
                        message.mentionList = [logsItem.mentionPidsArray copy];
                        
                        if (logsItem.hasPatchTimestamp)
                            message.updatedAt = [NSDate dateWithTimeIntervalSince1970:(logsItem.patchTimestamp / 1000.0)];
                        
                        [messages addObject:message];
                    }
                    
                    if (messages.firstObject) {
                        [self updateLastMessage:messages.firstObject client:client];
                    }
                    
                    [self postprocessMessages:messages];
                    [self sendACKIfNeeded:messages];
                    
                    [AVIMBlockHelper callArrayResultBlock:callback array:messages error:nil];
                } else {
                    [AVIMBlockHelper callArrayResultBlock:callback array:nil error:error];
                }
            }];
        }];
        [genericCommand avim_addRequiredKeyWithCommand:logsOutCommand];
        [client sendCommand:genericCommand];
    });
}

- (void)queryMessagesFromServerBeforeId:(NSString *)messageId
                              timestamp:(int64_t)timestamp
                                  limit:(NSUInteger)limit
                               callback:(AVIMArrayResultBlock)callback
{
    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
    genericCommand.needResponse = YES;
    genericCommand.cmd = AVIMCommandType_Logs;
    genericCommand.peerId = self->_imClient.clientId;
    
    AVIMLogsCommand *logsCommand = [[AVIMLogsCommand alloc] init];
    logsCommand.cid    = _conversationId;
    logsCommand.mid    = messageId;
    logsCommand.t      = [self.class validTimestamp:timestamp];
    logsCommand.l      = (int32_t)[self.class validLimit:limit];
    
    [genericCommand avim_addRequiredKeyWithCommand:logsCommand];
    [self queryMessagesFromServerWithCommand:genericCommand callback:callback];
}

- (void)queryMessagesFromServerBeforeId:(NSString *)messageId
                              timestamp:(int64_t)timestamp
                            toMessageId:(NSString *)toMessageId
                            toTimestamp:(int64_t)toTimestamp
                                  limit:(NSUInteger)limit
                               callback:(AVIMArrayResultBlock)callback
{
    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
    AVIMLogsCommand *logsCommand = [[AVIMLogsCommand alloc] init];
    genericCommand.needResponse = YES;
    genericCommand.cmd = AVIMCommandType_Logs;
    genericCommand.peerId = self->_imClient.clientId;
    logsCommand.cid    = _conversationId;
    logsCommand.mid    = messageId;
    logsCommand.tmid   = toMessageId;
    logsCommand.tt     = MAX(toTimestamp, 0);
    logsCommand.t      = MAX(timestamp, 0);
    logsCommand.l      = (int32_t)[self.class validLimit:limit];
    [genericCommand avim_addRequiredKeyWithCommand:logsCommand];
    [self queryMessagesFromServerWithCommand:genericCommand callback:callback];
}

- (void)queryMessagesFromServerWithLimit:(NSUInteger)limit
                                callback:(void (^)(NSArray<AVIMMessage *> *, NSError *))callback
{
    limit = [self.class validLimit:limit];
    
    int64_t timestamp = (int64_t)[self.class distantFutureTimestamp];
    
    [self queryMessagesFromServerBeforeId:nil
                                timestamp:timestamp
                                    limit:limit
                                 callback:^(NSArray *messages, NSError *error)
     {
         if (error) {
             
             [AVIMBlockHelper callArrayResultBlock:callback
                                             array:nil
                                             error:error];
             
             return;
         }
         
         if (!self->_imClient.messageQueryCacheEnabled) {
             
             [AVIMBlockHelper callArrayResultBlock:callback
                                             array:messages
                                             error:nil];
             
             return;
         }
         
         dispatch_async(messageCacheOperationQueue, ^{
             
             [self cacheContinuousMessages:messages
                            withBreakpoint:YES];
             
             [AVIMBlockHelper callArrayResultBlock:callback
                                             array:messages
                                             error:nil];
         });
     }];
}

- (NSArray *)queryMessagesFromCacheWithLimit:(NSUInteger)limit
{
    limit = [self.class validLimit:limit];
    NSArray *cachedMessages = [[self messageCacheStore] latestMessagesWithLimit:limit];
    [self postprocessMessages:cachedMessages];
    
    return cachedMessages;
}

- (void)queryMessagesWithLimit:(NSUInteger)limit
                      callback:(void (^)(NSArray<AVIMMessage *> *, NSError *))callback
{
    limit = [self.class validLimit:limit];
    
    BOOL socketOpened = (self->_imClient.status == AVIMClientStatusOpened);
    
    /* if disable query from cache, then only query from server. */
    if (!self->_imClient.messageQueryCacheEnabled) {
        
        /* connection is not open, callback error. */
        if (!socketOpened) {
            
            NSError *error = ({
                AVIMErrorCode code = AVIMErrorCodeClientNotOpen;
                LCError(code, AVIMErrorMessage(code), nil);
            });
            
            [AVIMBlockHelper callArrayResultBlock:callback
                                            array:nil
                                            error:error];
            
            return;
        }
        
        [self queryMessagesFromServerWithLimit:limit
                                      callback:callback];
        
        return;
    }
    
    /* connection is not open, query messages from cache */
    if (!socketOpened) {
        
        NSArray *messages = [self queryMessagesFromCacheWithLimit:limit];
        
        [AVIMBlockHelper callArrayResultBlock:callback
                                        array:messages
                                        error:nil];
        
        return;
    }
    
    int64_t timestamp = (int64_t)[self.class distantFutureTimestamp];
    
    /* query recent message from server. */
    [self queryMessagesFromServerBeforeId:nil
                                timestamp:timestamp
                              toMessageId:nil
                              toTimestamp:0
                                    limit:limit
                                 callback:^(NSArray *messages, NSError *error)
     {
         if (error) {
             
             /* If network has an error, fallback to query from cache */
             if ([error.domain isEqualToString:NSURLErrorDomain]) {
                 
                 NSArray *messages = [self queryMessagesFromCacheWithLimit:limit];
                 
                 [AVIMBlockHelper callArrayResultBlock:callback
                                                 array:messages
                                                 error:nil];
                 
                 return;
             }
             
             /* If error is not network relevant, return it */
             [AVIMBlockHelper callArrayResultBlock:callback
                                             array:nil
                                             error:error];
             
             return;
         }

         dispatch_async(messageCacheOperationQueue, ^{
             
             [self cacheContinuousMessages:messages
                            withBreakpoint:YES];
             
             NSArray *messages = [self queryMessagesFromCacheWithLimit:limit];
             
             [AVIMBlockHelper callArrayResultBlock:callback
                                             array:messages
                                             error:nil];
         });
     }];
}

- (void)queryMessagesBeforeId:(NSString *)messageId
                    timestamp:(int64_t)timestamp
                        limit:(NSUInteger)limit
                     callback:(void (^)(NSArray<AVIMMessage *> *, NSError *))callback
{
    if (messageId == nil) {
        
        NSString *reason = @"`messageId` can't be nil";
        
        [AVIMBlockHelper callArrayResultBlock:callback
                                        array:nil
                                        error:LCErrorInternal(reason)];
        
        return;
    }
    
    limit     = [self.class validLimit:limit];
    timestamp = [self.class validTimestamp:timestamp];

    /*
     * Firstly, if message query cache is not enabled, just forward query request.
     */
    if (!self->_imClient.messageQueryCacheEnabled) {
        
        [self queryMessagesFromServerBeforeId:messageId
                                    timestamp:timestamp
                                        limit:limit
                                     callback:^(NSArray *messages, NSError *error)
         {
             [AVIMBlockHelper callArrayResultBlock:callback
                                             array:messages
                                             error:error];
         }];
        
        return;
    }

    /*
     * Secondly, if message query cache is enabled, fetch message from cache.
     */
    dispatch_async(messageCacheOperationQueue, ^{
        
        LCIMMessageCacheStore *cacheStore = self.messageCacheStore;
        
        AVIMMessage *fromMessage = [cacheStore getMessageById:messageId
                                                    timestamp:timestamp];
        
        void (^queryMessageFromServerBefore_block)(void) = ^ {
            
            [self queryMessagesFromServerBeforeId:messageId
                                        timestamp:timestamp
                                            limit:limit
                                         callback:^(NSArray *messages, NSError *error)
             {
                 dispatch_async(messageCacheOperationQueue, ^{
                     
                     [self cacheContinuousMessages:messages
                                       plusMessage:fromMessage];
                     
                     [AVIMBlockHelper callArrayResultBlock:callback
                                                     array:messages
                                                     error:error];
                 });
             }];
        };
        
        if (fromMessage) {
            
            [self postprocessMessages:@[fromMessage]];
            
            if (fromMessage.breakpoint) {
                
                queryMessageFromServerBefore_block();
                
                return;
            }
        }
        
        BOOL continuous = YES;
        
        LCIMMessageCache *cache = [self messageCache];
        
        /* `cachedMessages` is timestamp or messageId ascending order */
        NSArray *cachedMessages = [cache messagesBeforeTimestamp:timestamp
                                                       messageId:messageId
                                                  conversationId:self.conversationId
                                                           limit:limit
                                                      continuous:&continuous];
        
        [self postprocessMessages:cachedMessages];
        
        /*
         * If message is continuous or socket connect is not opened, return fetched messages directly.
         */
        BOOL socketOpened = (self->_imClient.status == AVIMClientStatusOpened);
        
        if ((continuous && cachedMessages.count == limit) ||
            !socketOpened) {
            
            [AVIMBlockHelper callArrayResultBlock:callback
                                            array:cachedMessages
                                            error:nil];
            
            return;
        }
        
        /*
         * If cached messages exist, only fetch the rest uncontinuous messages.
         */
        if (cachedMessages.count > 0) {
            
            /* `continuousMessages` is timestamp or messageId ascending order */
            NSArray *continuousMessages = [self takeContinuousMessages:cachedMessages];
            
            BOOL hasContinuous = continuousMessages.count > 0;
            
            /*
             * Then, fetch rest of messages from remote server.
             */
            NSUInteger restCount = 0;
            AVIMMessage *startMessage = nil;
            
            if (hasContinuous) {
                
                restCount = limit - continuousMessages.count;
                startMessage = continuousMessages.firstObject;
                
            } else {
                
                restCount = limit;
                AVIMMessage *last = cachedMessages.lastObject;
                startMessage = [cache nextMessageForMessage:last
                                             conversationId:self.conversationId];
            }
            
            /*
             * If start message not nil, query messages before it.
             */
            if (startMessage) {
                
                [self queryMessagesFromServerBeforeId:startMessage.messageId
                                            timestamp:startMessage.sendTimestamp
                                                limit:restCount
                                             callback:^(NSArray *messages, NSError *error)
                 {
                     if (error) {
                         AVLoggerError(AVLoggerDomainIM, @"Error: %@", error);
                     }
                     
                     NSMutableArray *fetchedMessages;
                     
                     if (messages) {
                         
                         fetchedMessages = [NSMutableArray arrayWithArray:messages];
                         
                     } else {
                         
                         fetchedMessages = @[].mutableCopy;
                     }
                     
                     
                     if (hasContinuous) {
                         [fetchedMessages addObjectsFromArray:continuousMessages];
                     }
                     
                     dispatch_async(messageCacheOperationQueue, ^{
                         
                         [self cacheContinuousMessages:fetchedMessages
                                           plusMessage:fromMessage];
                         
                         NSArray *messages = [cacheStore messagesBeforeTimestamp:timestamp
                                                                       messageId:messageId
                                                                           limit:limit];
                         
                         [AVIMBlockHelper callArrayResultBlock:callback
                                                         array:messages
                                                         error:nil];
                     });
                 }];
                
                return;
            }
        }
        
        /*
         * Otherwise, just forward query request.
         */
        queryMessageFromServerBefore_block();
    });
}

- (void)queryMessagesInInterval:(AVIMMessageInterval *)interval
                      direction:(AVIMMessageQueryDirection)direction
                          limit:(NSUInteger)limit
                       callback:(void (^)(NSArray<AVIMMessage *> *, NSError *))callback
{
    AVIMLogsCommand *logsCommand = [[AVIMLogsCommand alloc] init];

    logsCommand.cid  = _conversationId;
    logsCommand.l    = (int32_t)[self.class validLimit:limit];

    logsCommand.direction = (direction == AVIMMessageQueryDirectionFromOldToNew)
        ? AVIMLogsCommand_QueryDirection_New
        : AVIMLogsCommand_QueryDirection_Old;

    AVIMMessageIntervalBound *startIntervalBound = interval.startIntervalBound;
    AVIMMessageIntervalBound *endIntervalBound = interval.endIntervalBound;

    logsCommand.mid  = startIntervalBound.messageId;
    logsCommand.tmid = endIntervalBound.messageId;

    logsCommand.tIncluded = startIntervalBound.closed;
    logsCommand.ttIncluded = endIntervalBound.closed;

    int64_t t = startIntervalBound.timestamp;
    int64_t tt = endIntervalBound.timestamp;

    if (t > 0)
        logsCommand.t = t;
    if (tt > 0)
        logsCommand.tt = tt;

    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
    genericCommand.needResponse = YES;
    genericCommand.cmd = AVIMCommandType_Logs;
    genericCommand.peerId = self->_imClient.clientId;
    genericCommand.logsMessage = logsCommand;

    [self queryMessagesFromServerWithCommand:genericCommand callback:callback];
}

- (void)postprocessMessages:(NSArray *)messages {
    for (AVIMMessage *message in messages) {
        message.status = AVIMMessageStatusSent;
        message.localClientId = self->_imClient.clientId;
    }
}

- (void)queryMediaMessagesFromServerWithType:(AVIMMessageMediaType)type
                                       limit:(NSUInteger)limit
                               fromMessageId:(NSString *)messageId
                               fromTimestamp:(int64_t)timestamp
                                    callback:(void (^)(NSArray<AVIMMessage *> *, NSError *))callback
{
    AVIMClient *client = self->_imClient;
    
    NSString *convId = self.conversationId;
    
    NSString *errReason = nil;
    
    if (!convId) {
        
        errReason = @"`conversationId` is invalid.";
        
    } else if (!client) {
        
        errReason = @"`imClient` is invalid.";;
    }
    
    if (errReason) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            callback(nil, LCErrorInternal(errReason));
        });
        
        return;
    }
    
    AVIMLogsCommand *logsCommand = [[AVIMLogsCommand alloc] init];
    
    logsCommand.cid = convId;
    
    logsCommand.lctype = type;
    
    logsCommand.l = (int32_t)[self.class validLimit:limit];
    
    if (messageId) {
        
        logsCommand.mid = messageId;
    }
    
    logsCommand.t = [self.class validTimestamp:timestamp];
    
    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
    
    genericCommand.cmd = AVIMCommandType_Logs;
    genericCommand.logsMessage = logsCommand;
    
    [genericCommand setNeedResponse:true];
    
    __weak typeof(self) weakSelf = self;
    
    [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error){
        
        dispatch_async(client.internalSerialQueue, ^{
            
            AVIMConversation *strongSelf = weakSelf;
            
            if (!strongSelf) { return; }
            
            if (error) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    callback(nil, error);
                });
                
                return;
            }
           
            AVIMLogsCommand *logsInCommand = inCommand.logsMessage;
            AVIMLogsCommand *logsOutCommand = outCommand.logsMessage;
            
            NSMutableArray *messageArray = [[NSMutableArray alloc] init];
            
            NSEnumerator *reverseLogsArray = logsInCommand.logsArray.reverseObjectEnumerator;
            
            for (AVIMLogItem *logsItem in reverseLogsArray) {
                
                AVIMMessage *message = nil;
                
                id data = [logsItem data_p];
                
                if (![data isKindOfClass:[NSString class]]) {
                    
                    AVLoggerError(AVLoggerDomainIM, @"Received an invalid message.");
                    
                    continue;
                }
                
                AVIMTypedMessageObject *messageObject = [[AVIMTypedMessageObject alloc] initWithJSON:data];
                
                if ([messageObject isValidTypedMessageObject]) {
                    
                    AVIMTypedMessage *m = [AVIMTypedMessage messageWithMessageObject:messageObject];
                    
                    message = m;
                    
                } else {
                    
                    AVIMMessage *m = [[AVIMMessage alloc] init];
                    
                    m.content = data;
                    
                    message = m;
                }
                
                message.clientId = logsItem.from;
                message.conversationId = logsOutCommand.cid;
                
                message.messageId = logsItem.msgId;
                message.sendTimestamp = logsItem.timestamp;
                
                message.mentionAll = logsItem.mentionAll;
                message.mentionList = logsItem.mentionPidsArray;
                
                if (logsItem.hasPatchTimestamp) {
                    
                    message.updatedAt = [NSDate dateWithTimeIntervalSince1970:(logsItem.patchTimestamp / 1000.0)];
                }
                
                message.status = AVIMMessageStatusSent;
                message.localClientId = client.clientId;
                
                [messageArray addObject:message];
            }
            
            [strongSelf sendACKIfNeeded:messageArray];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(messageArray, nil);
            });
        });
    }];
    
    dispatch_async(client.internalSerialQueue, ^{
        
        [client sendCommand:genericCommand];
    });
}

// MARK: - Member Info

- (void)getAllMemberInfoWithCallback:(void (^)(NSArray<AVIMConversationMemberInfo *> *, NSError *))callback
{
    [self getAllMemberInfoWithIgnoringCache:false
               forcingRefreshIMSessionToken:false
                             recursionCount:0
                                   callback:callback];
}

- (void)getAllMemberInfoWithIgnoringCache:(BOOL)ignoringCache
                                 callback:(void (^)(NSArray<AVIMConversationMemberInfo *> *, NSError *))callback
{
    [self getAllMemberInfoWithIgnoringCache:ignoringCache
               forcingRefreshIMSessionToken:false
                             recursionCount:0
                                   callback:callback];
}

- (void)getAllMemberInfoWithIgnoringCache:(BOOL)ignoringCache
             forcingRefreshIMSessionToken:(BOOL)forcingRefreshIMSessionToken
                           recursionCount:(NSUInteger)recursionCount
                                 callback:(void (^)(NSArray<AVIMConversationMemberInfo *> *, NSError *))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(nil, LCErrorInternal(@"client invalid."));
        }];
        return;
    }
    
    if (!ignoringCache) {
        __block NSArray<AVIMConversationMemberInfo *> *memberInfos = nil;
        [self internalSyncLock:^{
            if (self->_memberInfoTable) {
                memberInfos = self->_memberInfoTable.allValues;
            }
        }];
        if (memberInfos) {
            [self invokeInUserInteractQueue:^{
                callback(memberInfos, nil);
            }];
            return;
        }
    }
    
    [client getSessionTokenWithForcingRefresh:forcingRefreshIMSessionToken callback:^(NSString *sessionToken, NSError *error) {
        
        AssertRunInInternalSerialQueue(client);
        NSParameterAssert(sessionToken);
        
        if (error) {
            [self invokeInUserInteractQueue:^{
                callback(nil, error);
            }];
            return;
        }
        
        AVPaasClient *paasClient = AVPaasClient.sharedInstance;
        NSURLRequest *request = ({
            NSString *whereString = ({
                NSError *error = nil;
                NSData *data = [NSJSONSerialization dataWithJSONObject:@{ @"cid" : self->_conversationId } options:0 error:&error];
                if (error) {
                    [self invokeInUserInteractQueue:^{
                        callback(nil, error);
                    }];
                    return;
                }
                [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            });
            [paasClient requestWithPath:@"classes/_ConversationMemberInfo"
                                 method:@"GET"
                                headers:@{ @"X-LC-IM-Session-Token" : sessionToken }
                             parameters:@{ @"client_id": self->_clientId, @"where": whereString }];
        });
        [paasClient performRequest:request success:^(NSHTTPURLResponse *response, id responseObject) {
            if (![NSDictionary lc__checkingType:responseObject]) {
                [self invokeInUserInteractQueue:^{
                    callback(nil, LCErrorInternal(@"response invalid."));
                }];
                return;
            }
            NSArray *memberInfoDatas = [NSArray lc__decodingDictionary:responseObject key:@"results"];
            if (!memberInfoDatas) {
                [self invokeInUserInteractQueue:^{
                    callback(nil, LCErrorInternal(@"response invalid."));
                }];
                return;
            }
            NSMutableDictionary<NSString *, AVIMConversationMemberInfo *> *memberInfoTable = ({
                NSMutableDictionary<NSString *, AVIMConversationMemberInfo *> *memberInfoTable = [NSMutableDictionary dictionary];
                for (NSDictionary *dic in memberInfoDatas) {
                    if ([NSDictionary lc__checkingType:dic]) {
                        AVIMConversationMemberInfo *memberInfo = [[AVIMConversationMemberInfo alloc] initWithRawJSONData:dic.mutableCopy conversation:self];
                        NSString *memberId = memberInfo.memberId;
                        if (memberId) {
                            memberInfoTable[memberId] = memberInfo;
                        }
                    }
                }
                NSString *creator = self.creator;
                if (!memberInfoTable[creator]) {
                    NSMutableDictionary<NSString *, NSString *> *mutableDic = [NSMutableDictionary dictionary];
                    mutableDic[kAVIMConversationMemberInfoKey_conversationId] = self->_conversationId;
                    mutableDic[kAVIMConversationMemberInfoKey_memberId_1] = creator;
                    mutableDic[kAVIMConversationMemberInfoKey_role] = kAVIMConversationMemberRoleOwner;
                    memberInfoTable[creator] = [[AVIMConversationMemberInfo alloc] initWithRawJSONData:mutableDic conversation:self];
                }
                memberInfoTable;
            });
            NSArray<AVIMConversationMemberInfo *> *memberInfos = memberInfoTable.allValues;
            [self internalSyncLock:^{
                self->_memberInfoTable = memberInfoTable;
            }];
            [self invokeInUserInteractQueue:^{
                callback(memberInfos, nil);
            }];
        } failure:^(NSHTTPURLResponse *response, id responseObject, NSError *error) {
            if ([NSDictionary lc__checkingType:responseObject] &&
                [responseObject[@"code"] integerValue] == kLC_Code_SessionTokenExpired &&
                recursionCount < 3) {
                [self getAllMemberInfoWithIgnoringCache:ignoringCache
                           forcingRefreshIMSessionToken:true
                                         recursionCount:(recursionCount + 1)
                                               callback:callback];
            } else {
                [self invokeInUserInteractQueue:^{
                    callback(nil, error);
                }];
            }
        }];
    }];
}

- (void)getMemberInfoWithMemberId:(NSString *)memberId
                         callback:(void (^)(AVIMConversationMemberInfo *, NSError *))callback
{
    [self getMemberInfoWithIgnoringCache:false
                                memberId:memberId
                                callback:callback];
}

- (void)getMemberInfoWithIgnoringCache:(BOOL)ignoringCache
                              memberId:(NSString *)memberId
                              callback:(void (^)(AVIMConversationMemberInfo *, NSError *))callback
{
    if (!ignoringCache) {
        __block BOOL hasCache = false;
        __block AVIMConversationMemberInfo *memberInfo = nil;
        [self internalSyncLock:^{
            if (self->_memberInfoTable) {
                hasCache = true;
                memberInfo = self->_memberInfoTable[memberId];
            }
        }];
        if (hasCache) {
            [self invokeInUserInteractQueue:^{
                callback(memberInfo, nil);
            }];
            return;
        }
    }
    
    [self getAllMemberInfoWithIgnoringCache:ignoringCache forcingRefreshIMSessionToken:false recursionCount:0 callback:^(NSArray<AVIMConversationMemberInfo *> *memberInfos, NSError *error) {
        
        if (error) {
            callback(nil, error);
            return;
        }
        
        __block AVIMConversationMemberInfo *memberInfo = nil;
        [self internalSyncLock:^{
            if (self->_memberInfoTable) {
                memberInfo = self->_memberInfoTable[memberId];
            }
        }];
        
        callback(memberInfo, nil);
    }];
}

- (void)updateMemberRoleWithMemberId:(NSString *)memberId
                                role:(AVIMConversationMemberRole)role
                            callback:(void (^)(BOOL, NSError *))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(false, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    if ([memberId isEqualToString:self.creator]) {
        [self invokeInUserInteractQueue:^{
            NSError *error = ({
                AVIMErrorCode code = AVIMErrorCodeOwnerPromotionNotAllowed;
                LCError(code, AVIMErrorMessage(code), nil);
            });
            callback(false, error);
        }];
        return;
    }
    
    NSString *roleKey = AVIMConversationMemberInfo_role_to_key(role);
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        AVIMConvMemberInfo *convMemberInfo = [AVIMConvMemberInfo new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_MemberInfoUpdate;
        outCommand.convMessage = convCommand;
        
        convCommand.cid = self->_conversationId;
        convCommand.targetClientId = memberId;
        convCommand.info = convMemberInfo;
        
        convMemberInfo.pid = memberId;
        if (roleKey) {
            convMemberInfo.role = roleKey;
        } else {
            [self invokeInUserInteractQueue:^{
                callback(false, LCErrorInternal(@"role invalid."));
            }];
            return;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [self invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error);
            }];
            return;
        }
        
        __block AVIMConversationMemberInfo *memberInfo = nil;
        [self internalSyncLock:^{
            if (self->_memberInfoTable) {
                memberInfo = self->_memberInfoTable[memberId];
            }
        }];
        if (memberInfo) {
            [memberInfo updateRawJSONDataWithKey:kAVIMConversationMemberInfoKey_role object:roleKey];
        }
        
        [self invokeInUserInteractQueue:^{
            callback(true, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Member Block

- (void)blockMembers:(NSArray<NSString *> *)memberIds
            callback:(void (^)(NSArray<NSString *> *, NSArray<AVIMOperationFailure *> *, NSError *))callback
{
    [self blockOrUnblockMembers:memberIds isBlockAction:true callback:callback];
}

- (void)unblockMembers:(NSArray<NSString *> *)memberIds
              callback:(void (^)(NSArray<NSString *> *, NSArray<AVIMOperationFailure *> *, NSError *))callback
{
    [self blockOrUnblockMembers:memberIds isBlockAction:false callback:callback];
}

- (void)blockOrUnblockMembers:(NSArray<NSString *> *)memberIds
                isBlockAction:(BOOL)isBlockAction
                     callback:(void (^)(NSArray<NSString *> *, NSArray<AVIMOperationFailure *> *, NSError *))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(nil, nil, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    AVIMSignatureAction action = (isBlockAction ? AVIMSignatureActionBlock : AVIMSignatureActionUnblock);
    
    [client getSignatureWithConversationId:self->_conversationId action:action actionOnClientIds:memberIds callback:^(AVIMSignature *signature) {
        
        AssertRunInInternalSerialQueue(client);
        
        if (signature && signature.error) {
            [self invokeInUserInteractQueue:^{
                callback(nil, nil, signature.error);
            }];
            return;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = ({
            
            AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
            AVIMBlacklistCommand *blacklistCommand = [AVIMBlacklistCommand new];
            
            outCommand.cmd = AVIMCommandType_Blacklist;
            outCommand.op = (isBlockAction ? AVIMOpType_Block : AVIMOpType_Unblock);
            outCommand.blacklistMessage = blacklistCommand;
            
            blacklistCommand.srcCid = self->_conversationId;
            blacklistCommand.toPidsArray = memberIds.mutableCopy;
            if (signature && signature.signature && signature.timestamp && signature.nonce) {
                blacklistCommand.s = signature.signature;
                blacklistCommand.t = signature.timestamp;
                blacklistCommand.n = signature.nonce;
            }
            
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = outCommand;
            commandWrapper;
        });
        
        [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                [self invokeInUserInteractQueue:^{
                    callback(nil, nil, commandWrapper.error);
                }];
                return;
            }
            
            AVIMGenericCommand *inCommand = commandWrapper.inCommand;
            AVIMBlacklistCommand *blacklistCommand = (inCommand.hasBlacklistMessage ? inCommand.blacklistMessage : nil);
            NSMutableArray<AVIMOperationFailure *> *failedPids = [NSMutableArray array];
            for (AVIMErrorCommand *errorCommand in blacklistCommand.failedPidsArray) {
                AVIMOperationFailure *failedResult = [AVIMOperationFailure new];
                failedResult.code = (errorCommand.hasCode ? errorCommand.code : 0);
                failedResult.reason = (errorCommand.hasReason ? errorCommand.reason : nil);
                failedResult.clientIds = errorCommand.pidsArray;
                [failedPids addObject:failedResult];
            }

            [self invokeInUserInteractQueue:^{
                callback(blacklistCommand.allowedPidsArray, failedPids, nil);
            }];
        }];
        
        [client sendCommandWrapper:commandWrapper];
    }];
}

- (void)queryBlockedMembersWithLimit:(NSInteger)limit
                                next:(NSString * _Nullable)next
                            callback:(void (^)(NSArray<NSString *> *, NSString *, NSError *))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(nil, nil, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMBlacklistCommand *blacklistCommand = [AVIMBlacklistCommand new];
        
        outCommand.cmd = AVIMCommandType_Blacklist;
        outCommand.op = AVIMOpType_Query;
        outCommand.blacklistMessage = blacklistCommand;
        
        blacklistCommand.srcCid = self->_conversationId;
        blacklistCommand.limit = (limit <= 0 ? 50 : (limit > 100 ? 100 : (int32_t)limit));
        if (next) {
            blacklistCommand.next = next;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [self invokeInUserInteractQueue:^{
                callback(nil, nil, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMBlacklistCommand *blacklistCommand = (inCommand.hasBlacklistMessage ? inCommand.blacklistMessage : nil);
        NSString *next = (blacklistCommand.hasNext ? blacklistCommand.next : nil);
        
        [self invokeInUserInteractQueue:^{
            callback(blacklistCommand.blockedPidsArray, next, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Member Mute

- (void)muteMembers:(NSArray<NSString *> *)memberIds
           callback:(void (^)(NSArray<NSString *> *, NSArray<AVIMOperationFailure *> *, NSError *))callback
{
    [self muteOrUnmuteMembers:memberIds isMuteAction:true callback:callback];
}

- (void)unmuteMembers:(NSArray<NSString *> *)memberIds
             callback:(void (^)(NSArray<NSString *> *, NSArray<AVIMOperationFailure *> *, NSError *))callback
{
    [self muteOrUnmuteMembers:memberIds isMuteAction:false callback:callback];
}

- (void)muteOrUnmuteMembers:(NSArray<NSString *> *)memberIds
               isMuteAction:(BOOL)isMuteAction
                   callback:(void (^)(NSArray<NSString *> *, NSArray<AVIMOperationFailure *> *, NSError *))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(nil, nil, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = (isMuteAction ? AVIMOpType_AddShutup : AVIMOpType_RemoveShutup);
        outCommand.convMessage = convCommand;
        
        convCommand.cid = self->_conversationId;
        convCommand.mArray = memberIds.mutableCopy;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [self invokeInUserInteractQueue:^{
                callback(nil, nil, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
        NSMutableArray<AVIMOperationFailure *> *failedPids = [NSMutableArray array];
        for (AVIMErrorCommand *errorCommand in convCommand.failedPidsArray) {
            AVIMOperationFailure *failedResult = [AVIMOperationFailure new];
            failedResult.code = (errorCommand.hasCode ? errorCommand.code : 0);
            failedResult.reason = (errorCommand.hasReason ? errorCommand.reason : nil);
            failedResult.clientIds = errorCommand.pidsArray;
            [failedPids addObject:failedResult];
        }
        
        [self invokeInUserInteractQueue:^{
            callback(convCommand.allowedPidsArray, failedPids, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

- (void)queryMutedMembersWithLimit:(NSInteger)limit
                              next:(NSString * _Nullable)next
                          callback:(void (^)(NSArray<NSString *> *, NSString *, NSError *))callback
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        [self invokeInUserInteractQueue:^{
            callback(nil, nil, LCErrorInternal(@"imClient invalid."));
        }];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_QueryShutup;
        outCommand.convMessage = convCommand;
        
        convCommand.cid = self->_conversationId;
        convCommand.limit = (limit <= 0 ? 50 : (limit > 100 ? 100 : (int32_t)limit));
        if (next) {
            convCommand.next = next;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [self invokeInUserInteractQueue:^{
                callback(nil, nil, commandWrapper.error);
            }];
            return;
        }
    
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
        NSString *next = (convCommand.hasNext ? convCommand.next : nil);
        
        [self invokeInUserInteractQueue:^{
            callback(convCommand.mArray, next, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Event Handler

- (AVIMMessage *)process_direct:(AVIMDirectCommand *)directCommand messageId:(NSString *)messageId isTransientMsg:(BOOL)isTransientMsg
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        return nil;
    }
    AssertRunInInternalSerialQueue(client);
    
    NSString *content = (directCommand.hasMsg ? directCommand.msg : nil);
    int64_t timestamp = (directCommand.hasTimestamp ? directCommand.timestamp : 0);
    if (!content || !timestamp) {
        /// @note
        /// 1. message must with `msg` and `timestamp`, otherwise it's invalid.
        /// 2. directCommand's other properties is nullable or optional.
        return nil;
    }
    
    AVIMMessage *message = ({
        AVIMMessage *message = nil;
        AVIMTypedMessageObject *messageObject = [[AVIMTypedMessageObject alloc] initWithJSON:content];
        if (messageObject.isValidTypedMessageObject) {
            message = [AVIMTypedMessage messageWithMessageObject:messageObject];
        } else {
            message = [[AVIMMessage alloc] init];
        }
        message.conversationId = self->_conversationId;
        message.messageId = messageId;
        message.clientId = (directCommand.hasFromPeerId ? directCommand.fromPeerId : nil);
        message.localClientId = self->_clientId;
        message.content = content;
        message.transient = isTransientMsg;
        message.sendTimestamp = timestamp;
        message.offline = (directCommand.hasOffline ? directCommand.offline : false);
        message.hasMore = (directCommand.hasHasMore ? directCommand.hasMore : false);
        message.mentionAll = (directCommand.hasMentionAll ? directCommand.mentionAll : false);
        message.mentionList = directCommand.mentionPidsArray;
        message.updatedAt = (directCommand.hasPatchTimestamp ? [NSDate dateWithTimeIntervalSince1970:(directCommand.patchTimestamp / 1000.0)] : nil);
        if (message.ioType == AVIMMessageIOTypeOut) {
            message.status = AVIMMessageStatusSent;
        } else {
            message.status = AVIMMessageStatusDelivered;
        }
        message;
    });
    
    if (!isTransientMsg) {
        BOOL shouldIncreaseUnreadCount = [self updateLastMessage:message client:client];
        if (shouldIncreaseUnreadCount) {
            [self internalSyncLock:^{
                self->_unreadMessagesCount += 1;
            }];
            [client conversation:self didUpdateForKeys:@[AVIMConversationUpdatedKeyUnreadMessagesCount]];
        }
        if (client.messageQueryCacheEnabled) {
            LCIMMessageCacheStore *cacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:self->_clientId conversationId:self->_conversationId];
            [cacheStore insertOrUpdateMessage:message withBreakpoint:YES];
        }
    }
    
    return message;
}

- (NSUInteger)process_unread:(AVIMUnreadTuple *)unreadTuple
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        return 0;
    }
    AssertRunInInternalSerialQueue(client);
    
    NSUInteger unreadCount = (unreadTuple.hasUnread ? unreadTuple.unread : 0);
    BOOL mentioned = (unreadTuple.hasMentioned ? unreadTuple.mentioned : false);
    
    if (unreadCount > 0) {
        AVIMMessage *lastMessage = ({
            AVIMMessage *lastMessage = nil;
            NSString *content = (unreadTuple.hasData_p ? unreadTuple.data_p : nil);
            NSString *messageId = (unreadTuple.hasMid ? unreadTuple.mid : nil);
            int64_t timestamp = (unreadTuple.hasTimestamp ? unreadTuple.timestamp : 0);
            NSString *fromId = (unreadTuple.hasFrom ? unreadTuple.from : nil);
            if (content && messageId && timestamp && fromId) {
                AVIMTypedMessageObject *typedMessageObject = [[AVIMTypedMessageObject alloc] initWithJSON:content];
                if (typedMessageObject.isValidTypedMessageObject) {
                    lastMessage = [AVIMTypedMessage messageWithMessageObject:typedMessageObject];
                } else {
                    lastMessage = [[AVIMMessage alloc] init];
                }
                int64_t patchTimestamp = (unreadTuple.hasPatchTimestamp ? unreadTuple.patchTimestamp : 0);
                lastMessage.status = AVIMMessageStatusDelivered;
                lastMessage.conversationId = self->_conversationId;
                lastMessage.content = content;
                lastMessage.messageId = messageId;
                lastMessage.sendTimestamp = timestamp;
                lastMessage.clientId = fromId;
                lastMessage.localClientId = self->_clientId;
                lastMessage.updatedAt = [NSDate dateWithTimeIntervalSince1970:(patchTimestamp / 1000.0)];
            }
            lastMessage;
        });
        if (lastMessage) {
            BOOL shouldUpdateUnreadCount = [self updateLastMessage:lastMessage client:client];
            if (shouldUpdateUnreadCount) {
                [self internalSyncLock:^{
                    self->_unreadMessagesCount = unreadCount;
                }];
                [client conversation:self didUpdateForKeys:@[AVIMConversationUpdatedKeyUnreadMessagesCount]];
            }
        }
    } else {
        [self internalSyncLock:^{
            self->_unreadMessagesCount = 0;
        }];
        [client conversation:self didUpdateForKeys:@[AVIMConversationUpdatedKeyUnreadMessagesCount]];
    }
    
    self->_unreadMessagesMentioned = mentioned;
    [client conversation:self didUpdateForKeys:@[AVIMConversationUpdatedKeyUnreadMessagesMentioned]];
    
    return unreadCount;
}

- (AVIMMessage *)process_patch_modified:(AVIMPatchItem *)patchItem
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        return nil;
    }
    AssertRunInInternalSerialQueue(client);
    
    NSString *content = (patchItem.hasData_p ? patchItem.data_p : nil);
    NSString *messageId = (patchItem.hasMid ? patchItem.mid : nil);
    int64_t timestamp = (patchItem.hasTimestamp ? patchItem.timestamp : 0);
    NSString *fromId = (patchItem.hasFrom ? patchItem.from : nil);
    int64_t patchTimestamp = (patchItem.hasPatchTimestamp ? patchItem.patchTimestamp : 0);
    if (!content || !messageId || !timestamp || !fromId || !patchTimestamp) {
        return nil;
    }
    
    AVIMMessage *patchMessage = ({
        AVIMMessage *message = nil;
        AVIMTypedMessageObject *messageObject = [[AVIMTypedMessageObject alloc] initWithJSON:content];
        if ([messageObject isValidTypedMessageObject]) {
            message = [AVIMTypedMessage messageWithMessageObject:messageObject];
        } else {
            message = [[AVIMMessage alloc] init];
        }
        message.messageId = messageId;
        message.content = content;
        message.sendTimestamp = timestamp;
        message.clientId = fromId;
        message.conversationId = self->_conversationId;
        message.localClientId = self->_clientId;
        message.status = AVIMMessageStatusDelivered;
        message.mentionAll = (patchItem.hasMentionAll ? patchItem.mentionAll : false);
        message.mentionList = patchItem.mentionPidsArray;
        message.updatedAt = [NSDate dateWithTimeIntervalSince1970:(patchTimestamp / 1000.0)];
        message;
    });
    
    [self updateLastMessage:patchMessage client:client];
    
    if (client.messageQueryCacheEnabled) {
        LCIMMessageCacheStore *messageCacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:self->_clientId conversationId:self->_conversationId];
        [messageCacheStore insertOrUpdateMessage:patchMessage withBreakpoint:YES];
    }
    
    return patchMessage;
}

- (AVIMMessage *)process_rcp:(AVIMRcpCommand *)rcpCommand isReadRcp:(BOOL)isReadRcp
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        return nil;
    }
    AssertRunInInternalSerialQueue(client);
    
    NSString *messageId = (rcpCommand.hasId_p ? rcpCommand.id_p : nil);
    int64_t timestamp = (rcpCommand.hasT ? rcpCommand.t : 0);
    
    __block AVIMMessage *message = nil;
    if (messageId && !isReadRcp) {
        [self internalSyncLock:^{
            message = self->_rcpMessageTable[messageId];
            [self->_rcpMessageTable removeObjectForKey:messageId];
        }];
        if (message) {
            message.status = AVIMMessageStatusDelivered;
            message.deliveredTimestamp = timestamp;
        }
    }
    
    [self internalSyncLock:^{
        if (isReadRcp) {
            self->_lastReadTimestamp = timestamp;
        } else {
            self->_lastDeliveredTimestamp = timestamp;
        }
    }];
    
    [client conversation:self didUpdateForKeys:@[(isReadRcp ? AVIMConversationUpdatedKeyLastReadAt : AVIMConversationUpdatedKeyLastDeliveredAt)]];
    
    return message;
}

- (void)process_conv_updated_attr:(NSDictionary *)attr attrModified:(NSDictionary *)attrModified
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        return;
    }
    AssertRunInInternalSerialQueue(client);
    
    [self internalSyncLock:^{
        process_attr_and_attrModified(attr, attrModified, self->_rawJSONData);
    }];
    
    [self removeCachedConversation];
}

- (void)process_member_info_changed:(NSString *)memberId role:(NSString *)role
{
    AVIMClient *client = self->_imClient;
    if (!client) {
        return;
    }
    AssertRunInInternalSerialQueue(client);
    
    if (!memberId || !role) {
        return;
    }
    
    __block AVIMConversationMemberInfo *memberInfo = nil;
    [self internalSyncLock:^{
        if (self->_memberInfoTable) {
            memberInfo = self->_memberInfoTable[memberId];
        }
    }];
    if (memberInfo) {
        [memberInfo updateRawJSONDataWithKey:kAVIMConversationMemberInfoKey_role object:role];
    }
}

#pragma mark - Keyed Conversation

- (AVIMKeyedConversation *)keyedConversation
{
    AVIMKeyedConversation *keyedConversation = [AVIMKeyedConversation new];
    keyedConversation.rawDataDic = self.rawJSONDataCopy;
    return keyedConversation;
}

// MARK: - Deprecated

- (void)sendMessage:(AVIMMessage *)message
            options:(AVIMMessageSendOption)options
           callback:(AVIMBooleanResultBlock)callback
{
    [self sendMessage:message
              options:options
        progressBlock:nil
             callback:callback];
}


- (void)sendMessage:(AVIMMessage *)message
            options:(AVIMMessageSendOption)options
      progressBlock:(AVProgressBlock)progressBlock
           callback:(AVIMBooleanResultBlock)callback
{
    AVIMMessageOption *option = [[AVIMMessageOption alloc] init];
    
    if (options & AVIMMessageSendOptionTransient)
        option.transient = YES;
    
    if (options & AVIMMessageSendOptionRequestReceipt)
        option.receipt = YES;
    
    [self sendMessage:message option:option progressBlock:progressBlock callback:callback];
}


- (void)update:(NSDictionary *)attributes
      callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self updateWithDictionary:attributes callback:^(BOOL succeeded, NSError *error) {
        [self invokeInUserInteractQueue:^{
            callback(succeeded, error);
        }];
    }];
}

- (void)markAsReadInBackground
{
    AVIMClient *client = self->_imClient;
    
    if (!client) {
        
        return;
    }
    
    __weak typeof(self) ws = self;
    
    dispatch_async(client.internalSerialQueue, ^{
        [ws.imClient sendCommand:({
            AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
            genericCommand.needResponse = YES;
            genericCommand.cmd = AVIMCommandType_Read;
            genericCommand.peerId = ws.imClient.clientId;
            
            AVIMReadCommand *readCommand = [[AVIMReadCommand alloc] init];
            readCommand.cid = ws.conversationId;
            [genericCommand avim_addRequiredKeyWithCommand:readCommand];
            genericCommand;
        })];
    });
}

@end

@implementation AVIMChatRoom

@end

@implementation AVIMServiceConversation

- (void)subscribeWithCallback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self joinWithCallback:callback];
}

- (void)unsubscribeWithCallback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self quitWithCallback:callback];
}

@end

@implementation AVIMTemporaryConversation

@end
