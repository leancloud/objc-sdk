//
//  LCIMConversationCacheStore.m
//  AVOS
//
//  Created by Tang Tianyong on 8/29/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMConversationCacheStore.h"
#import "LCIMConversationCacheStoreSQL.h"
#import "LCIMMessageCacheStoreSQL.h"
#import "AVIMClient_Internal.h"
#import "AVIMConversation.h"
#import "AVIMConversation_Internal.h"
#import "LCDatabaseMigrator.h"

#define LCIM_CONVERSATION_MAX_CACHE_AGE 60 * 60 * 24

@implementation LCIMConversationCacheStore

+ (NSString *)LCIM_SQL_Delete_Expired_Conversations
{
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ <= ?;",
                     LCIM_TABLE_CONVERSATION_V2,
                     LCIM_FIELD_EXPIRE_AT];
    
    return sql;
}

- (NSArray *)insertionRecordForConversation:(AVIMConversation *)conversation expireAt:(NSTimeInterval)expireAt
{
    id conversationId = conversation.conversationId;
    id name = (conversation.name ?: NSNull.null);
    id creator = (conversation.creator ?: NSNull.null);
    id transient = @(conversation.transient);
    id members = ({
        NSArray<NSString *> *members = conversation.members;
        members ? [members componentsJoinedByString:@","] : NSNull.null;
    });
    id attributes = ({
        NSDictionary *attributes = conversation.attributes;
        attributes ? [NSKeyedArchiver archivedDataWithRootObject:attributes] : NSNull.null;
    });
    id createAt = ({
        NSDate *date = conversation.createAt;
        date ? @(date.timeIntervalSince1970) : NSNull.null;
    });
    id updateAt = ({
        NSDate *date = conversation.updateAt;
        date ? @(date.timeIntervalSince1970) : NSNull.null;
    });
    id lastMessageAt = ({
        NSDate *date = conversation.lastMessageAt;
        date ? @(date.timeIntervalSince1970) : NSNull.null;
    });
    id lastMessage = ({
        AVIMMessage *lastMessage = conversation.lastMessage;
        lastMessage ? [NSKeyedArchiver archivedDataWithRootObject:lastMessage] : NSNull.null;
    });
    id muted = @(conversation.muted);
    id rawDataData = ({
        NSDictionary *rawJSONData = conversation.rawJSONDataCopy;
        rawJSONData ? [NSKeyedArchiver archivedDataWithRootObject:rawJSONData] : NSNull.null;
    });
    
    return @[conversationId, name, creator,
             transient, members, attributes,
             createAt, updateAt, lastMessageAt,
             lastMessage, muted, rawDataData,
             [NSNumber numberWithDouble:expireAt]];
}

- (void)insertConversations:(NSArray *)conversations {
    [self insertConversations:conversations maxAge:LCIM_CONVERSATION_MAX_CACHE_AGE];
}

- (void)insertConversations:(NSArray *)conversations maxAge:(NSTimeInterval)maxAge {
    NSTimeInterval expireAt = [[NSDate date] timeIntervalSince1970] + maxAge;
    for (AVIMConversation *conversation in conversations) {
        if (!conversation.conversationId) continue;
        NSArray *insertionRecord = [self insertionRecordForConversation:conversation expireAt:expireAt];
        LCIM_OPEN_DATABASE(db, ({
            [db executeUpdate:LCIM_SQL_INSERT_CONVERSATION withArgumentsInArray:insertionRecord];
        }));
    }
}

- (void)deleteConversation:(AVIMConversation *)conversation {
    [self deleteConversationForId:conversation.conversationId];
}

- (void)deleteConversationForId:(NSString *)conversationId {
    if (!conversationId) return;

    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[conversationId];
        [db executeUpdate:LCIM_SQL_DELETE_CONVERSATION withArgumentsInArray:args];
    }));
}

- (void)deleteAllMessageOfConversationForId:(NSString *)conversationId {
    if (!conversationId) return;

    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[conversationId];
        [db executeUpdate:LCIM_SQL_DELETE_ALL_MESSAGES_OF_CONVERSATION withArgumentsInArray:args];
    }));
}

