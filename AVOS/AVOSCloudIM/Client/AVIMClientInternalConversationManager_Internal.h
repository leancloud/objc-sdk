//
//  AVIMClientInternalConversationManager_Internal.h
//  AVOS
//
//  Created by zapcannon87 on 2018/7/18.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMClientInternalConversationManager.h"

@class AVIMClient;
@class AVIMConversation;

@interface AVIMClientInternalConversationManager ()

#if DEBUG
@property (nonatomic, strong) dispatch_queue_t internalSerialQueue;
#endif
@property (nonatomic, weak) AVIMClient *client;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<void (^)(AVIMConversation *, NSError *)> *> *callbacksMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AVIMConversation *> *conversationMap;

- (instancetype)initWithClient:(AVIMClient *)client;

- (void)insertConversation:(AVIMConversation *)conversation;
- (AVIMConversation *)conversationForId:(NSString *)conversationId;
- (void)removeConversationsWithIds:(NSArray<NSString *> *)conversationIds;
- (void)removeAllConversations;

- (void)queryConversationWithId:(NSString *)conversationId
                       callback:(void (^)(AVIMConversation *conversation, NSError *error))callback;

- (void)queryConversationsWithIds:(NSArray<NSString *> *)conversationIds
                         callback:(void (^)(AVIMConversation *conversation, NSError *error))callback;


@end
