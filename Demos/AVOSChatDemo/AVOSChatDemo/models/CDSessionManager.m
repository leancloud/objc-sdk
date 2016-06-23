//
//  CDSessionManager.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/29/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDSessionManager.h"
#import "FMDB.h"
#import "CDCommon.h"

@interface CDSessionManager () {
//    NSMutableArray *_sessions;
    FMDatabase *_database;
    AVSession *_session;
    NSMutableArray *_chatRooms;
}

@end

static id instance = nil;
static BOOL initialized = NO;

@implementation CDSessionManager
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

- (NSString *)databasePath {
    static NSString *databasePath = nil;
    if (!databasePath) {
        NSString *cacheDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        databasePath = [cacheDirectory stringByAppendingPathComponent:@"chat.db"];
    }
    return databasePath;
}
//+ (id)allocWithZone:(NSZone *)zone {
//    return [self sharedInstance];
//}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (instancetype)init {
    if ((self = [super init])) {
        _chatRooms = [[NSMutableArray alloc] init];
        
        AVSession *session = [[AVSession alloc] init];
        session.sessionDelegate = self;
        session.signatureDelegate = self;
        _session = session;

        NSLog(@"database path:%@", [self databasePath]);
        _database = [FMDatabase databaseWithPath:[self databasePath]];
        [_database open];
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    if (![_database tableExists:@"messages"]) {
        [_database executeUpdate:@"create table \"messages\" (\"fromid\" text, \"toid\" text, \"type\" text, \"message\" text, \"object\" text, \"time\" integer)"];
    }
    if (![_database tableExists:@"sessions"]) {
        [_database executeUpdate:@"create table \"sessions\" (\"type\" integer, \"otherid\" text)"];
    }
    [_session openWithPeerId:[AVUser currentUser].username];
//    [_session open:[AVUser currentUser].username withPeerIds:nil];
//    [_session open:@"u85083689_e1083492a60f83827de73c04b1dca9" withPeerIds:nil];

    FMResultSet *rs = [_database executeQuery:@"select \"type\", \"otherid\" from \"sessions\""];
    NSMutableArray *peerIds = [[NSMutableArray alloc] init];
    while ([rs next]) {
        NSInteger type = [rs intForColumn:@"type"];
        NSString *otherid = [rs stringForColumn:@"otherid"];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInteger:type] forKey:@"type"];
        [dict setObject:otherid forKey:@"otherid"];
        if (type == CDChatRoomTypeSingle) {
            [peerIds addObject:otherid];
        } else if (type == CDChatRoomTypeGroup) {
            [dict setObject:[NSNumber numberWithInteger:type] forKey:@"type"];
            [dict setObject:otherid forKey:@"otherid"];
            
            AVGroup *group = [AVGroup getGroupWithGroupId:otherid session:_session];
            group.delegate = self;
            [group join];
        }
        [_chatRooms addObject:dict];
    }
    [_session watchPeerIds:peerIds callback:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"watch success");
        } else {
            NSLog(@"%@", error);
        }
    }];
    initialized = YES;
}

//- (void)addSession:(AVSession *)session {
//    BOOL hadSession = NO;
//    for (AVSession *s in _sessions) {
//        if ([session isGroupSession]) {
//            if ([s isGroupSession] && [session group].groupId && [[session group].groupId isEqualToString:[s group].groupId]) {
//                hadSession = YES;
//                break;
//            }
//        } else {
//            if (![s isGroupSession] && [[[session getAllPeers] firstObject] isEqual:[[s getAllPeers] firstObject]]) {
//                hadSession = YES;
//                break;
//            }
//        }
//    }
//    if (!hadSession) {
//        NSString *otherId = nil;
//        CDSessionType type = 0;
//        if ([session isGroupSession]) {
//            otherId = [session group].groupId;
//            type = CDSessionTypeGroup;
//        } else {
//            otherId = [[session getAllPeers] firstObject];
//            type = CDSessionTypeNormal;
//        }
//        if (otherId) {
//        [_database executeUpdate:@"insert into \"sessions\" (\"type\", \"otherid\") values (?, ?)" withArgumentsInArray:@[[NSNumber numberWithInteger:type], otherId]];
//        [_sessions addObject:session];
//        }
//    }
////    
////    if ([_sessions indexOfObject:session] == NSNotFound) {
////        [_sessions addObject:session];
////    }
//}
//
//- (NSArray *)sessions {
//    return _sessions;
//}


