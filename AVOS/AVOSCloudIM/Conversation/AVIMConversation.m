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

NSString *LCIMClientIdKey = @"clientId";
NSString *LCIMConversationIdKey = @"conversationId";
NSString *LCIMConversationPropertyNameKey = @"propertyName";
NSString *LCIMConversationPropertyValueKey = @"propertyValue";

NSNotificationName LCIMConversationPropertyUpdateNotification = @"LCIMConversationPropertyUpdateNotification";
NSNotificationName LCIMConversationDidReceiveMessageNotification = @"LCIMConversationDidReceiveMessageNotification";

static NSError * AVIMConversation_ParameterInvalidError(NSString *reason)
{
    NSError *aError = ({
        NSDictionary *userInfo = @{ @"reason" : reason };
        [NSError errorWithDomain:@"LeanCloudErrorDomain"
                            code:0
                        userInfo:userInfo];
    });
    return aError;
}

static void AVIMConversation_MergeUpdatedDicIntoOriginDic(NSDictionary *updatedDic, NSMutableDictionary *originDic)
{
    if (!updatedDic || !originDic) {
        
        return;
    }
    
    NSArray *allKeys = [updatedDic allKeys];
    
    for (id key in allKeys) {
        
        id newValue = updatedDic[key];
        
        if ([NSString lc__checkingType:key]) {
            
            NSArray *subKeys = [(NSString *)key componentsSeparatedByString:@"."];
            
            if (subKeys.count > 1) {
                
                id oldSubValue = originDic[subKeys[0]];
                
                if (!oldSubValue) {
                    
                    oldSubValue = [NSMutableDictionary dictionary];
                    
                    originDic[subKeys[0]] = oldSubValue;
                }
                
                for (int i = 1; i < subKeys.count; i++) {
                    
                    id nextSubKey = subKeys[i];
                    
                    if (i == subKeys.count - 1) {
                        
                        oldSubValue[nextSubKey] = newValue;
                        
                    } else {
                        
                        id nextSubValue = oldSubValue[nextSubKey];
                        
                        if (!nextSubValue) {
                            
                            nextSubValue = [NSMutableDictionary dictionary];
                            
                            oldSubValue[nextSubKey] = nextSubValue;
                        }
                        
                        oldSubValue = nextSubValue;
                    }
                }
            } else {
                
                originDic[key] = newValue;
            }
        } else {
            
            originDic[key] = newValue;
        }
    }
}

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
    
    NSLock *_lock;
    
    NSMutableDictionary *_rawJSONData;
    NSMutableDictionary *_pendingData;
    NSMutableDictionary *_snapshotData;
    
    NSMutableDictionary<NSString *, AVIMConversationMemberInfo *> *_memberInfoTable;
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
    [NSException raise:NSInternalInconsistencyException
                format:@"New Instance is not Allowed."];
    
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Init Instance is not Allowed."];
    
    return nil;
}

+ (instancetype)newWithConversationId:(NSString *)conversationId
                             convType:(LCIMConvType)convType
                               client:(AVIMClient *)client
{
    if (!conversationId) {
        
        return nil;
    }
    
    AVIMConversation *conv = nil;
    
    switch (convType)
    {
        case LCIMConvTypeNormal:
            
            conv = [[AVIMConversation alloc] initWithConversationId:conversationId client:client];
            
            conv.transient = false;
            conv.system = false;
            conv.temporary = false;
            
            break;
            
        case LCIMConvTypeTransient:
            
            conv = [[AVIMChatRoom alloc] initWithConversationId:conversationId client:client];
            
            conv.transient = true;
            conv.system = false;
            conv.temporary = false;
            
            break;
            
        case LCIMConvTypeSystem:
            
            conv = [[AVIMServiceConversation alloc] initWithConversationId:conversationId client:client];
            
            conv.transient = false;
            conv.system = true;
            conv.temporary = false;
            
            break;
            
        case LCIMConvTypeTemporary:
            
            conv = [[AVIMTemporaryConversation alloc] initWithConversationId:conversationId client:client];
            
            conv.transient = false;
            conv.system = false;
            conv.temporary = true;
            
            break;
            
        default:
            
            AVLoggerError(AVLoggerDomainIM, @"Unknown Conversation Type is Found, ID: (%@)", conversationId);
            
            conv = nil;
            
            break;
    }
    
    if (conv) {

        [conv setupObserver];
    }
    
    return conv;
}

+ (instancetype)newWithRawJSONData:(NSDictionary *)rawJSONData
                            client:(AVIMClient *)client
{
    NSString *conversationId = [rawJSONData objectForKey:kConvAttrKey_conversationId];
    
    if (!conversationId) {
        
        return nil;
    }
    
    AVIMConversation *conversation = nil;
    
    BOOL isTransient = [rawJSONData[kConvAttrKey_transient] boolValue];
    BOOL isSystem = [rawJSONData[kConvAttrKey_system] boolValue];
    BOOL isTemporary = [rawJSONData[kConvAttrKey_temporary] boolValue];
    
    if (isTransient && !isSystem && !isTemporary) {
        
        conversation = [[AVIMChatRoom alloc] initWithConversationId:conversationId client:client];
        
    } else if (isSystem &&!isTransient  && !isTemporary) {
        
        conversation = [[AVIMServiceConversation alloc] initWithConversationId:conversationId client:client];
        
    } else if (isTemporary && !isTransient && !isSystem) {
        
        conversation = [[AVIMTemporaryConversation alloc] initWithConversationId:conversationId client:client];
        
    } else {
        
        conversation = [[AVIMConversation alloc] initWithConversationId:conversationId client:client];
    }
    
    conversation.transient = isTransient;
    conversation.system = isSystem;
    conversation.temporary = isTemporary;
    
    [conversation setRawJSONData:[rawJSONData mutableCopy]];
    
    conversation.name = rawJSONData[kConvAttrKey_name];
    conversation.attributes = rawJSONData[kConvAttrKey_attributes];
    conversation.creator = rawJSONData[kConvAttrKey_creator];
    conversation.lastMessage = [AVIMMessage parseMessageWithConversationId:conversationId result:rawJSONData];
    conversation.members = rawJSONData[kConvAttrKey_members];
    
    conversation.uniqueId = rawJSONData[kConvAttrKey_uniqueId];
    conversation.unique = [rawJSONData[kConvAttrKey_unique] boolValue];
    conversation.muted = [rawJSONData[kConvAttrKey_muted] boolValue];
    conversation.temporaryTTL = [rawJSONData[kConvAttrKey_temporaryTTL] intValue];
    
    conversation.lastMessageAt = ({
        
        NSDate *date = nil;
        
        NSDictionary *lastMessageDate = rawJSONData[kConvAttrKey_lastMessageAt];
        NSNumber *lastMessageTimestamp = rawJSONData[kConvAttrKey_lastMessageTimestamp];
        /* For system conversation, there's no `lm` field.
         Instead, we read `msg_timestamp`field. */
        if (lastMessageDate) {
            date = [AVObjectUtils dateFromDictionary:lastMessageDate];
        } else if (lastMessageTimestamp) {
            date = [NSDate dateWithTimeIntervalSince1970:([lastMessageTimestamp doubleValue] / 1000.0)];
        }
        
        date;
    });
    
    conversation.createAt = ({
        
        NSDate *date = nil;
        
        NSString *createdAt = rawJSONData[kConvAttrKey_createdAt];
        if (createdAt) {
            date = [AVObjectUtils dateFromString:createdAt];
        }
        
        date;
    });
    
    conversation.updateAt = ({
        
        NSDate *date = nil;
        
        NSString *updatedAt = rawJSONData[kConvAttrKey_updatedAt];
        if (updatedAt) {
            date = [AVObjectUtils dateFromString:updatedAt];
        }
        
        date;
    });
    
    [conversation setupObserver];
    
    return conversation;
}

- (instancetype)initWithConversationId:(NSString *)conversationId
                                client:(AVIMClient *)client
{
    self = [super init];
    
    if (self) {
        
        self->_conversationId = conversationId;
        
        self->_imClient = client;
        
        self->_lock = [[NSLock alloc] init];
        
        self->_rawJSONData = [NSMutableDictionary dictionary];
        
        self->_pendingData = [NSMutableDictionary dictionary];
        
        self->_snapshotData = nil;
        
        self->_memberInfoTable = nil;
    }
    
    return self;
}

