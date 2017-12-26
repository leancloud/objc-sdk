//
//  AVIMKeyedConversation.m
//  AVOS
//
//  Created by Tang Tianyong on 6/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMKeyedConversation.h"
#import "AVIMKeyedConversation_internal.h"
#import "AVIMClient_Internal.h"
#import "AVIMConversation.h"
#import "AVIMConversation_Internal.h"

#define LC_SEL_STR(sel) (NSStringFromSelector(@selector(sel)))

@implementation AVIMKeyedConversation

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];

    if (self) {
        self.conversationId = [aDecoder decodeObjectForKey:LC_SEL_STR(conversationId)];
        self.clientId       = [aDecoder decodeObjectForKey:LC_SEL_STR(clientId)];
        self.creator        = [aDecoder decodeObjectForKey:LC_SEL_STR(creator)];
        self.createAt       = [aDecoder decodeObjectForKey:LC_SEL_STR(createAt)];
        self.updateAt       = [aDecoder decodeObjectForKey:LC_SEL_STR(updateAt)];
        self.lastMessageAt  = [aDecoder decodeObjectForKey:LC_SEL_STR(lastMessageAt)];
        self.lastDeliveredAt = [aDecoder decodeObjectForKey:LC_SEL_STR(lastDeliveredAt)];
        self.lastReadAt     = [aDecoder decodeObjectForKey:LC_SEL_STR(lastReadAt)];
        self.lastMessage    = [aDecoder decodeObjectForKey:LC_SEL_STR(lastMessage)];
        self.name           = [aDecoder decodeObjectForKey:LC_SEL_STR(name)];
        self.members        = [aDecoder decodeObjectForKey:LC_SEL_STR(members)];
        self.attributes     = [aDecoder decodeObjectForKey:LC_SEL_STR(attributes)];
        
        self.transient      = [aDecoder decodeBoolForKey:LC_SEL_STR(transient)];
        self.muted          = [aDecoder decodeBoolForKey:LC_SEL_STR(muted)];
        
        NSString *system_key = LC_SEL_STR(system);
        
        if ([aDecoder containsValueForKey:system_key]) {
            
            self.system = [aDecoder decodeBoolForKey:system_key];
            
        } else {
            
            self.system = false;
        }
        
        NSString *temporary_key = LC_SEL_STR(temporary);
        
        if ([aDecoder containsValueForKey:temporary_key]) {
            
            self.temporary = [aDecoder decodeBoolForKey:temporary_key];
            
        } else {
            
            self.temporary = false;
        }
        
        NSString *temporaryTTL_key = LC_SEL_STR(temporaryTTL);
        
        if ([aDecoder containsValueForKey:temporaryTTL_key]) {
            
            self.temporaryTTL = [aDecoder decodeInt32ForKey:temporaryTTL_key];
            
        } else {
            
            self.temporaryTTL = 0;
        }
        
        NSString *unique_key = LC_SEL_STR(unique);
        
        if ([aDecoder containsValueForKey:unique_key]) {
            
            self.unique = [aDecoder decodeBoolForKey:unique_key];
            
        } else {
            
            self.unique = false;
        }
        
        NSString *uniqueId_key = LC_SEL_STR(uniqueId);
        
        if ([aDecoder containsValueForKey:uniqueId_key]) {
            
            self.uniqueId = [aDecoder decodeObjectForKey:uniqueId_key];
        }
        
        /* check if exist `properties` */
        ///
        NSString *properties_key = LC_SEL_STR(properties);
        
        if ([aDecoder containsValueForKey:properties_key]) {
            
            self.properties = [aDecoder decodeObjectForKey:properties_key];
        }
        ///
        
        /* check if exist `rawDataDic` */
        ///
        NSString *rawDataDic_key = LC_SEL_STR(rawDataDic);
        
        if ([aDecoder containsValueForKey:rawDataDic_key]) {
            
            self.rawDataDic = [aDecoder decodeObjectForKey:rawDataDic_key];
        }
        ///
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.conversationId forKey:LC_SEL_STR(conversationId)];
    [aCoder encodeObject:self.clientId       forKey:LC_SEL_STR(clientId)];
    [aCoder encodeObject:self.creator        forKey:LC_SEL_STR(creator)];
    [aCoder encodeObject:self.createAt       forKey:LC_SEL_STR(createAt)];
    [aCoder encodeObject:self.updateAt       forKey:LC_SEL_STR(updateAt)];
    [aCoder encodeObject:self.lastMessageAt  forKey:LC_SEL_STR(lastMessageAt)];
    [aCoder encodeObject:self.lastDeliveredAt forKey:LC_SEL_STR(lastDeliveredAt)];
    [aCoder encodeObject:self.lastReadAt     forKey:LC_SEL_STR(lastReadAt)];
    [aCoder encodeObject:self.lastMessage    forKey:LC_SEL_STR(lastMessage)];
    [aCoder encodeObject:self.name           forKey:LC_SEL_STR(name)];
    [aCoder encodeObject:self.members        forKey:LC_SEL_STR(members)];
    [aCoder encodeObject:self.attributes     forKey:LC_SEL_STR(attributes)];
    
    if (self.properties) {
        
        [aCoder encodeObject:self.properties forKey:LC_SEL_STR(properties)];
    }
    
    if (self.rawDataDic) {
        
        [aCoder encodeObject:self.rawDataDic forKey:LC_SEL_STR(rawDataDic)];
    }
    
    if (self.uniqueId) {
        
        [aCoder encodeObject:self.uniqueId forKey:LC_SEL_STR(uniqueId)];
    }
    
    [aCoder encodeBool:self.transient forKey:LC_SEL_STR(transient)];
    [aCoder encodeBool:self.system forKey:LC_SEL_STR(system)];
    [aCoder encodeBool:self.temporary forKey:LC_SEL_STR(temporary)];
    [aCoder encodeInt32:self.temporaryTTL forKey:LC_SEL_STR(temporaryTTL)];
    [aCoder encodeBool:self.muted forKey:LC_SEL_STR(muted)];
    [aCoder encodeBool:self.unique forKey:LC_SEL_STR(unique)];
}

@end