//- (void)sendWithSession:(AVSession *)session message:(NSString *)message {
//    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
//    [dict setObject:session.getSelfPeerId forKey:@"dn"];
//    [dict setObject:message forKey:@"msg"];
//    NSError *error = nil;
//    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
//    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    if ([session group]) {
//        [[session group] sendMessage:payload isTransient:NO];
//    } else {
//        [session sendMessage:payload isTransient:NO toPeerIds:session.getAllPeers];
//    }
//    
//    dict = [NSMutableDictionary dictionary];
//    [dict setObject:session.getSelfPeerId forKey:@"fromid"];
//    if ([session group]) {
//        [dict setObject:[session group].groupId forKey:@"toid"];
//    } else {
//        NSArray *names = session.getAllPeers;
//        NSString *name = [names objectAtIndex:0];
//        [dict setObject:name forKey:@"toid"];
//    }
//    [dict setObject:message forKey:@"message"];
//    [dict setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
//    [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"message\", \"time\") values (:fromid, :toid, :message, :time)" withParameterDictionary:dict];
//    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:session userInfo:dict];
//}

- (void)clearData {
    [_database executeUpdate:@"DROP TABLE IF EXISTS messages"];
    [_database executeUpdate:@"DROP TABLE IF EXISTS sessions"];
    [_chatRooms removeAllObjects];
    [_session close];
    initialized = NO;
}

- (NSArray *)chatRooms {
    return _chatRooms;
}
- (void)addChatWithPeerId:(NSString *)peerId {
    BOOL exist = NO;
    for (NSDictionary *dict in _chatRooms) {
        CDChatRoomType type = [[dict objectForKey:@"type"] integerValue];
        NSString *otherid = [dict objectForKey:@"otherid"];
        if (type == CDChatRoomTypeSingle && [peerId isEqualToString:otherid]) {
            exist = YES;
            break;
        }
    }
    if (!exist) {
        [_session watchPeerIds:@[peerId] callback:^(BOOL succeeded, NSError *error) {
            if (succeeded) {
                NSLog(@"watch success");
            } else {
                NSLog(@"%@", error);
            }
        }];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInteger:CDChatRoomTypeSingle] forKey:@"type"];
        [dict setObject:peerId forKey:@"otherid"];
        [_chatRooms addObject:dict];
        [_database executeUpdate:@"insert into \"sessions\" (\"type\", \"otherid\") values (?, ?)" withArgumentsInArray:@[[NSNumber numberWithInteger:CDChatRoomTypeSingle], peerId]];
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:_session userInfo:nil];
    }
}

- (AVGroup *)joinGroup:(NSString *)groupId {
    BOOL exist = NO;
    for (NSDictionary *dict in _chatRooms) {
        CDChatRoomType type = [[dict objectForKey:@"type"] integerValue];
        NSString *otherid = [dict objectForKey:@"otherid"];
        if (type == CDChatRoomTypeGroup && [groupId isEqualToString:otherid]) {
            exist = YES;
            break;
        }
    }
    if (!exist) {
        AVGroup *group = [AVGroup getGroupWithGroupId:groupId session:_session];
        group.delegate = self;
        [group join];
        
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInteger:CDChatRoomTypeGroup] forKey:@"type"];
        [dict setObject:groupId forKey:@"otherid"];
        [_chatRooms addObject:dict];
        [_database executeUpdate:@"insert into \"sessions\" (\"type\", \"otherid\") values (?, ?)" withArgumentsInArray:@[[NSNumber numberWithInteger:CDChatRoomTypeGroup], groupId]];
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:group.session userInfo:nil];
    }
    return [AVGroup getGroupWithGroupId:groupId session:_session];;
}
- (void)startNewGroup:(AVGroupResultBlock)callback {
    [AVGroup createGroupWithSession:_session groupDelegate:self callback:^(AVGroup *group, NSError *error) {
        if (!error) {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setObject:[NSNumber numberWithInteger:CDChatRoomTypeGroup] forKey:@"type"];
            [dict setObject:group.groupId forKey:@"otherid"];
            [_chatRooms addObject:dict];
            [_database executeUpdate:@"insert into \"sessions\" (\"type\", \"otherid\") values (?, ?)" withArgumentsInArray:@[[NSNumber numberWithInteger:CDChatRoomTypeGroup], group.groupId]];
            if (callback) {
                callback(group, error);
            }
        } else {
            NSLog(@"error:%@", error);
        }
    }];
}

