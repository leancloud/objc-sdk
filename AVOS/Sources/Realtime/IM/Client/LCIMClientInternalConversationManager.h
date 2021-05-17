//
//  LCIMClientInternalConversationManager.h
//  LeanCloud
//
//  Created by zapcannon87 on 2018/7/18.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LCIMClient;
@class LCIMConversation;

@interface LCIMClientInternalConversationManager : NSObject

#if DEBUG
@property (nonatomic, strong) dispatch_queue_t internalSerialQueue;
#endif
@property (nonatomic, weak) LCIMClient *client;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<void (^)(LCIMConversation *, NSError *)> *> *callbacksMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, LCIMConversation *> *conversationMap;

- (instancetype)initWithClient:(LCIMClient *)client;

- (void)insertConversation:(LCIMConversation *)conversation;
- (LCIMConversation *)conversationForId:(NSString *)conversationId;
- (void)removeConversationsWithIds:(NSArray<NSString *> *)conversationIds;
- (void)removeAllConversations;

- (void)queryConversationWithId:(NSString *)conversationId
                       callback:(void (^)(LCIMConversation *conversation, NSError *error))callback;

- (void)queryConversationsWithIds:(NSArray<NSString *> *)conversationIds
                         callback:(void (^)(LCIMConversation *conversation, NSError *error))callback;

@end
