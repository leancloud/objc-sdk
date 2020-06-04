//
//  AVIMDynamicObject.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMDynamicObject.h"
#import "AVMPMessagePack.h"

@implementation AVIMDynamicObject {
    NSMutableDictionary *_localData;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _localData = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        _localData = [dictionary mutableCopy];
    }
    return self;
}

- (instancetype)initWithMutableDictionary:(NSMutableDictionary *)mutableDictionary
{
    self = [super init];
    if (self) {
        _localData = mutableDictionary;
    }
    return self;
}

- (instancetype)initWithJSON:(NSString *)json
{
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return nil;
    }
    NSError *error;
    NSMutableDictionary *dic = [NSJSONSerialization JSONObjectWithData:data
                                                               options:NSJSONReadingMutableContainers
                                                                 error:&error];
    if (error) {
        return nil;
    }
    return ([dic isKindOfClass:[NSDictionary class]]
            ? [self initWithMutableDictionary:dic]
            : nil);
}

- (instancetype)initWithMessagePack:(NSData *)data
{
    NSDictionary *dic = [AVMPMessagePackReader readData:data options:0 error:nil];
    return ([dic isKindOfClass:[NSDictionary class]]
            ? [self initWithDictionary:dic]
            : nil);
}

- (NSMutableDictionary *)localData
{
    return _localData;
}

- (BOOL)hasKey:(NSString *)key
{
    return ([self objectForKey:key]);
}

- (id)objectForKey:(NSString *)key
{
    if (![key isKindOfClass:[NSString class]]) {
        return nil;
    }
    id object = [_localData objectForKey:key];
    return [object isEqual:[NSNull null]] ? nil : object;
}

- (id)objectForKeyedSubscript:(NSString *)key
{
    return [self objectForKey:key];
}

- (void)setObject:(id)object forKey:(NSString *)key
{
    if (![key isKindOfClass:[NSString class]]) {
        return;
    }
    if (object && ![object isEqual:[NSNull null]]) {
        [_localData setObject:object forKey:key];
    } else {
        [self removeObjectForKey:key];
    }
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)key
{
    [self setObject:object forKey:key];
}

- (void)removeObjectForKey:(NSString *)key
{
    if (![key isKindOfClass:[NSString class]]) {
        return;
    }
    [_localData removeObjectForKey:key];
}

- (NSDictionary *)rawDictionary
{
    NSMutableSet *visitedObjects = [[NSMutableSet alloc] init];
    return [self rawDictionaryWithVisitedObjects:visitedObjects];
}

- (NSDictionary *)rawDictionaryWithVisitedObjects:(NSMutableSet *)visitedObjects
{
    if ([visitedObjects containsObject:self]) {
        return nil;
    }
    [visitedObjects addObject:self];
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    for (NSString *key in _localData) {
        id object = [_localData objectForKey:key];
        if (object) {
            if ([object isKindOfClass:[AVIMDynamicObject class]]) {
                NSDictionary *childDic = [object rawDictionaryWithVisitedObjects:visitedObjects];
                if (childDic) {
                    [dic setObject:childDic forKey:key];
                }
            } else if ([object isEqual:[NSNull null]]) {
                /* remove null */
            } else {
                [dic setObject:object forKey:key];
            }
        }
    }
    return dic;
}

- (NSString *)JSONString
{
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self rawDictionary]
                                                   options:0
                                                     error:&error];
    if (error) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSDictionary *)dictionary
{
    return [self rawDictionary];
}

- (NSData *)messagePack
{
    NSDictionary *dic = [self rawDictionary];
    return [AVMPMessagePackWriter writeObject:dic options:0 error:nil];
}

@end