- (void)sendMessage:(NSString *)message toPeerId:(NSString *)peerId {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"dn"];
    [dict setObject:@"text" forKey:@"type"];
    [dict setObject:message forKey:@"msg"];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    AVMessage *messageObject = [AVMessage messageForPeerWithSession:_session toPeerId:peerId payload:payload requestReceipt:NO];
    [_session sendMessage:messageObject];
    //    [_session sendMessage:payload isTransient:NO toPeerIds:@[peerId]];
    
    dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"fromid"];
    [dict setObject:peerId forKey:@"toid"];
    [dict setObject:@"text" forKey:@"type"];
    [dict setObject:message forKey:@"message"];
    [dict setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
    [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"type\", \"message\", \"time\") values (:fromid, :toid, :type, :message, :time)" withParameterDictionary:dict];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:nil userInfo:dict];
    
}

- (void)sendAttachment:(AVObject *)object toPeerId:(NSString *)peerId {
    NSString *type = [object objectForKey:@"type"];
//    AVFile *file = [object objectForKey:type];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"dn"];
    [dict setObject:type forKey:@"type"];
    [dict setObject:object.objectId forKey:@"object"];
    
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    AVMessage *messageObject = [AVMessage messageForPeerWithSession:_session toPeerId:peerId payload:payload requestReceipt:NO];
    [_session sendMessage:messageObject];
    //    [_session sendMessage:payload isTransient:NO toPeerIds:@[peerId]];
    
    dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"fromid"];
    [dict setObject:peerId forKey:@"toid"];
    [dict setObject:type forKey:@"type"];
    [dict setObject:object.objectId forKey:@"object"];
    [dict setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
    [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"type\", \"object\", \"time\") values (:fromid, :toid, :type, :object, :time)" withParameterDictionary:dict];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:nil userInfo:dict];
    
}

- (void)sendMessage:(NSString *)message toGroup:(NSString *)groupId {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"dn"];
    [dict setObject:@"text" forKey:@"type"];
    [dict setObject:message forKey:@"msg"];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    AVGroup *group = [AVGroup getGroupWithGroupId:groupId session:_session];
    AVMessage *messageObject = [AVMessage messageForGroup:group payload:payload];
    [group sendMessage:messageObject];
    
    dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"fromid"];
    [dict setObject:groupId forKey:@"toid"];
    [dict setObject:@"text" forKey:@"type"];
    [dict setObject:message forKey:@"message"];
    [dict setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
    [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"type\", \"message\", \"time\") values (:fromid, :toid, :type, :message, :time)" withParameterDictionary:dict];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:nil userInfo:dict];
    
}

- (void)sendAttachment:(AVObject *)object toGroup:(NSString *)groupId {
    NSString *type = [object objectForKey:@"type"];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"dn"];
    [dict setObject:type forKey:@"type"];
    [dict setObject:object.objectId forKey:@"object"];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    AVGroup *group = [AVGroup getGroupWithGroupId:groupId session:_session];
    AVMessage *messageObject = [AVMessage messageForGroup:group payload:payload];
    [group sendMessage:messageObject];
    
    dict = [NSMutableDictionary dictionary];
    [dict setObject:_session.peerId forKey:@"fromid"];
    [dict setObject:groupId forKey:@"toid"];
    [dict setObject:type forKey:@"type"];
    [dict setObject:object.objectId forKey:@"object"];
    [dict setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
    [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"type\", \"object\", \"time\") values (:fromid, :toid, :type, :object, :time)" withParameterDictionary:dict];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:nil userInfo:dict];
    
}