- (void)deleteConversationAndItsMessagesForId:(NSString *)conversationId {
    [self deleteConversationForId:conversationId];
    [self deleteAllMessageOfConversationForId:conversationId];
}

- (void)updateConversationForLastMessageAt:(NSDate *)lastMessageAt conversationId:(NSString *)conversationId {
    if (!conversationId || !lastMessageAt) return;
    
    NSNumber *lastMessageAtNumber = [NSNumber numberWithDouble:[lastMessageAt timeIntervalSince1970]];
    
    LCIM_OPEN_DATABASE(db, ({
        NSArray *args = @[
                          lastMessageAtNumber,
                          conversationId,
                          ];
        [db executeUpdate:LCIM_SQL_UPDATE_CONVERSATION withArgumentsInArray:args];
    }));
}

- (AVIMConversation *)conversationForId:(NSString *)conversationId timestamp:(NSTimeInterval)timestamp {
    __block AVIMConversation *conversation = nil;

    LCIM_OPEN_DATABASE(db, ({
        conversation = [self conversationForId:conversationId database:db timestamp:timestamp];
    }));

    return conversation;
}

- (AVIMConversation *)conversationForId:(NSString *)conversationId database:(LCDatabase *)database timestamp:(NSTimeInterval)timestamp {
    if (!conversationId) return nil;

    AVIMConversation *conversation = nil;

    NSArray *args = @[conversationId];
    LCResultSet *result = [database executeQuery:LCIM_SQL_SELECT_CONVERSATION withArgumentsInArray:args];

    if ([result next]) {
        NSTimeInterval expireAt = [result doubleForColumn:LCIM_FIELD_EXPIRE_AT];

        if (expireAt <= timestamp) {
            [database executeUpdate:LCIM_SQL_DELETE_CONVERSATION withArgumentsInArray:@[conversationId]];
        } else {
            conversation = [self conversationWithResult:result];
        }
    }

    [result close];

    return conversation;
}

- (AVIMConversation *)conversationForId:(NSString *)conversationId {
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];

    return [self conversationForId:conversationId timestamp:timestamp];
}

- (NSDate *)dateFromTimeInterval:(NSTimeInterval)timeInterval {
    return timeInterval ? [NSDate dateWithTimeIntervalSince1970:timeInterval] : nil;
}

- (AVIMConversation *)conversationWithResult:(LCResultSet *)result
{
    AVIMConversation *conversation = ({
        NSDictionary *rawDataDic = ({
            NSData *data = [result dataForColumn:LCIM_FIELD_RAW_DATA];
            data ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
        });
        AVIMConversation *conv = [AVIMConversation conversationWithRawJSONData:rawDataDic.mutableCopy client:self.client];
        conv;
    });
    return conversation;
}

- (NSArray *)conversationsForIds:(NSArray *)conversationIds {
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];

    __block BOOL isOK = YES;
    NSMutableArray *conversations = [NSMutableArray array];

    LCIM_OPEN_DATABASE(db, ({
        for (NSString *conversationId in conversationIds) {
            AVIMConversation *conversation = [self conversationForId:conversationId database:db timestamp:timestamp];

            if (conversation) {
                [conversations addObject:conversation];
            } else {
                isOK = NO;
                return;
            }
        }
    }));

    return isOK ? conversations : @[];
}

- (void)cleanAllExpiredConversations
{
    [self.databaseQueue inDatabase:^(LCDatabase *db) {
        
        db.logsErrors = LCIM_SHOULD_LOG_ERRORS;
        
        NSString *sql = [self.class LCIM_SQL_Delete_Expired_Conversations];
        
        NSTimeInterval currentTimestamp = NSDate.date.timeIntervalSince1970;
        
        NSArray *args = @[@(currentTimestamp)];
        
        [db executeUpdate:sql withArgumentsInArray:args];
    }];
}

@end
