//
//  LCIMClient.m
//  ChatApp
//
//  Created by Qihe Bian on 12/10/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMClient.h"
#import "LCUser.h"
#import "SQPersist.h"
#import "LCConversationEntity.h"

static id instance = nil;
static BOOL initialized = NO;
static NSString *databaseName = nil;

@interface LCIMClient () <AVIMClientDelegate, AVIMSignatureDataSource> {
    AVIMClient *_imClient;
    SQPDatabase *_database;
    NSMutableArray *_conversations;

}

@end
@implementation LCIMClient
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    if (!initialized) {
        [instance commonInit];
    }
    return instance;
}

- (NSArray *)conversations {
    return _conversations;
}

- (NSString *)databaseName {
    if (!databaseName) {
//        NSString *cacheDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *userId = [[LCUser currentUser] objectId];
        databaseName = [NSString stringWithFormat:@"chat_%@.db", userId];
//        databasePath = [cacheDirectory stringByAppendingPathComponent:dbname];
    }
    return databaseName;
}

- (instancetype)init {
    if ((self = [super init])) {
        AVIMClient *imClient = [[AVIMClient alloc] init];
        imClient.delegate = self;
        imClient.signatureDataSource = self;
        _imClient = imClient;
        
        _database = [SQPDatabase sharedInstance];
//        _database.logRequests = YES;
//        _database.logPropertyScan = YES;
        _database.addMissingColumns = YES;

        _conversations = [[NSMutableArray alloc] init];
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    [_database setupDatabaseWithName:[self databaseName]];
    NSLog(@"DB path: %@ ", [_database getDdPath]);

    initialized = YES;
}

- (void)close {
    [_database closeDatabase];
    databaseName = nil;
    [_conversations removeAllObjects];
    [_imClient closeWithCallback:nil];
    initialized = NO;
}

- (void)addConversationIfNotExists:(AVIMConversation *)conversation {
    if (conversation && ![_conversations containsObject:conversation]) {
        LCConversationEntity *entity = [LCConversationEntity SQPFetchOneByAttribut:@"conversationId" withValue:conversation.conversationId];
        if (!entity) {
            entity = [LCConversationEntity SQPCreateEntity];
            entity.conversationId = conversation.conversationId;
        }
        entity.conversationId = conversation.conversationId;
        entity.name = conversation.name;
        entity.members = conversation.members;
        [entity SQPSaveEntity];
        [_conversations addObject:conversation];
    }
}

- (void)saveMessageToDatabase:(AVIMMessage *)message callback:(AVBooleanResultBlock)callback {
    __block LCUser *user = [LCUser userById:message.clientId];
    NSString *text = message.content;
    if ([message isKindOfClass:[AVIMTypedMessage class]]) {
        AVIMTypedMessage *typedMessage = (AVIMTypedMessage *)message;
        text = typedMessage.text;
    }
    if (!user) {
        [LCUser queryUserWithId:message.clientId callback:^(AVObject *object, NSError *error) {
            if (object) {
                user = (LCUser *)object;
                LCMessageEntity *entity = [LCMessageEntity SQPCreateEntity];
                entity.text = text;
                entity.sender = user.nickname;
                entity.clientId = message.clientId;
                entity.date = [NSDate dateWithTimeIntervalSince1970:message.sendTimestamp/1000.0];
                entity.messageId = message.messageId;
                entity.conversationId = message.conversationId;
                [entity SQPSaveEntity];
                callback(YES, nil);
            }
            callback(NO, error);
        }];
    } else {
        LCMessageEntity *entity = [LCMessageEntity SQPCreateEntity];
        entity.text = text;
        entity.sender = user.nickname;
        entity.clientId = message.clientId;
        entity.date = [NSDate dateWithTimeIntervalSince1970:message.sendTimestamp/1000.0];
        entity.messageId = message.messageId;
        entity.conversationId = message.conversationId;
        [entity SQPSaveEntity];
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(YES, nil);
        });
    }
}

- (void)clearDataAndClose {
    [_database removeDatabase];
    [self close];
}

- (void)openWithCallback:(AVIMBooleanResultBlock)callback {
    [_imClient openWithClientId:[[LCUser currentUser] objectId] callback:callback];
//    [_im openWithClientId:[[LCUser currentUser] objectId] security:NO callback:^(BOOL succeeded, NSError *error) {
//        if (succeeded) {
//            NSLog(@"IM open success!");
//            
//            [self createConversationWithUserId:@"ufosky3" callback:^(AVIMConversation *conversation, NSError *error) {
//                NSLog(@"conversation create success!");
//            }];
//        } else {
//            NSLog(@"error:%@", error);
//        }
//    }];
}

- (void)createConversationWithUserId:(NSString *)userId callback:(AVIMConversationResultBlock)callback {
  [_imClient createConversationWithName:nil clientIds:@[userId] attributes:@{@"type":@(LCConversationTypeSingle)} options:AVIMConversationOptionNone callback:^(AVIMConversation *conversation, NSError *error) {
        [self addConversationIfNotExists:conversation];
        callback(conversation, error);
    }];
}

