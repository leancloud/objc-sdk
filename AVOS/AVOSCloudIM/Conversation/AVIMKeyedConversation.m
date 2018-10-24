//
//  AVIMKeyedConversation.m
//  AVOS
//
//  Created by Tang Tianyong on 6/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMKeyedConversation_internal.h"
#import "AVIMMessage.h"

@implementation AVIMKeyedConversation

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        NSString *conversationId = NSStringFromSelector(@selector(conversationId));
        if ([aDecoder containsValueForKey:conversationId]) {
            self.conversationId = [aDecoder decodeObjectForKey:conversationId];
        }
        NSString *clientId = NSStringFromSelector(@selector(clientId));
        if ([aDecoder containsValueForKey:clientId]) {
            self.clientId = [aDecoder decodeObjectForKey:clientId];
        }
        NSString *creator = NSStringFromSelector(@selector(creator));
        if ([aDecoder containsValueForKey:creator]) {
            self.creator = [aDecoder decodeObjectForKey:creator];
        }
        NSString *createAt = NSStringFromSelector(@selector(createAt));
        if ([aDecoder containsValueForKey:createAt]) {
            self.createAt = [aDecoder decodeObjectForKey:createAt];
        }
        NSString *updateAt = NSStringFromSelector(@selector(updateAt));
        if ([aDecoder containsValueForKey:updateAt]) {
            self.updateAt = [aDecoder decodeObjectForKey:updateAt];
        }
        NSString *lastMessageAt = NSStringFromSelector(@selector(lastMessageAt));
        if ([aDecoder containsValueForKey:lastMessageAt]) {
            self.lastMessageAt = [aDecoder decodeObjectForKey:lastMessageAt];
        }
        NSString *lastDeliveredAt = NSStringFromSelector(@selector(lastDeliveredAt));
        if ([aDecoder containsValueForKey:lastDeliveredAt]) {
            self.lastDeliveredAt = [aDecoder decodeObjectForKey:lastDeliveredAt];
        }
        NSString *lastReadAt = NSStringFromSelector(@selector(lastReadAt));
        if ([aDecoder containsValueForKey:lastReadAt]) {
            self.lastReadAt = [aDecoder decodeObjectForKey:lastReadAt];
        }
        NSString *lastMessage = NSStringFromSelector(@selector(lastMessage));
        if ([aDecoder containsValueForKey:lastMessage]) {
            self.lastMessage = [aDecoder decodeObjectForKey:lastMessage];
        }
        NSString *name = NSStringFromSelector(@selector(name));
        if ([aDecoder containsValueForKey:name]) {
            self.name = [aDecoder decodeObjectForKey:name];
        }
        NSString *members = NSStringFromSelector(@selector(members));
        if ([aDecoder containsValueForKey:members]) {
            self.members = [aDecoder decodeObjectForKey:members];
        }
        NSString *attributes = NSStringFromSelector(@selector(attributes));
        if ([aDecoder containsValueForKey:attributes]) {
            self.attributes = [aDecoder decodeObjectForKey:attributes];
        }
        NSString *uniqueId = NSStringFromSelector(@selector(uniqueId));
        if ([aDecoder containsValueForKey:uniqueId]) {
            self.uniqueId = [aDecoder decodeObjectForKey:uniqueId];
        }
        NSString *rawDataDic = NSStringFromSelector(@selector(rawDataDic));
        if ([aDecoder containsValueForKey:rawDataDic]) {
            self.rawDataDic = [aDecoder decodeObjectForKey:rawDataDic];
        }
        self.unique = [aDecoder decodeBoolForKey:NSStringFromSelector(@selector(unique))];
        self.transient = [aDecoder decodeBoolForKey:NSStringFromSelector(@selector(transient))];
        self.system = [aDecoder decodeBoolForKey:NSStringFromSelector(@selector(system))];
        self.temporary = [aDecoder decodeBoolForKey:NSStringFromSelector(@selector(temporary))];
        self.muted = [aDecoder decodeBoolForKey:NSStringFromSelector(@selector(muted))];
        self.temporaryTTL = [aDecoder decodeIntegerForKey:NSStringFromSelector(@selector(temporaryTTL))];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (self.conversationId) {
        [aCoder encodeObject:self.conversationId forKey:NSStringFromSelector(@selector(conversationId))];
    }
    if (self.clientId) {
        [aCoder encodeObject:self.clientId forKey:NSStringFromSelector(@selector(clientId))];
    }
    if (self.creator) {
        [aCoder encodeObject:self.creator forKey:NSStringFromSelector(@selector(creator))];
    }
    if (self.createAt) {
        [aCoder encodeObject:self.createAt forKey:NSStringFromSelector(@selector(createAt))];
    }
    if (self.updateAt) {
        [aCoder encodeObject:self.updateAt forKey:NSStringFromSelector(@selector(updateAt))];
    }
    if (self.lastMessageAt) {
        [aCoder encodeObject:self.lastMessageAt forKey:NSStringFromSelector(@selector(lastMessageAt))];
    }
    if (self.lastDeliveredAt) {
        [aCoder encodeObject:self.lastDeliveredAt forKey:NSStringFromSelector(@selector(lastDeliveredAt))];
    }
    if (self.lastReadAt) {
        [aCoder encodeObject:self.lastReadAt forKey:NSStringFromSelector(@selector(lastReadAt))];
    }
    if (self.lastMessage) {
        [aCoder encodeObject:self.lastMessage forKey:NSStringFromSelector(@selector(lastMessage))];
    }
    if (self.name) {
        [aCoder encodeObject:self.name forKey:NSStringFromSelector(@selector(name))];
    }
    if (self.members) {
        [aCoder encodeObject:self.members forKey:NSStringFromSelector(@selector(members))];
    }
    if (self.attributes) {
        [aCoder encodeObject:self.attributes forKey:NSStringFromSelector(@selector(attributes))];
    }
    if (self.uniqueId) {
        [aCoder encodeObject:self.uniqueId forKey:NSStringFromSelector(@selector(uniqueId))];
    }
    if (self.rawDataDic) {
        [aCoder encodeObject:self.rawDataDic forKey:NSStringFromSelector(@selector(rawDataDic))];
    }
    [aCoder encodeBool:self.unique forKey:NSStringFromSelector(@selector(unique))];
    [aCoder encodeBool:self.transient forKey:NSStringFromSelector(@selector(transient))];
    [aCoder encodeBool:self.system forKey:NSStringFromSelector(@selector(system))];
    [aCoder encodeBool:self.temporary forKey:NSStringFromSelector(@selector(temporary))];
    [aCoder encodeBool:self.muted forKey:NSStringFromSelector(@selector(muted))];
    [aCoder encodeInteger:self.temporaryTTL forKey:NSStringFromSelector(@selector(temporaryTTL))];
}

@end