- (void)setupObserver
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    [center addObserver:self
               selector:@selector(propertyDidUpdate:)
                   name:LCIMConversationPropertyUpdateNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(didReceiveMessageNotification:)
                   name:LCIMConversationDidReceiveMessageNotification
                 object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// MARK: - Callback Invoking

- (void)invokeInSpecifiedQueue:(void (^)(void))block
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        block();
    });
}

// MARK: - Internal Lock

- (void)internalSyncLock:(void (^)(void))block
{
    [_lock lock];
    block();
    [_lock unlock];
}

// MARK: - PaaS Client

- (AVPaasClient *)paasClient
{
    return AVPaasClient.sharedInstance;
}

// MARK: -

- (void)propertyDidUpdate:(NSNotification *)notification {
    if (!self.conversationId)
        return;

    NSDictionary *userInfo = notification.userInfo;

    NSString *clientId = userInfo[LCIMClientIdKey];
    NSString *conversationId = userInfo[LCIMConversationIdKey];
    NSString *propertyName = userInfo[LCIMConversationPropertyNameKey];
    NSString *propertyValue = userInfo[LCIMConversationPropertyValueKey];

    if (!propertyName
        || (!clientId || ![clientId isEqualToString:self.imClient.clientId])
        || (!conversationId || ![conversationId isEqualToString:self.conversationId]))
        return;

    [self tryUpdateKey:propertyName toValue:propertyValue];
}

- (void)tryUpdateKey:(NSString *)key toValue:(id)value {
    if ([self shouldUpdateKey:key toValue:value]) {
        [self updateKey:key toValue:value];
    }
}

- (BOOL)shouldUpdateKey:(NSString *)key toValue:(id)value {
    if ([key isEqualToString:@"lastMessage"]) {
        AVIMMessage *lastMessage = value;
        AVIMMessage *originLastMessage = self.lastMessage;

        BOOL shouldUpdate = (lastMessage && (!originLastMessage || lastMessage.sendTimestamp > originLastMessage.sendTimestamp));

        if (shouldUpdate) {
            NSDate *lastMessageAt = [NSDate dateWithTimeIntervalSince1970:(lastMessage.sendTimestamp / 1000.0)];
            [self updateKey:@"lastMessageAt" toValue:lastMessageAt];
        }

        return shouldUpdate;
    }

    return YES;
}

- (void)updateKey:(NSString *)key toValue:(id)value {
    [self setValue:value forKey:key];
    [self postUpdateNotificationForKey:key];
}

- (void)postUpdateNotificationForKey:(NSString *)key {
    id  delegate = self.imClient.threadUnsafe_delegate;
    SEL selector = @selector(conversation:didUpdateForKey:);

    if (![delegate respondsToSelector:selector])
        return;

    [AVIMRuntimeHelper callMethodInMainThreadWithTarget:delegate
                                               selector:selector
                                              arguments:@[self, key]];
}

- (void)didReceiveMessageNotification:(NSNotification *)notification {
    if (!self.conversationId)
        return;
    if (notification.object != self.imClient)
        return;

    NSDictionary *userInfo = notification.userInfo;
    AVIMMessage *message = userInfo[@"message"];

    if (![message.conversationId isEqualToString:self.conversationId])
        return;

    [self didReceiveMessage:message];
}

- (void)didReceiveMessage:(AVIMMessage *)message {
    if (!message.transient) {
        self.lastMessage = message;
        [self postUpdateNotificationForKey:NSStringFromSelector(@selector(lastMessage))];

        /* Update last message timestamp if needed. */
        NSDate *sentAt = [NSDate dateWithTimeIntervalSince1970:(message.sendTimestamp / 1000.0)];

        if (!self.lastMessageAt || [self.lastMessageAt compare:sentAt] == NSOrderedAscending) {
            self.lastMessageAt = sentAt;
            [self postUpdateNotificationForKey:NSStringFromSelector(@selector(lastMessageAt))];
        }

        /* Increase unread messages count. */
        self.unreadMessagesCount += 1;
        [self postUpdateNotificationForKey:NSStringFromSelector(@selector(unreadMessagesCount))];
    }
}

// MARK: - Property

- (NSDictionary *)rawJSONDataCopy
{
    __block NSDictionary *dic = nil;
    
    [self internalSyncLock:^{
        
        dic = [self->_rawJSONData copy];
    }];
    
    return dic;
}

- (void)setRawJSONData:(NSMutableDictionary *)rawJSONData
{
    [self internalSyncLock:^{
        
        self->_rawJSONData = rawJSONData;
    }];
}

- (NSString *)clientId {
    return self.imClient.clientId;
}

- (AVIMMessage *)lastMessage {
    if (_lastMessage) {
        return _lastMessage;
    }
    if (!_lastMessageAt || !self.imClient.messageQueryCacheEnabled) {
        return nil;
    }
    [AVUtils warnMainThreadIfNecessary];
    NSArray *cachedMessages = [[self messageCacheStore] latestMessagesWithLimit:1];
    AVIMMessage *message = [cachedMessages lastObject];
    if (message) {
        _lastMessage = message;
        return _lastMessage;
    }
    return nil;
}

- (void)setImClient:(AVIMClient *)imClient {
    _imClient = imClient;
}

- (void)setConversationId:(NSString *)conversationId {
    _conversationId = [conversationId copy];
}

- (void)setMembers:(NSArray *)members {
    _members = members;
}

- (void)setObject:(id)object forKey:(NSString *)key
{
    [self internalSyncLock:^{
        
        self->_pendingData[key] = object;
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

- (void)addMembers:(NSArray *)members {
    if (members.count > 0) {
        self.members = ({
            NSMutableOrderedSet *allMembers = [NSMutableOrderedSet orderedSetWithArray:self.members ?: @[]];
            [allMembers addObjectsFromArray:members];
            [allMembers array];
        });
    }
}

- (void)addMember:(NSString *)clientId {
    if (clientId) {
        [self addMembers:@[clientId]];
    }
}

- (void)removeMembers:(NSArray *)members {
    if (members.count > 0) {
        if (_members.count > 0) {
            NSMutableArray *array = [_members mutableCopy];
            [array removeObjectsInArray:members];
            self.members = [array copy];
        }
    }
}

- (void)removeMember:(NSString *)clientId {
    if (clientId) {
        [self removeMembers:@[clientId]];
    }
}

- (void)setCreator:(NSString *)creator {
    _creator = creator;
}

- (NSString *)name
{
    __block NSString *name = nil;
    
    [self internalSyncLock:^{
        
        name = _rawJSONData[kConvAttrKey_name];
    }];
    
    return name;
}

- (void)setName:(NSString *)name
{
    [self internalSyncLock:^{
        
        _rawJSONData[kConvAttrKey_name] = name;
    }];
}

- (NSDictionary *)attributes
{
    __block NSDictionary *attributes = nil;
    
    [self internalSyncLock:^{
        
        attributes = _rawJSONData[kConvAttrKey_attributes];
    }];
    
    return attributes;
}

- (void)setAttributes:(NSDictionary *)attributes
{
    [self internalSyncLock:^{
        
        _rawJSONData[kConvAttrKey_attributes] = attributes;
    }];
}

// MARK: -

- (void)fetchWithCallback:(void (^)(BOOL, NSError *))callback
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(false, aError);
        });
        
        return;
    }
    
    AVIMConversationQuery *query = [client conversationQuery];

    query.cachePolicy = kAVCachePolicyNetworkOnly;
    [query getConversationById:self.conversationId callback:^(AVIMConversation *conversation, NSError *error) {
        dispatch_async(client.internalSerialQueue, ^{
            [conversation lastMessage];
            if (conversation && conversation != self) {
                [self setKeyedConversation:[conversation keyedConversation]];
            }
            [AVIMBlockHelper callBooleanResultBlock:callback error:error];
        });
    }];
}