- (NSArray *)getMessagesForPeerId:(NSString *)peerId {
    NSString *selfId = _session.peerId;
    FMResultSet *rs = [_database executeQuery:@"select \"fromid\", \"toid\", \"type\", \"message\", \"object\", \"time\" from \"messages\" where (\"fromid\"=? and \"toid\"=?) or (\"fromid\"=? and \"toid\"=?)" withArgumentsInArray:@[selfId, peerId, peerId, selfId]];
    NSMutableArray *result = [NSMutableArray array];
    while ([rs next]) {
        NSString *fromid = [rs stringForColumn:@"fromid"];
        NSString *toid = [rs stringForColumn:@"toid"];
        double time = [rs doubleForColumn:@"time"];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:time];
        NSString *type = [rs stringForColumn:@"type"];
        if ([type isEqualToString:@"text"]) {
            NSString *message = [rs stringForColumn:@"message"];
            NSDictionary *dict = @{@"fromid":fromid, @"toid":toid, @"type":type, @"message":message, @"time":date};
            [result addObject:dict];
        } else {
            NSString *object = [rs stringForColumn:@"object"];
            NSDictionary *dict = @{@"fromid":fromid, @"toid":toid, @"type":type, @"object":object, @"time":date};
            [result addObject:dict];
        }
    }
    return result;
}

- (NSArray *)getMessagesForGroup:(NSString *)groupId {
    FMResultSet *rs = [_database executeQuery:@"select \"fromid\", \"toid\", \"type\", \"message\", \"object\", \"time\" from \"messages\" where \"toid\"=?" withArgumentsInArray:@[groupId]];
    NSMutableArray *result = [NSMutableArray array];
    while ([rs next]) {
        NSString *fromid = [rs stringForColumn:@"fromid"];
        NSString *toid = [rs stringForColumn:@"toid"];
        double time = [rs doubleForColumn:@"time"];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:time];
        NSString *type = [rs stringForColumn:@"type"];
        if ([type isEqualToString:@"text"]) {
            NSString *message = [rs stringForColumn:@"message"];
            NSDictionary *dict = @{@"fromid":fromid, @"toid":toid, @"type":type, @"message":message, @"time":date};
            [result addObject:dict];
        } else {
            NSString *object = [rs stringForColumn:@"object"];
            NSDictionary *dict = @{@"fromid":fromid, @"toid":toid, @"type":type, @"object":object, @"time":date};
            [result addObject:dict];
        }
    }
    return result;
}

- (void)getHistoryMessagesForPeerId:(NSString *)peerId callback:(AVArrayResultBlock)callback {
    AVHistoryMessageQuery *query = [AVHistoryMessageQuery queryWithFirstPeerId:_session.peerId secondPeerId:peerId];
    [query findInBackgroundWithCallback:^(NSArray *objects, NSError *error) {
        callback(objects, error);
    }];
}

- (void)getHistoryMessagesForGroup:(NSString *)groupId callback:(AVArrayResultBlock)callback {
    AVHistoryMessageQuery *query = [AVHistoryMessageQuery queryWithGroupId:groupId];
    [query findInBackgroundWithCallback:^(NSArray *objects, NSError *error) {
        callback(objects, error);
    }];
}
#pragma mark - AVSessionDelegate
- (void)sessionOpened:(AVSession *)session {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@", session.peerId);
}

- (void)sessionPaused:(AVSession *)session {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@", session.peerId);
}

- (void)sessionResumed:(AVSession *)session {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@", session.peerId);
}