- (void)createConversationWithUserIds:(NSArray *)userIds callback:(AVIMConversationResultBlock)callback {
    if (userIds.count == 1) {
        NSString *userId = [userIds objectAtIndex:0];
        [self createConversationWithUserId:userId callback:callback];
    } else {
        [_imClient createConversationWithName:nil clientIds:userIds attributes:@{@"type":@(LCConversationTypeGroup)} options:AVIMConversationOptionNone callback:^(AVIMConversation *conversation, NSError *error) {
            [self addConversationIfNotExists:conversation];
            callback(conversation, error);
        }];
    }
}

- (void)fetchOrCreateConversationWithUserId:(NSString *)userId callback:(AVIMConversationResultBlock)callback {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [array addObject:_imClient.clientId];
    [array addObject:userId];
  AVIMConversationQuery *query = [_imClient conversationQuery];
  [query whereKey:kAVIMKeyMember containedIn:array];
  [query whereKey:kAVIMKeyMember sizeEqualTo:array.count];
  [query findConversationsWithCallback:^(NSArray *objects, NSError *error) {
    if (objects.count > 0) {
      AVIMConversation *conversation = [objects objectAtIndex:0];
      [self addConversationIfNotExists:conversation];
      callback(conversation, nil);
    } else if (!error) {
      [self createConversationWithUserId:userId callback:callback];
    } else {
      callback(nil, error);
    }
  }];
//    [_imClient queryConversationsWithClientIds:array skip:0 limit:0 callback:^(NSArray *objects, NSError *error) {
//        if (objects.count > 0) {
//            AVIMConversation *conversation = [objects objectAtIndex:0];
//            [self addConversationIfNotExists:conversation];
//            callback(conversation, nil);
//        } else if (!error) {
//            [self createConversationWithUserId:userId callback:callback];
//        } else {
//            callback(nil, error);
//        }
//    }];
}

- (void)queryConversationsWithCallback:(AVIMArrayResultBlock)callback {
    NSMutableArray *entities = [LCConversationEntity SQPFetchAll];
    NSMutableArray *conversationIds = [[NSMutableArray alloc] init];
    for (LCConversationEntity *entity in entities) {
        NSString *conversationId = entity.conversationId;
        if (conversationId) {
            [conversationIds addObject:conversationId];
        }
    }
  
  AVIMConversationQuery *query = [_imClient conversationQuery];
  [query whereKey:kAVIMKeyConversationId containedIn:conversationIds];
  [query findConversationsWithCallback:^(NSArray *objects, NSError *error) {
  
//    [_imClient queryConversationByIds:conversationIds callback:^(NSArray *objects, NSError *error) {
        [_database beginTransaction];
        for (AVIMConversation *conversation in objects) {
//            LCConversationEntity *entity = [LCConversationEntity SQPFetchOneByAttribut:@"conversationId" withValue:conversation.conversationId];
//            if (!entity) {
//                entity = [LCConversationEntity SQPCreateEntity];
//                entity.conversationId = conversation.conversationId;
//            }
//            entity.name = conversation.name;
//            entity.members = conversation.members;
//            [entity SQPSaveEntity];
            [self addConversationIfNotExists:conversation];
        }
        [_database commitTransaction];
        callback(objects, error);
    }];
}

- (void)updateConversation:(AVIMConversation *)conversation withName:(NSString *)name attributes:(NSDictionary *)attributes callback:(AVIMBooleanResultBlock)callback {
    AVIMConversationUpdateBuilder *builder = [conversation newUpdateBuilder];
    builder.name = name;
    builder.attributes = attributes;
    [conversation sendUpdate:[builder dictionary] callback:^(BOOL succeeded, NSError *error) {
        NSLog(@"name:%@", conversation.name);
        NSLog(@"attributes:%@", conversation.attributes);
    }];
}

- (void)addUserIds:(NSArray *)userIds toConversation:(AVIMConversation *)conversation callback:(AVIMBooleanResultBlock)callback {
    [conversation addMembersWithClientIds:userIds callback:^(BOOL succeeded, NSError *error) {
        callback(succeeded, error);
    }];
}

- (void)sendText:(NSString *)text conversation:(AVIMConversation *)conversation callback:(AVIMBooleanResultBlock)callback {
//    AVIMLocationMessage *message = [AVIMLocationMessage messageWithText:text latitude:1 longitude:1 attributes:@{@"a":@"test"}];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"head_default@2x" ofType:@"png"];
    AVIMImageMessage *message = [AVIMImageMessage messageWithText:text attachedFilePath:path attributes:@{@"a":@"test"}];
//    AVIMTextMessage *message = [[AVIMTextMessage alloc] init];
//    message.text = text;
//    AVIMMessage *message = [AVIMMessage messageWithContent:text];
    [conversation sendMessage:message callback:^(BOOL succeeded, NSError *error) {
        [self saveMessageToDatabase:message callback:callback];
    }];
}

