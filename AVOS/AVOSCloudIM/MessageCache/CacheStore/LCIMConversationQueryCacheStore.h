//
//  LCIMConversationQueryCacheStore.h
//  AVOS
//
//  Created by Tang Tianyong on 8/31/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCKeyValueStore.h"

@class LCIMConversationOutCommand;

@interface LCIMConversationQueryCacheStore : LCKeyValueStore

@property (copy, readonly) NSString *clientId;

- (instancetype)initWithClientId:(NSString *)clientId;

- (void)cacheConversationIds:(NSArray *)conversationIds forCommand:(LCIMConversationOutCommand *)command;

- (void)removeConversationIdsForCommand:(LCIMConversationOutCommand *)command;

/*!
 * Get conversation id list for a given command.
 * @param command LCIMConversationOutCommand object.
 * @return A conversation id list or nil if cache not found.
 */
- (NSArray *)conversationIdsForCommand:(LCIMConversationOutCommand *)command;

@end