- (void)fetchReceiptTimestampsInBackground
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        return;
    }
    
    dispatch_async(client.internalSerialQueue, ^{
        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];

        genericCommand.cmd = AVIMCommandType_Conv;
        genericCommand.op = AVIMOpType_MaxRead;
        genericCommand.peerId = self.imClient.clientId;
        genericCommand.needResponse = YES;

        AVIMConvCommand *convCommand = [[AVIMConvCommand alloc] init];
        convCommand.cid = self.conversationId;

        genericCommand.convMessage = convCommand;

        [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
            if (error)
                return;

            AVIMConvCommand *convCommand = inCommand.convMessage;
            NSDate *lastDeliveredAt = [NSDate dateWithTimeIntervalSince1970:convCommand.maxAckTimestamp / 1000.0];
            NSDate *lastReadAt = [NSDate dateWithTimeIntervalSince1970:convCommand.maxReadTimestamp / 1000.0];

            [self.imClient updateReceipt:lastDeliveredAt
                          ofConversation:self
                                  forKey:NSStringFromSelector(@selector(lastDeliveredAt))];

            [self.imClient updateReceipt:lastReadAt
                          ofConversation:self
                                  forKey:NSStringFromSelector(@selector(lastReadAt))];
        }];

        [self.imClient sendCommand:genericCommand];
    });
}

- (void)joinWithCallback:(void (^)(BOOL, NSError *))callback
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(false, aError);
        });
        
        return;
    }
    
    [self addMembersWithClientIds:@[client.clientId] callback:callback];
}

- (void)addMembersWithClientIds:(NSArray<NSString *> *)clientIds
                       callback:(void (^)(BOOL, NSError *))callback;
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(false, aError);
        });
        
        return;
    }
    
    [[AVIMClient class] _assertClientIdsIsValid:clientIds];
    dispatch_async(client.internalSerialQueue, ^{
        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
        genericCommand.needResponse = YES;
        genericCommand.cmd = AVIMCommandType_Conv;
        genericCommand.peerId = client.clientId;
        genericCommand.op = AVIMOpType_Add;
        
        AVIMConvCommand *command = [[AVIMConvCommand alloc] init];
        command.cid = self.conversationId;
        command.mArray = [NSMutableArray arrayWithArray:clientIds];
        
        NSArray *clientIds = [command.mArray copy];

        [client getSignatureWithConversationId:command.cid action:AVIMSignatureActionAdd actionOnClientIds:clientIds callback:^(AVIMSignature *signature) {
            
            if (signature && signature.error) {
                
                [self invokeInSpecifiedQueue:^{
                    
                    callback(false, signature.error);
                }];
                
                return;
            }
            
            [genericCommand avim_addRequiredKeyWithCommand:command];
            [genericCommand avim_addRequiredKeyForConvMessageWithSignature:signature];
            
            [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
                if (!error) {
                    AVIMConvCommand *conversationOutCommand = outCommand.convMessage;
                    [self addMembers:[conversationOutCommand.mArray copy]];
                    [self removeCachedConversation];
                    [AVIMBlockHelper callBooleanResultBlock:callback error:nil];
                } else {
                    [AVIMBlockHelper callBooleanResultBlock:callback error:error];
                }
            }];
            
            [client sendCommand:genericCommand];
        }];
    });
}

- (void)quitWithCallback:(void (^)(BOOL, NSError *))callback
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(false, aError);
        });
        
        return;
    }
    
    [self removeMembersWithClientIds:@[client.clientId] callback:callback];
}

- (void)removeMembersWithClientIds:(NSArray<NSString *> *)clientIds
                          callback:(void (^)(BOOL, NSError *))callback
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{

            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(false, aError);
        });
        
        return;
    }
    
    NSString *myClientId = client.clientId;
    
    [[AVIMClient class] _assertClientIdsIsValid:clientIds];
    dispatch_async(client.internalSerialQueue, ^{
        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
        genericCommand.needResponse = YES;
        genericCommand.cmd = AVIMCommandType_Conv;
        genericCommand.peerId = client.clientId;
        genericCommand.op = AVIMOpType_Remove;
        
        AVIMConvCommand *command = [[AVIMConvCommand alloc] init];
        command.cid = self.conversationId;
        command.mArray = [NSMutableArray arrayWithArray:clientIds];
        
        NSArray *clientIds = [command.mArray copy];
        
        [client getSignatureWithConversationId:command.cid action:AVIMSignatureActionRemove actionOnClientIds:clientIds callback:^(AVIMSignature *signature) {
            
            if (signature && signature.error) {
                
                [self invokeInSpecifiedQueue:^{
                    
                    callback(false, signature.error);
                }];
                
                return;
            }
            
            [genericCommand avim_addRequiredKeyWithCommand:command];
            [genericCommand avim_addRequiredKeyForConvMessageWithSignature:signature];
            
            [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
                if (!error) {
                    AVIMConvCommand *conversationOutCommand = outCommand.convMessage;
                    [self removeMembers:[conversationOutCommand.mArray copy]];
                    [self removeCachedConversation];
                    if ([clientIds containsObject:myClientId]) {
                        [self removeCachedMessages];
                    }
                    
                    [AVIMBlockHelper callBooleanResultBlock:callback error:nil];
                } else {
                    [AVIMBlockHelper callBooleanResultBlock:callback error:error];
                }
            }];
            
            [client sendCommand:genericCommand];
        }];
    });
}

- (void)countMembersWithCallback:(void (^)(NSInteger, NSError *))callback
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(0, aError);
        });
        
        return;
    }
    
    dispatch_async(client.internalSerialQueue, ^{

        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
        genericCommand.needResponse = YES;
        genericCommand.cmd = AVIMCommandType_Conv;
        genericCommand.peerId = client.clientId;
        genericCommand.op = AVIMOpType_Count;
        
        AVIMConvCommand *command = [[AVIMConvCommand alloc] init];
        command.cid = self.conversationId;
        
        [genericCommand avim_addRequiredKeyWithCommand:command];
        [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
            if (!error) {
                AVIMConvCommand *conversationInCommand = inCommand.convMessage;
                [self invokeInSpecifiedQueue:^{
                    callback(conversationInCommand.count, nil);
                }];
            } else {
                [self invokeInSpecifiedQueue:^{
                    callback(0, error);
                }];
            }
        }];
        [client sendCommand:genericCommand];
    });
}

- (void)updateWithCallback:(void (^)(BOOL succeeded, NSError *error))callback
{
    __block NSDictionary *pendingData = nil;
    
    [self internalSyncLock:^{
        
        if (self->_snapshotData) {
            
            pendingData = nil;
            
        } else {
            
            pendingData = [self->_pendingData copy];
            
            NSMutableDictionary *snapshotData = [_rawJSONData mutableCopy];
            
            AVIMConversation_MergeUpdatedDicIntoOriginDic(pendingData, snapshotData);
            
            self->_snapshotData = snapshotData;
        }
    }];
    
    if (!pendingData) {
        
        [self invokeInSpecifiedQueue:^{
            
            NSError *aError = ({
                NSString *reason = @"can't update before last update done.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(false, aError);
        }];
        
        return;
    }
    
    void(^clearPendingData_block)(void) = ^(void) {
        
        [self->_pendingData removeAllObjects];
        
        self->_snapshotData = nil;
    };
    
    [self updateWithDictionary:pendingData callback:^(BOOL succeeded, NSError *error) {
        
        if (error) {
            
            [self internalSyncLock:^{
                
                clearPendingData_block();
            }];
            
            [self invokeInSpecifiedQueue:^{
                
                callback(false, error);
            }];
            
            return;
        }
        
        [self removeCachedConversation];
        
        [self internalSyncLock:^{
            
            self->_rawJSONData = self->_snapshotData;
            
            clearPendingData_block();
        }];
        
        [self invokeInSpecifiedQueue:^{
            
            callback(true, nil);
        }];
    }];
}

- (void)updateWithDictionary:(NSDictionary *)dictionary
                    callback:(void (^)(BOOL succeeded, NSError *error))callback
{
    AVIMClient *client = self.imClient;
    
    NSString *conversationId = self.conversationId;
    
    if (!client) {
        
        callback(false, AVIMConversation_ParameterInvalidError(@"imClient invalid."));
        
        return;
    }
    
    [client addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        LCIMProtobufCommandWrapper *commandWrapper = ({
            
            AVIMGenericCommand *command = [[AVIMGenericCommand alloc] init];
            command.cmd = AVIMCommandType_Conv;
            command.op = AVIMOpType_Update;
            
            AVIMConvCommand *convCommand = [[AVIMConvCommand alloc] init];
            convCommand.cid = conversationId;
            convCommand.attr = [AVIMCommandFormatter JSONObjectWithDictionary:dictionary];
            
            command.convMessage = convCommand;
            
            LCIMProtobufCommandWrapper *commandWrapper = [[LCIMProtobufCommandWrapper alloc] init];
            commandWrapper.outCommand = command;
            
            commandWrapper;
        });
        
        [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                
                callback(false, commandWrapper.error);
                
                return;
            }
            
            callback(true, nil);
        }];
        
        [client sendCommandWrapper:commandWrapper];
    }];
}