- (void)session:(AVSession *)session didReceiveMessage:(AVMessage *)message {
//- (void)onSessionMessage:(AVSession *)session message:(NSString *)message peerId:(NSString *)peerId {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ message:%@ fromPeerId:%@", session.peerId, message, message.fromPeerId);
    NSError *error;
    NSData *data = [message.payload dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    NSLog(@"%@", jsonDict);
    NSString *type = [jsonDict objectForKey:@"type"];
    NSString *msg = [jsonDict objectForKey:@"msg"];
    NSString *object = [jsonDict objectForKey:@"object"];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:message.fromPeerId forKey:@"fromid"];
    [dict setObject:session.peerId forKey:@"toid"];
    [dict setObject:@(message.timestamp/1000) forKey:@"time"];
    [dict setObject:type forKey:@"type"];
    if ([type isEqualToString:@"text"]) {
        [dict setObject:msg forKey:@"message"];
        [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"type\", \"message\", \"time\") values (:fromid, :toid, :type, :message, :time)" withParameterDictionary:dict];
    } else {
        [dict setObject:object forKey:@"object"];
        [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"type\", \"object\", \"time\") values (:fromid, :toid, :type, :object, :time)" withParameterDictionary:dict];
    }
    
//    BOOL exist = NO;
//    for (NSDictionary *dict in _chatRooms) {
//        CDChatRoomType type = [[dict objectForKey:@"type"] integerValue];
//        NSString *otherid = [dict objectForKey:@"otherid"];
//        if (type == CDChatRoomTypeSingle && [message.fromPeerId isEqualToString:otherid]) {
//            exist = YES;
//            break;
//        }
//    }
//    if (!exist) {
        [self addChatWithPeerId:message.fromPeerId];
//        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:session userInfo:nil];
//    }
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:session userInfo:dict];
    //    NSError *error;
    //    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    //    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    //
    //    if (error == nil) {
    //        KAMessage *chatMessage = nil;
    //        if ([jsonDict objectForKey:@"st"]) {
    //            NSString *displayName = [jsonDict objectForKey:@"dn"];
    //            NSString *status = [jsonDict objectForKey:@"st"];
    //            if ([status isEqualToString:@"on"]) {
    //                chatMessage = [[KAMessage alloc] initWithDisplayName:displayName Message:@"上线了" fromMe:YES];
    //            } else {
    //                chatMessage = [[KAMessage alloc] initWithDisplayName:displayName Message:@"下线了" fromMe:YES];
    //            }
    //            chatMessage.isStatus = YES;
    //        } else {
    //            NSString *displayName = [jsonDict objectForKey:@"dn"];
    //            NSString *message = [jsonDict objectForKey:@"msg"];
    //            if ([displayName isEqualToString:MY_NAME]) {
    //                chatMessage = [[KAMessage alloc] initWithDisplayName:displayName Message:message fromMe:YES];
    //            } else {
    //                chatMessage = [[KAMessage alloc] initWithDisplayName:displayName Message:message fromMe:NO];
    //            }
    //        }
    //
    //        if (chatMessage) {
    //            [_messages addObject:chatMessage];
    //            //            [self.tableView beginUpdates];
    //            [self.tableView reloadData];
    //            //            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:_messages.count - 1 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    //            [self.tableView scrollRectToVisible:self.tableView.tableFooterView.frame animated:YES];
    //            //            [self.tableView endUpdates];
    //        }
    //    }
}

- (void)session:(AVSession *)session messageSendFailed:(AVMessage *)message error:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ message:%@ toPeerId:%@ error:%@", session.peerId, message, message.toPeerId, error);
}

- (void)session:(AVSession *)session messageSendFinished:(AVMessage *)message {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ message:%@ toPeerId:%@", session.peerId, message, message.toPeerId);
}

- (void)session:(AVSession *)session messageArrived:(AVMessage *)message {
    NSLog(@"%s", __PRETTY_FUNCTION__);

}

- (void)session:(AVSession *)session didReceiveStatus:(AVPeerStatus)status peerIds:(NSArray *)peerIds {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ peerIds:%@ status:%@", session.peerId, peerIds, status==AVPeerStatusOffline?@"offline":@"online");
}

- (void)sessionFailed:(AVSession *)session error:(NSError *)error {
//- (void)onSessionError:(AVSession *)session withException:(NSException *)exception {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"session:%@ error:%@", session.peerId, error);
}