- (NSArray *)messagesForConversationId:(NSString *)conversationId {
    NSString *where = [NSString stringWithFormat:@"conversationId = '%@'", conversationId];
    NSMutableArray *messages = [LCMessageEntity SQPFetchAllWhere:where orderBy:@"date"];
    return messages;
}

- (LCMessageEntity *)latestMessageForConversationId:(NSString *)conversationId {
    NSString *where = [NSString stringWithFormat:@"conversationId = '%@'", conversationId];
    NSMutableArray *messages = [LCMessageEntity SQPFetchAllWhere:where orderBy:@"date DESC" pageIndex:0 itemsPerPage:1];
    if (messages.count > 0) {
        return [messages objectAtIndex:0];
    } else {
        return nil;
    }
}

#pragma mark - AVIMDelegate
- (void)imClientPaused:(AVIMClient *)imClient {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
}

- (void)imClientResuming:(AVIMClient *)imClient {
    NSLog(@"%s", __PRETTY_FUNCTION__);

}

- (void)imClientResumed:(AVIMClient *)imClient {
    NSLog(@"%s", __PRETTY_FUNCTION__);

}

- (void)imClient:(AVIMClient *)imClient error:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);

}

/*!
 接收到新的消息。
 @param conversation － 所属对话
 @param message - 具体的消息
 @return None.
 */
- (void)conversation:(AVIMConversation *)conversation didReceiveCommonMessage:(AVIMMessage *)message {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (![_conversations containsObject:conversation]) {
      AVIMConversationQuery *query = [_imClient conversationQuery];
      [query getConversationById:conversation.conversationId callback:^(AVIMConversation *conversation, NSError *error) {
            if (!error) {
                [self addConversationIfNotExists:conversation];
                [self saveMessageToDatabase:message callback:^(BOOL succeeded, NSError *error) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:LC_NOTIFICATION_MESSAGE_UPDATED object:conversation];
                }];
            }
        }];
    } else {
        [self saveMessageToDatabase:message callback:^(BOOL succeeded, NSError *error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:LC_NOTIFICATION_MESSAGE_UPDATED object:conversation];
        }];
    }
}

- (void)conversation:(AVIMConversation *)conversation didReceiveTypedMessage:(AVIMTypedMessage *)message {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (![_conversations containsObject:conversation]) {
      AVIMConversationQuery *query = [_imClient conversationQuery];
      [query getConversationById:conversation.conversationId callback:^(AVIMConversation *conversation, NSError *error) {
            if (!error) {
                [self addConversationIfNotExists:conversation];
                [self saveMessageToDatabase:message callback:^(BOOL succeeded, NSError *error) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:LC_NOTIFICATION_MESSAGE_UPDATED object:conversation];
                }];
            }
        }];
    } else {
        [self saveMessageToDatabase:message callback:^(BOOL succeeded, NSError *error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:LC_NOTIFICATION_MESSAGE_UPDATED object:conversation];
        }];
    }
}

/*!
 消息已投递给对方。
 @param conversation － 所属对话
 @param message - 具体的消息
 @return None.
 */
- (void)conversation:(AVIMConversation *)conversation messageDelivered:(AVIMMessage *)message {
    NSLog(@"%s", __PRETTY_FUNCTION__);

}

/*!
 对话中有新成员加入的通知。
 @param conversation － 所属对话
 @param clientIds - 加入的新成员列表
 @param clientId - 邀请者的 id
 @return None.
 */
- (void)conversation:(AVIMConversation *)conversation membersAdded:(NSArray *)clientIds byClientId:(NSString *)clientId {
    NSLog(@"%s", __PRETTY_FUNCTION__);

}

/*!
 对话中有成员离开的通知。
 @param conversation － 所属对话
 @param clientIds - 离开的成员列表
 @param clientId - 操作者的 id
 @return None.
 */
- (void)conversation:(AVIMConversation *)conversation membersRemoved:(NSArray *)clientIds byClientId:(NSString *)clientId {
    NSLog(@"%s", __PRETTY_FUNCTION__);

}

/*!
 被邀请加入对话的通知。
 @param conversation － 所属对话
 @param clientId - 邀请者的 id
 @return None.
 */
- (void)conversation:(AVIMConversation *)conversation invitedByClientId:(NSString *)clientId {
    NSLog(@"%s", __PRETTY_FUNCTION__);

}

/*!
 从对话中被移除的通知。
 @param conversation － 所属对话
 @param clientId - 操作者的 id
 @return None.
 */
- (void)conversation:(AVIMConversation *)conversation kickedByClientId:(NSString *)clientId {
    NSLog(@"%s", __PRETTY_FUNCTION__);

}

@end