- (void)muteWithCallback:(void (^)(BOOL, NSError *))callback
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(false, aError);
        });
        
        return;
    }
    
    dispatch_async(client.internalSerialQueue, ^{

        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
        genericCommand.needResponse = YES;
        genericCommand.cmd = AVIMCommandType_Conv;
        genericCommand.peerId = client.clientId;
        genericCommand.op = AVIMOpType_Mute;
        
        AVIMConvCommand *convCommand = [[AVIMConvCommand alloc] init];
        convCommand.cid = self.conversationId;
        [genericCommand avim_addRequiredKeyWithCommand:convCommand];
        [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
            if (!error) {
                self.muted = YES;
                [self removeCachedConversation];
                [AVIMBlockHelper callBooleanResultBlock:callback error:nil];
            } else {
                [AVIMBlockHelper callBooleanResultBlock:callback error:error];
            }
        }];
        [client sendCommand:genericCommand];
    });
}

- (void)unmuteWithCallback:(void (^)(BOOL, NSError *))callback
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{

            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(false, aError);
        });
        
        return;
    }
    
    dispatch_async(client.internalSerialQueue, ^{

        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
        genericCommand.needResponse = YES;
        genericCommand.cmd = AVIMCommandType_Conv;
        genericCommand.peerId = client.clientId;
        genericCommand.op = AVIMOpType_Unmute;
        
        AVIMConvCommand *convCommand = [[AVIMConvCommand alloc] init];
        convCommand.cid = self.conversationId;
        [genericCommand avim_addRequiredKeyWithCommand:convCommand];
        [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
            if (!error) {
                self.muted = NO;
                [self removeCachedConversation];
                [AVIMBlockHelper callBooleanResultBlock:callback error:nil];
            } else {
                [AVIMBlockHelper callBooleanResultBlock:callback error:error];
            }
        }];
        [client sendCommand:genericCommand];
    });
}

- (void)readInBackground
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        return;
    }
    
    dispatch_async(client.internalSerialQueue, ^{

        int64_t lastTimestamp = 0;
        NSString *lastMessageId = nil;

        /* NOTE:
           We do not care about the owner of last message.
           Server will do the right thing.
         */
        AVIMMessage *lastMessage = self.lastMessage;

        if (lastMessage) {
            lastTimestamp = lastMessage.sendTimestamp;
            lastMessageId = lastMessage.messageId;
        } else if (self.lastMessageAt)
            lastTimestamp = [self.lastMessageAt timeIntervalSince1970] * 1000;

        if (lastTimestamp <= 0) {
            AVLoggerInfo(AVLoggerDomainIM, @"No message to read.");
            return;
        }

        AVIMReadTuple *readTuple = [[AVIMReadTuple alloc] init];
        AVIMReadCommand *readCommand = [[AVIMReadCommand alloc] init];
        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];

        readTuple.cid = self.conversationId;
        readTuple.mid = lastMessageId;
        readTuple.timestamp = lastTimestamp;

        readCommand.convsArray = [NSMutableArray arrayWithObject:readTuple];

        genericCommand.cmd = AVIMCommandType_Read;
        genericCommand.peerId = client.clientId;

        [genericCommand avim_addRequiredKeyWithCommand:readCommand];

        [client resetUnreadMessagesCountForConversation:self];
        [client sendCommand:genericCommand];
    });
}

- (void)sendMessage:(AVIMMessage *)message
           callback:(void (^)(BOOL, NSError *))callback
{
    [self sendMessage:message option:nil callback:callback];
}

- (void)sendMessage:(AVIMMessage *)message
             option:(AVIMMessageOption *)option
           callback:(void (^)(BOOL, NSError *))callback
{
    [self sendMessage:message option:option progressBlock:nil callback:callback];
}

- (void)sendMessage:(AVIMMessage *)message
      progressBlock:(void (^)(NSInteger))progressBlock
           callback:(void (^)(BOOL, NSError *))callback
{
    [self sendMessage:message option:nil progressBlock:progressBlock callback:callback];
}

- (void)sendMessage:(AVIMMessage *)message
             option:(AVIMMessageOption *)option
      progressBlock:(void (^)(NSInteger))progressBlock
           callback:(void (^)(BOOL, NSError *))callback
{
    AVIMClient *client = self.imClient;
    
    if (!client || client.threadUnsafe_status != AVIMClientStatusOpened) {
        
        message.status = AVIMMessageStatusFailed;
        NSError *error = [AVIMErrorUtil errorWithCode:kAVIMErrorClientNotOpen reason:@"You can only send message when the status of the client is opened."];
        [AVIMBlockHelper callBooleanResultBlock:callback error:error];
        return;
    }
    
    message.clientId = client.clientId;
    message.conversationId = _conversationId;
    message.status = AVIMMessageStatusSending;
    
    if ([message isKindOfClass:[AVIMTypedMessage class]]) {
        AVIMTypedMessage *typedMessage = (AVIMTypedMessage *)message;
        AVFile *file = typedMessage.file;
        
        if (file) {
            [file uploadWithProgress:progressBlock completionHandler:^(BOOL succeeded, NSError * _Nullable error) {
                if (succeeded) {
                    /* If uploading is success, bind file to message */
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self fillTypedMessage:typedMessage withFile:file];
                        [self fillTypedMessageForLocationIfNeeded:typedMessage];
                        [self sendRealMessage:message option:option callback:callback];
                    });
                } else {
                    message.status = AVIMMessageStatusFailed;
                    [AVIMBlockHelper callBooleanResultBlock:callback error:error];
                }
            }];
        } else {
            [self fillTypedMessageForLocationIfNeeded:typedMessage];
            [self sendRealMessage:message option:option callback:callback];
        }
    } else {
        [self sendRealMessage:message option:option callback:callback];
    }
}