#pragma mark - AVGroupDelegate
- (void)group:(AVGroup *)group didReceiveMessage:(AVMessage *)message {
//- (void)session:(AVSession *)session group:(AVGroup *)group didReceiveGroupMessage:(NSString *)message fromPeerId:(NSString *)peerId {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ message:%@ fromPeerId:%@", group.groupId, message, message.fromPeerId);
    NSError *error;
    NSData *data = [message.payload dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    NSLog(@"%@", jsonDict);
    
    NSString *type = [jsonDict objectForKey:@"type"];
    NSString *msg = [jsonDict objectForKey:@"msg"];
    NSString *object = [jsonDict objectForKey:@"object"];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:message.fromPeerId forKey:@"fromid"];
    [dict setObject:group.groupId forKey:@"toid"];
    [dict setObject:@(message.timestamp/1000) forKey:@"time"];
    [dict setObject:type forKey:@"type"];
    if ([type isEqualToString:@"text"]) {
        [dict setObject:msg forKey:@"message"];
        [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"type\", \"message\", \"time\") values (:fromid, :toid, :type, :message, :time)" withParameterDictionary:dict];
    } else {
        [dict setObject:object forKey:@"object"];
        [_database executeUpdate:@"insert into \"messages\" (\"fromid\", \"toid\", \"type\", \"object\", \"time\") values (:fromid, :toid, :type, :object, :time)" withParameterDictionary:dict];
    }

//    BOOL exist = NO;
//    for (NSDictionary *dict in _chatRooms) {
//        CDChatRoomType type = [[dict objectForKey:@"type"] integerValue];
//        NSString *otherid = [dict objectForKey:@"otherid"];
//        if (type == CDChatRoomTypeGroup && [group.groupId isEqualToString:otherid]) {
//            exist = YES;
//            break;
//        }
//    }
//    if (!exist) {
        [self joinGroup:group.groupId];
//        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:group.session userInfo:nil];
//    }

    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MESSAGE_UPDATED object:group.session userInfo:dict];
}

- (void)group:(AVGroup *)group didReceiveEvent:(AVGroupEvent)event peerIds:(NSArray *)peerIds {
//- (void)session:(AVSession *)session group:(AVGroup *)group didReceiveGroupEvent:(AVGroupEvent)event memberIds:(NSArray *)memberIds {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ event:%lu peerIds:%@", group.groupId, event, peerIds);
    if (event == AVGroupEventSelfJoined) {
        [self joinGroup:group.groupId];
//        BOOL exist = NO;
//        for (NSDictionary *dict in _chatRooms) {
//            CDChatRoomType type = [[dict objectForKey:@"type"] integerValue];
//            NSString *otherid = [dict objectForKey:@"otherid"];
//            if (type == CDChatRoomTypeGroup && [group.groupId isEqualToString:otherid]) {
//                exist = YES;
//                break;
//            }
//        }
//        if (!exist) {
//            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
//            [dict setObject:[NSNumber numberWithInteger:CDChatRoomTypeGroup] forKey:@"type"];
//            [dict setObject:group.groupId forKey:@"otherid"];
//            [_chatRooms addObject:dict];
//            [_database executeUpdate:@"insert into \"sessions\" (\"type\", \"otherid\") values (?, ?)" withArgumentsInArray:@[[NSNumber numberWithInteger:CDChatRoomTypeGroup], group.groupId]];
//            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_UPDATED object:group.session userInfo:nil];
//        }
    }
}

- (void)group:(AVGroup *)group messageSendFinished:(AVMessage *)message {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ message:%@", group.groupId, message.payload);

}

- (void)group:(AVGroup *)group messageSendFailed:(AVMessage *)message error:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ message:%@ error:%@", group.groupId, message.payload, error);

}

- (void)session:(AVSession *)session group:(AVGroup *)group messageSent:(NSString *)message success:(BOOL)success {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"group:%@ message:%@ success:%d", group.groupId, message, success);
}

//- (AVSignature *)createSessionSignature:(NSString *)peerId watchedPeerIds:(NSArray *)watchedPeerIds action:(NSString *)action {
//    AVSignature *signature = [[AVSignature alloc] init];
//    signature.signature = @"b1a9ae4d2950a6dd36de15c0426f14954dc4b502";
//    signature.timestamp = 1409195426;
//    signature.nonce = @"115209";
//    return signature;
//}

@end