- (void)fillTypedMessage:(AVIMTypedMessage *)typedMessage withFile:(AVFile *)file {
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

- (void)fillTypedMessageForLocationIfNeeded:(AVIMTypedMessage *)typedMessage {
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
               callback:(AVIMBooleanResultBlock)callback
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(false, aError);
        });
        
        return;
    }
    
    [client addOperationToInternalSerialQueue:^(AVIMClient *client) {
        
        BOOL isWillMessage = option.will;
        BOOL needReceipt = option.receipt;
        BOOL isTransientMessage = option.transient;
        AVIMMessagePriority messagePriority = option.priority;
        NSDictionary *pushData = option.pushData;
        
        AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
        
        genericCommand.cmd = AVIMCommandType_Direct;
        
        if (messagePriority > 0) {
            if (self.transient) {
                genericCommand.priority = messagePriority;
            } else {
                AVLoggerInfo(AVLoggerDomainIM, @"Message priority has no effect in non-transient conversation.");
            }
        }
        
        AVIMDirectCommand *directCommand = [[AVIMDirectCommand alloc] init];
        [genericCommand avim_addRequiredKeyWithCommand:directCommand];
        [genericCommand avim_addRequiredKeyForDirectMessageWithMessage:message transient:isTransientMessage];
        
        if (isWillMessage) {
            directCommand.will = YES;
        }
        if (needReceipt) {
            directCommand.r = YES;
        }
        if (pushData) {
            if (isTransientMessage || self.transient) {
                AVLoggerInfo(AVLoggerDomainIM, @"Push data cannot applied to transient message or transient conversation.");
            } else {
                NSError *error = nil;
                NSData  *data  = [NSJSONSerialization dataWithJSONObject:pushData options:0 error:&error];
                
                if (error) {
                    AVLoggerInfo(AVLoggerDomainIM, @"Push data cannot be serialize to JSON string. Error: %@.", error.localizedDescription);
                } else {
                    directCommand.pushData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                }
            }
        }
        if (message.mentionAll) {
            directCommand.mentionAll = YES;
        }
        if (message.mentionList.count) {
            directCommand.mentionPidsArray = [message.mentionList mutableCopy];
        }
        
        if (isTransientMessage) {
            
            LCIMProtobufCommandWrapper *commandWrapper = [[LCIMProtobufCommandWrapper alloc] init];
            
            commandWrapper.outCommand = genericCommand;
            
            [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
                
                if (commandWrapper.error) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        callback(false, commandWrapper.error);
                    });
                    
                    return;
                }
                
                if (!(commandWrapper.inCommand.ackMessage)) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        NSError *aError = ({
                            NSString *reason = @"Not get a ACK from In Command.";
                            NSDictionary *userInfo = @{ @"reason" : reason };
                            [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                code:0
                                            userInfo:userInfo];
                        });
                        
                        callback(false, aError);
                    });
                    
                    return;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    callback(true, nil);
                });
            }];
            
            [client sendCommandWrapper:commandWrapper];
            
        } else {
            
            genericCommand.needResponse = YES;
            [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
                
                AVIMDirectCommand *directOutCommand = outCommand.directMessage;
                AVIMMessage *message = outCommand.directMessage.message;
                
                if (error) {
                    message.status = AVIMMessageStatusFailed;
                } else {
                    message.status = AVIMMessageStatusSent;
                    
                    AVIMAckCommand *ackInCommand = inCommand.ackMessage;
                    message.sendTimestamp = ackInCommand.t;
                    message.messageId = ackInCommand.uid;
                    self.lastMessage = message;
                    if (client.messageQueryCacheEnabled) {
                        [[self messageCacheStore] insertOrUpdateMessage:message withBreakpoint:NO];
                    }
                    if (directOutCommand.r) {
                        [client stageMessage:message];
                    }
                    [self updateConversationAfterSendMessage:message];
                }
                [AVIMBlockHelper callBooleanResultBlock:callback error:error];
            }];
            
            [client sendCommand:genericCommand];
        }
    }];
}

- (AVIMGenericCommand *)patchCommandWithOldMessage:(AVIMMessage *)oldMessage
                                        newMessage:(AVIMMessage *)newMessage
{
    AVIMGenericCommand *command = [[AVIMGenericCommand alloc] init];

    command.needResponse = YES;
    command.cmd = AVIMCommandType_Patch;
    command.op = AVIMOpType_Modify;
    command.peerId = self.clientId;

    AVIMPatchItem *patchItem = [[AVIMPatchItem alloc] init];

    patchItem.cid = self.conversationId;
    patchItem.mid = oldMessage.messageId;
    patchItem.timestamp = oldMessage.sendTimestamp;
    patchItem.data_p = newMessage.payload;

    if (newMessage.mentionAll) {
        patchItem.mentionAll = newMessage.mentionAll;
    }
    if (newMessage.mentionList.count) {
        patchItem.mentionPidsArray = [newMessage.mentionList mutableCopy];
    }

    NSArray<AVIMPatchItem*> *patchesArray = @[patchItem];
    AVIMPatchCommand *patchMessage = [[AVIMPatchCommand alloc] init];

    patchMessage.patchesArray = [patchesArray mutableCopy];
    command.patchMessage = patchMessage;

    return command;
}

- (BOOL)containsMessage:(AVIMMessage *)message {
    if (!message.messageId)
        return NO;
    if (!message.conversationId)
        return NO;

    return [self.conversationId isEqualToString:message.conversationId];
}

- (void)didUpdateMessage:(AVIMMessage *)oldMessage
            toNewMessage:(AVIMMessage *)newMessage
            patchCommand:(AVIMPatchCommand *)command
{
    newMessage.messageId            = oldMessage.messageId;
    newMessage.clientId             = oldMessage.clientId;
    newMessage.localClientId        = oldMessage.localClientId;
    newMessage.conversationId       = oldMessage.conversationId;
    newMessage.sendTimestamp        = oldMessage.sendTimestamp;
    newMessage.readTimestamp        = oldMessage.readTimestamp;
    newMessage.deliveredTimestamp   = oldMessage.deliveredTimestamp;
    newMessage.offline              = oldMessage.offline;
    newMessage.status               = oldMessage.status;
    newMessage.updatedAt            = [NSDate dateWithTimeIntervalSince1970:command.lastPatchTime / 1000.0];

    LCIMMessageCache *messageCache = [self messageCache];
    [messageCache updateMessage:newMessage forConversationId:self.conversationId];
}

- (void)updateMessage:(AVIMMessage *)oldMessage
         toNewMessage:(AVIMMessage *)newMessage
             callback:(AVIMBooleanResultBlock)callback
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(false, aError);
        });
        
        return;
    }
    
    if (!newMessage) {
        NSError *error = [AVErrorUtils errorWithCode:kAVIMErrorMessageNotFound errorText:@"Cannot update a message to nil."];
        [AVUtils callBooleanResultBlock:callback error:error];
        return;
    }
    if (![self containsMessage:oldMessage]) {
        NSError *error = [AVErrorUtils errorWithCode:kAVIMErrorMessageNotFound errorText:@"Cannot find a message to update."];
        [AVUtils callBooleanResultBlock:callback error:error];
        return;
    }

    AVIMGenericCommand *patchCommand = [self patchCommandWithOldMessage:oldMessage
                                                             newMessage:newMessage];

    patchCommand.callback = ^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
        if (error) {
            [AVUtils callBooleanResultBlock:callback error:error];
            return;
        }
        [self didUpdateMessage:oldMessage toNewMessage:newMessage patchCommand:inCommand.patchMessage];
        [AVUtils callBooleanResultBlock:callback error:nil];
    };

    [client sendCommand:patchCommand];
}

- (void)recallMessage:(AVIMMessage *)oldMessage
             callback:(void (^)(BOOL, NSError * _Nullable, AVIMRecalledMessage * _Nullable))callback
{
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(false, aError, nil);
        });
        
        return;
    }
    
    /* arg check */
    ///
    NSString *conversationId = self.conversationId;
    
    NSString *oldMessageId = oldMessage ? oldMessage.messageId : nil;
    
    NSString *errReason = nil;
    
    if (!conversationId) {
        
        errReason = @"`conversationId` is invalid.";
        
    } else if (!oldMessage || !oldMessageId) {
        
        errReason = @"`oldMessage` is invalid.";
        
    } else if (callback == nil) {
        
        errReason = @"`callback` is invalid.";
    }
    
    if (errReason) {
        
        NSString *reason = errReason;
        
        NSDictionary *info = @{ @"reason" : reason };
        
        NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                              code:0
                                          userInfo:info];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            callback(false, aError, nil);
        });
        
        return;
    }
    ///
    
    AVIMGenericCommand *(^cmdOfRecall)(void) = ^AVIMGenericCommand *(void) {
        
        AVIMGenericCommand *command = [[AVIMGenericCommand alloc] init];
        
        command.needResponse = YES;
        command.cmd = AVIMCommandType_Patch;
        command.op = AVIMOpType_Modify;
        command.peerId = self.clientId;
        
        AVIMPatchItem *patchItem = [[AVIMPatchItem alloc] init];
        
        patchItem.cid = conversationId;
        patchItem.mid = oldMessageId;
        patchItem.timestamp = oldMessage.sendTimestamp;
        patchItem.recall = true;
        
        NSArray<AVIMPatchItem*> *patchesArray = @[patchItem];
        AVIMPatchCommand *patchMessage = [[AVIMPatchCommand alloc] init];
        
        patchMessage.patchesArray = [patchesArray mutableCopy];
        command.patchMessage = patchMessage;
        
        return command;
    };
    
    AVIMGenericCommand *patch_modify_cmd = cmdOfRecall();
    
    patch_modify_cmd.callback = ^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
        
        if (error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(false, error, nil);
            });
            
            return;
        }
        
        AVIMRecalledMessage *recalledMessage = [[AVIMRecalledMessage alloc] init];
        
        [self didUpdateMessage:oldMessage
                  toNewMessage:recalledMessage
                  patchCommand:inCommand.patchMessage];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            callback(true, nil, recalledMessage);
        });
    };
    
    [client sendCommand:patch_modify_cmd];
}

- (void)updateConversationAfterSendMessage:(AVIMMessage *)message {
    NSDate *messageSentAt = [NSDate dateWithTimeIntervalSince1970:(message.sendTimestamp / 1000.0)];
    self.lastMessageAt = messageSentAt;
    [self.conversationCache updateConversationForLastMessageAt:messageSentAt conversationId:self.conversationId];
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
    return self.imClient.conversationCache;
}

- (void)cacheContinuousMessages:(NSArray *)messages
                    plusMessage:(AVIMMessage *)message
{
    NSMutableArray *cachedMessages = [NSMutableArray array];
    
    if (messages) { [cachedMessages addObjectsFromArray:messages]; }
    
    if (message) { [cachedMessages addObject:message]; }
    
    [self cacheContinuousMessages:cachedMessages withBreakpoint:YES];

    [self messagesDidCache];
}

- (void)cacheContinuousMessages:(NSArray *)messages withBreakpoint:(BOOL)breakpoint {
    if (breakpoint) {
        [[self messageCache] addContinuousMessages:messages forConversationId:self.conversationId];
    } else {
        [[self messageCacheStore] insertOrUpdateMessages:messages];
    }

    [self messagesDidCache];
}

- (void)messagesDidCache {
    AVIMMessage *lastMessage = [[self queryMessagesFromCacheWithLimit:1] firstObject];
    [self tryUpdateKey:@"lastMessage" toValue:lastMessage];
}

- (void)removeCachedConversation {
    [[self conversationCache] removeConversationForId:self.conversationId];
}

- (void)removeCachedMessages {
    [[self messageCacheStore] cleanCache];
}

- (void)addMessageToCache:(AVIMMessage *)message {
    message.clientId = self.imClient.clientId;
    message.conversationId = _conversationId;

    [[self messageCacheStore] insertOrUpdateMessage:message];
}

- (void)removeMessageFromCache:(AVIMMessage *)message {
    [[self messageCacheStore] deleteMessage:message];
}

#pragma mark - Message Query

- (void)sendACKIfNeeded:(NSArray *)messages
{
    AVIMClient *client = self.imClient;
    
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
    AVIMClient *client = self.imClient;
    
    if (!client) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`imClient` is invalid.";
                NSDictionary *userInfo = @{ @"reason" : reason };
                [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                    code:0
                                userInfo:userInfo];
            });
            
            callback(nil, aError);
        });
        
        return;
    }
    
    AVIMLogsCommand *logsOutCommand = genericCommand.logsMessage;
    dispatch_async(client.internalSerialQueue, ^{
        [genericCommand setCallback:^(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error) {
            if (!error) {
                AVIMLogsCommand *logsInCommand = inCommand.logsMessage;
                AVIMLogsCommand *logsOutCommand = outCommand.logsMessage;
                NSArray *logs = [logsInCommand.logsArray copy];
                NSMutableArray *messages = [[NSMutableArray alloc] init];
                for (AVIMLogItem *logsItem in logs) {
                    AVIMMessage *message = nil;
                    id data = [logsItem data_p];
                    if (![data isKindOfClass:[NSString class]]) {
                        AVLoggerError(AVOSCloudIMErrorDomain, @"Received an invalid message.");
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
                self.lastMessage = messages.lastObject;
                [self postprocessMessages:messages];
                [self sendACKIfNeeded:messages];
                
                [AVIMBlockHelper callArrayResultBlock:callback array:messages error:nil];
            } else {
                [AVIMBlockHelper callArrayResultBlock:callback array:nil error:error];
            }
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
    genericCommand.peerId = self.imClient.clientId;
    
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
    genericCommand.peerId = self.imClient.clientId;
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
         
         if (!self.imClient.messageQueryCacheEnabled) {
             
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
    
    BOOL socketOpened = (self.imClient.threadUnsafe_status == AVIMClientStatusOpened);
    
    /* if disable query from cache, then only query from server. */
    if (!self.imClient.messageQueryCacheEnabled) {
        
        /* connection is not open, callback error. */
        if (!socketOpened) {
            
            NSError *error = [AVIMErrorUtil errorWithCode:kAVIMErrorClientNotOpen
                                                   reason:@"Client not open when query messages from server."];
            
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
        
        NSDictionary *info = @{ @"reason" : reason };
        
        NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                              code:0
                                          userInfo:info];
        
        [AVIMBlockHelper callArrayResultBlock:callback
                                        array:nil
                                        error:aError];
        
        return;
    }
    
    limit     = [self.class validLimit:limit];
    timestamp = [self.class validTimestamp:timestamp];

    /*
     * Firstly, if message query cache is not enabled, just forward query request.
     */
    if (!self.imClient.messageQueryCacheEnabled) {
        
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
        BOOL socketOpened = (self.imClient.threadUnsafe_status == AVIMClientStatusOpened);
        
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
    genericCommand.peerId = self.imClient.clientId;
    genericCommand.logsMessage = logsCommand;

    [self queryMessagesFromServerWithCommand:genericCommand callback:callback];
}

- (void)postprocessMessages:(NSArray *)messages {
    for (AVIMMessage *message in messages) {
        message.status = AVIMMessageStatusSent;
        message.localClientId = self.imClient.clientId;
    }
}

- (void)queryMediaMessagesFromServerWithType:(AVIMMessageMediaType)type
                                       limit:(NSUInteger)limit
                               fromMessageId:(NSString *)messageId
                               fromTimestamp:(int64_t)timestamp
                                    callback:(void (^)(NSArray<AVIMMessage *> *, NSError *))callback
{
    AVIMClient *client = self.imClient;
    
    NSString *convId = self.conversationId;
    
    NSString *errReason = nil;
    
    if (!convId) {
        
        errReason = @"`conversationId` is invalid.";
        
    } else if (!client) {
        
        errReason = @"`imClient` is invalid.";;
    }
    
    if (errReason) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSDictionary *info = @{ @"reason" : errReason };
            
            NSError *aError = [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                                  code:0
                                              userInfo:info];
            
            callback(nil, aError);
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
                    
                    AVLoggerError(AVOSCloudIMErrorDomain, @"Received an invalid message.");
                    
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

// MARK: - Conv Updated

- (void)mergeConvUpdatedMessage:(NSDictionary *)convUpdatedMessage
{
    [self internalSyncLock:^{
        
        AVIMConversation_MergeUpdatedDicIntoOriginDic(convUpdatedMessage, self->_rawJSONData);
    }];
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
    if (!ignoringCache) {
        
        __block NSArray<AVIMConversationMemberInfo *> *memberInfos = nil;
        
        [self internalSyncLock:^{
            
            if (self->_memberInfoTable) {
                
                memberInfos = self->_memberInfoTable.allValues;
            }
        }];
        
        if (memberInfos) {
            
            [self invokeInSpecifiedQueue:^{
                
                callback(memberInfos, nil);
            }];
            
            return;
        }
    }
    
    AVIMClient *client = self.imClient;
    NSString *clientId = client.clientId;
    NSString *conversationId = self.conversationId;
    
    if (!client || !clientId || !conversationId) {
        
        [self invokeInSpecifiedQueue:^{
            
            NSError *error = nil;

            if (!conversationId) {
                
                error = AVIMConversation_ParameterInvalidError(@"conversationId invalid.");
                
            } else {
                
                error = AVIMConversation_ParameterInvalidError(@"imClient invalid.");
            }
            
            callback(nil, error);
        }];
        
        return;
    }
    
    NSError *JSONSerializationError = nil;
    
    NSData *whereData = [NSJSONSerialization dataWithJSONObject:@{ @"cid" : conversationId } options:0 error:&JSONSerializationError];
    
    if (JSONSerializationError) {
        
        [self invokeInSpecifiedQueue:^{
            
            callback(nil, JSONSerializationError);
        }];
        
        return;
    }
    
    [client getSessionTokenWithForcingRefresh:forcingRefreshIMSessionToken callback:^(NSString *sessionToken, NSError *error) {
        
        NSParameterAssert(sessionToken);
        
        if (error) {
            
            [self invokeInSpecifiedQueue:^{
                
                callback(nil, error);
            }];
            
            return;
        }
        
        AVPaasClient *paasClient = self.paasClient;
        
        NSURLRequest *request = ({
            
            NSString *whereString = [[NSString alloc] initWithData:whereData encoding:NSUTF8StringEncoding];
            NSDictionary *parameters = nil;
            if (whereString) {
                parameters = @{ @"client_id" : clientId, @"where" : whereString };
            }
            [paasClient requestWithPath:@"classes/_ConversationMemberInfo"
                                 method:@"GET"
                                headers:@{ @"X-LC-IM-Session-Token" : sessionToken }
                             parameters:parameters];
        });
        
        [paasClient performRequest:request success:^(NSHTTPURLResponse *response, id responseObject) {
            
            if ([NSDictionary lc__checkingType:responseObject]) {
                
                NSArray *memberInfoJSONs = [NSArray lc__decodingDictionary:responseObject key:@"results"];
                
                if (!memberInfoJSONs) {
                    
                    [self invokeInSpecifiedQueue:^{
                        
                        callback(@[], nil);
                    }];
                    
                } else {
                    
                    NSMutableArray<AVIMConversationMemberInfo *> *memberInfos = [NSMutableArray arrayWithCapacity:memberInfoJSONs.count];
                    NSMutableDictionary<NSString *, AVIMConversationMemberInfo *> *memberInfoTable = [NSMutableDictionary dictionaryWithCapacity:memberInfoJSONs.count];
                    
                    for (id JSON in memberInfoJSONs) {
                        
                        if ([NSDictionary lc__checkingType:JSON]) {
                            
                            AVIMConversationMemberInfo *memberInfo = [[AVIMConversationMemberInfo alloc] initWithJSON:JSON conversation:self];
                            
                            [memberInfos addObject:memberInfo];
                            
                            NSString *memberId = memberInfo.memberId;
                            if (memberId) {
                                [memberInfoTable setObject:memberInfo forKey:memberId];
                            }
                        }
                    }
                    
                    [self internalSyncLock:^{
                        
                        self->_memberInfoTable = memberInfoTable;
                    }];
                    
                    [self invokeInSpecifiedQueue:^{
                        
                        callback(memberInfos, nil);
                    }];
                }
                
            } else {
                
                [self invokeInSpecifiedQueue:^{
                    
                    NSError *aError = ({
                        NSString *reason = @"response invalid.";
                        NSDictionary *userInfo = @{ @"reason" : reason };
                        [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                            code:0
                                        userInfo:userInfo];
                    });
                    
                    callback(nil, aError);
                }];
            }
            
        } failure:^(NSHTTPURLResponse *response, id responseObject, NSError *error) {
            
            if ([NSDictionary lc__checkingType:responseObject] &&
                [responseObject[@"code"] integerValue] == kLC_Code_SessionTokenExpired &&
                recursionCount < 3) {
                
                [self getAllMemberInfoWithIgnoringCache:ignoringCache
                           forcingRefreshIMSessionToken:true
                                         recursionCount:(recursionCount + 1)
                                               callback:callback];
                
            } else {
                
                [self invokeInSpecifiedQueue:^{
                    
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
        
        __block NSDictionary<NSString *, AVIMConversationMemberInfo *> *memberInfoTable = nil;
        
        [self internalSyncLock:^{
            
            if (self->_memberInfoTable) {
                
                memberInfoTable = self->_memberInfoTable.copy;
            }
        }];
        
        if (memberInfoTable) {
            
            [self invokeInSpecifiedQueue:^{
                
                callback(memberInfoTable[memberId], nil);
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
    AVIMClient *client = self.imClient;
    NSString *conversationId = self.conversationId;
    NSString *role_string = AVIMConversationMemberInfo_StringFromRole(role);
    
    if (!client || !conversationId) {
        
        [self invokeInSpecifiedQueue:^{
            
            NSError *error = nil;
            
            if (!conversationId) {
                
                error = AVIMConversation_ParameterInvalidError(@"conversationId invalid.");
                
            } else {
                
                error = AVIMConversation_ParameterInvalidError(@"imClient invalid.");
            }
            
            callback(nil, error);
        }];
        
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        AVIMConvMemberInfo *convMemberInfo = [AVIMConvMemberInfo new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_MemberInfoUpdate;
        outCommand.convMessage = convCommand;
        
        convCommand.cid = conversationId;
        convCommand.targetClientId = memberId;
        convCommand.info = convMemberInfo;
        
        convMemberInfo.pid = memberId;
        convMemberInfo.role = role_string;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        [self invokeInSpecifiedQueue:^{
            
            if (commandWrapper.error) {
                
                callback(false, commandWrapper.error);
                
                return;
            }
            
            __block AVIMConversationMemberInfo *memberInfo = nil;
            
            [self internalSyncLock:^{
                
                if (self->_memberInfoTable) {
                    
                    memberInfo = self->_memberInfoTable[memberId];
                }
            }];
            
            if (memberInfo) {
                
                [memberInfo updateRawJSONDataWithKey:@"role" object:role_string];
            }
            
            callback(true, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

- (void)process_member_info_changed:(AVIMGenericCommand *)inCommand
{
    AVIMConvCommand *convCommand = inCommand.convMessage;
    AVIMConvMemberInfo *memberInfoCommand = convCommand.info;
    
    NSString *memberId = memberInfoCommand.pid;
    NSString *role = memberInfoCommand.role;
    
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
        
        [memberInfo updateRawJSONDataWithKey:@"role" object:role];
    }
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
    AVIMClient *client = self.imClient;
    NSString *conversationId = self.conversationId;
    
    if (!client || !conversationId) {
        
        [self invokeInSpecifiedQueue:^{
            
            NSError *error = nil;
            
            if (!conversationId) {
                
                error = AVIMConversation_ParameterInvalidError(@"conversationId invalid.");
                
            } else {
                
                error = AVIMConversation_ParameterInvalidError(@"imClient invalid.");
            }
            
            callback(nil, nil, error);
        }];
        
        return;
    }
    
    AVIMSignatureAction action = (isBlockAction ? AVIMSignatureActionBlock : AVIMSignatureActionUnblock);
    
    [client getSignatureWithConversationId:conversationId action:action actionOnClientIds:memberIds callback:^(AVIMSignature *signature) {
        
        if (signature && signature.error) {
            
            [self invokeInSpecifiedQueue:^{
                
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
            
            if (signature && signature.signature && signature.timestamp && signature.nonce) {
                
                blacklistCommand.s = signature.signature;
                blacklistCommand.t = signature.timestamp;
                blacklistCommand.n = signature.nonce;
            }
            
            blacklistCommand.srcCid = conversationId;
            blacklistCommand.toPidsArray = memberIds.mutableCopy;
            
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = outCommand;
            
            commandWrapper;
        });
        
        [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
            
            [self invokeInSpecifiedQueue:^{
                
                if (commandWrapper.error) {
                    
                    callback(nil, nil, commandWrapper.error);
                    
                } else {
                    
                    AVIMBlacklistCommand *cmd = commandWrapper.inCommand.blacklistMessage;
                    
                    NSArray<NSString *> *allowedPids = cmd.allowedPidsArray ?: @[];
                    
                    NSMutableArray<AVIMOperationFailure *> *failedPids = [NSMutableArray array];
                    
                    for (AVIMErrorCommand *errorCommand in cmd.failedPidsArray) {
                        AVIMOperationFailure *failedResult = [AVIMOperationFailure new];
                        failedResult.code = errorCommand.code;
                        failedResult.reason = errorCommand.reason;
                        failedResult.clientIds = errorCommand.pidsArray;
                        [failedPids addObject:failedResult];
                    }
                    
                    callback(allowedPids, failedPids, nil);
                }
            }];
        }];
        
        [client sendCommandWrapper:commandWrapper];
    }];
}

- (void)queryBlockedMembersWithLimit:(NSInteger)limit
                                next:(NSString * _Nullable)next
                            callback:(void (^)(NSArray<NSString *> *, NSString *, NSError *))callback
{
    AVIMClient *client = self.imClient;
    NSString *conversationId = self.conversationId;
    
    if (!client || !conversationId) {
        
        [self invokeInSpecifiedQueue:^{
            
            NSError *error = nil;
            
            if (!conversationId) {
                
                error = AVIMConversation_ParameterInvalidError(@"conversationId invalid.");
                
            } else {
                
                error = AVIMConversation_ParameterInvalidError(@"imClient invalid.");
            }
            
            callback(nil, nil, error);
        }];
        
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMBlacklistCommand *blacklistCommand = [AVIMBlacklistCommand new];
        
        outCommand.cmd = AVIMCommandType_Blacklist;
        outCommand.op = AVIMOpType_Query;
        outCommand.blacklistMessage = blacklistCommand;
        
        blacklistCommand.srcCid = conversationId;
        blacklistCommand.limit = ({
            int32_t number;
            if (limit <= 0) {
                number = 50;
            }
            else if (limit > 100) {
                number = 100;
            }
            else {
                number = (int32_t)limit;
            }
            number;
        });
        blacklistCommand.next = ([next isEqualToString:@""] ? nil : next);
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        [self invokeInSpecifiedQueue:^{
            
            if (commandWrapper.error) {
                
                callback(nil, nil, commandWrapper.error);
                
            } else {
                
                AVIMBlacklistCommand *cmd = commandWrapper.inCommand.blacklistMessage;
                
                callback(cmd.blockedPidsArray, cmd.next, nil);
            }
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
    AVIMClient *client = self.imClient;
    NSString *conversationId = self.conversationId;
    
    if (!client || !conversationId) {
        
        [self invokeInSpecifiedQueue:^{
            
            NSError *error = nil;
            
            if (!conversationId) {
                
                error = AVIMConversation_ParameterInvalidError(@"conversationId invalid.");
                
            } else {
                
                error = AVIMConversation_ParameterInvalidError(@"imClient invalid.");
            }
            
            callback(nil, nil, error);
        }];
        
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = (isMuteAction ? AVIMOpType_AddShutup : AVIMOpType_RemoveShutup);
        outCommand.convMessage = convCommand;
        
        convCommand.cid = conversationId;
        convCommand.mArray = memberIds.mutableCopy;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        [self invokeInSpecifiedQueue:^{
            
            if (commandWrapper.error) {
                
                callback(nil, nil, commandWrapper.error);
                
            } else {
                
                AVIMConvCommand *cmd = commandWrapper.inCommand.convMessage;
                
                NSArray<NSString *> *allowedPids = cmd.allowedPidsArray ?: @[];
                
                NSMutableArray<AVIMOperationFailure *> *failedPids = [NSMutableArray array];
                
                for (AVIMErrorCommand *errorCommand in cmd.failedPidsArray) {
                    AVIMOperationFailure *failedResult = [AVIMOperationFailure new];
                    failedResult.code = errorCommand.code;
                    failedResult.reason = errorCommand.reason;
                    failedResult.clientIds = errorCommand.pidsArray;
                    [failedPids addObject:failedResult];
                }
                
                callback(allowedPids, failedPids, nil);
            }
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

- (void)queryMutedMembersWithLimit:(NSInteger)limit
                              next:(NSString * _Nullable)next
                          callback:(void (^)(NSArray<NSString *> *, NSString *, NSError *))callback
{
    AVIMClient *client = self.imClient;
    NSString *conversationId = self.conversationId;
    
    if (!client || !conversationId) {
        
        [self invokeInSpecifiedQueue:^{
            
            NSError *error = nil;
            
            if (!conversationId) {
                
                error = AVIMConversation_ParameterInvalidError(@"conversationId invalid.");
                
            } else {
                
                error = AVIMConversation_ParameterInvalidError(@"imClient invalid.");
            }
            
            callback(nil, nil, error);
        }];
        
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_QueryShutup;
        outCommand.convMessage = convCommand;
        
        convCommand.cid = conversationId;
        convCommand.limit = ({
            int32_t number;
            if (limit <= 0) {
                number = 50;
            }
            else if (limit > 100) {
                number = 100;
            }
            else {
                number = (int32_t)limit;
            }
            number;
        });
        convCommand.next = ([next isEqualToString:@""] ? nil : next);
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        [self invokeInSpecifiedQueue:^{
            
            if (commandWrapper.error) {
                
                callback(nil, nil, commandWrapper.error);
                
            } else {
                
                AVIMConvCommand *cmd = commandWrapper.inCommand.convMessage;
                
                callback(cmd.mArray, cmd.next, nil);
            }
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

#pragma mark - Keyed Conversation

- (AVIMKeyedConversation *)keyedConversation
{
    AVIMKeyedConversation *keyedConversation = [[AVIMKeyedConversation alloc] init];
    
    keyedConversation.conversationId = self.conversationId;
    keyedConversation.clientId       = self.imClient.clientId;
    keyedConversation.creator        = self.creator;
    keyedConversation.createAt       = self.createAt;
    keyedConversation.updateAt       = self.updateAt;
    keyedConversation.lastMessageAt  = self.lastMessageAt;
    keyedConversation.lastMessage    = self.lastMessage;
    keyedConversation.name           = self.name;
    keyedConversation.members        = self.members;
    keyedConversation.attributes     = self.attributes;
    
    keyedConversation.muted        = self.muted;
    keyedConversation.transient    = self.transient;
    keyedConversation.system       = self.system;
    keyedConversation.temporary    = self.temporary;
    keyedConversation.temporaryTTL = self.temporaryTTL;
    keyedConversation.unique       = self.unique;
    
    if (self.uniqueId) {
        
        keyedConversation.uniqueId = self.uniqueId;
    }
    
    NSDictionary *rawJSONData = [self rawJSONDataCopy];
    
    keyedConversation.properties = [rawJSONData copy];
    keyedConversation.rawDataDic = [rawJSONData copy];
    
    return keyedConversation;
}

- (void)setKeyedConversation:(AVIMKeyedConversation *)keyedConversation
{
    self.conversationId    = keyedConversation.conversationId;
    self.creator           = keyedConversation.creator;
    self.createAt          = keyedConversation.createAt;
    self.updateAt          = keyedConversation.updateAt;
    self.lastMessageAt     = keyedConversation.lastMessageAt;
    self.lastMessage       = keyedConversation.lastMessage;
    self.name              = keyedConversation.name;
    self.members           = keyedConversation.members;
    self.attributes        = keyedConversation.attributes;
    
    self.muted        = keyedConversation.muted;
    self.transient    = keyedConversation.transient;
    self.system       = keyedConversation.system;
    self.temporary    = keyedConversation.temporary;
    self.temporaryTTL = keyedConversation.temporaryTTL;
    self.unique       = keyedConversation.unique;
    
    if (keyedConversation.uniqueId) {
        
        self.uniqueId = keyedConversation.uniqueId;
    }
    
    if (keyedConversation.properties) {
        
        [self setRawJSONData:keyedConversation.properties.mutableCopy];
        
    } else if (keyedConversation.rawDataDic) {
        
        [self setRawJSONData:keyedConversation.rawDataDic.mutableCopy];
    }
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


- (void)update:(NSDictionary *)attributes callback:(AVIMBooleanResultBlock)callback
{
    [self updateWithDictionary:attributes callback:^(BOOL succeeded, NSError *error) {
        
        if (error) {
            
            [self invokeInSpecifiedQueue:^{
                
                callback(false, error);
            }];
            
            return;
        }
        
        [self removeCachedConversation];
        
        [self internalSyncLock:^{
            
            AVIMConversation_MergeUpdatedDicIntoOriginDic(attributes, self->_rawJSONData);
        }];
        
        [self invokeInSpecifiedQueue:^{
            
            callback(true, nil);
        }];
    }];
}

- (void)markAsReadInBackground
{
    AVIMClient *client = self.imClient;
    
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
