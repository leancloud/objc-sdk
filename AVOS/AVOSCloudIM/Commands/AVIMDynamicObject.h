//
//  AVIMDynamicObject.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define LC_FORWARD_PROPERTY_ACCESSOR(           \
    getter_name,                                \
    getter_return_type,                         \
    getter_return_value,                        \
    setter_name,                                \
    setter_object_value)                        \
                                                \
- (getter_return_type)getter_name {             \
    NSString *key = NSStringFromSelector(@selector(getter_name));   \
    id getter_name = self[key];                 \
    return (getter_return_value);               \
}                                               \
                                                \
- (void)setter_name:(getter_return_type)getter_name {               \
    NSString *key = NSStringFromSelector(@selector(getter_name));   \
    self[key] = (setter_object_value);          \
}

#define LC_FORWARD_PROPERTY_ACCESSOR_NUMBER(    \
    getter_name,                                \
    setter_name,                                \
    number_type)                                \
                                                \
    LC_FORWARD_PROPERTY_ACCESSOR(               \
    getter_name,                                \
    number_type,                                \
    (number_type)[getter_name doubleValue],     \
    setter_name,                                \
    @((double)getter_name))

#define LC_FORWARD_PROPERTY_ACCESSOR_OBJECT(    \
    getter_name,                                \
    setter_name)                                \
                                                \
    LC_FORWARD_PROPERTY_ACCESSOR(               \
    getter_name,                                \
    id,                                         \
    getter_name,                                \
    setter_name,                                \
    getter_name)

#define LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY(   \
    getter_name,                                    \
    setter_name)                                    \
                                                    \
    LC_FORWARD_PROPERTY_ACCESSOR(                   \
    getter_name,                                    \
    id,                                             \
    getter_name,                                    \
    setter_name,                                    \
    [getter_name copy])

@interface AVIMDynamicObject : NSObject
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithMutableDictionary:(NSMutableDictionary *)dictionary;
- (instancetype)initWithJSON:(NSString *)json;
- (instancetype)initWithMessagePack:(NSData *)data;
- (NSString *)JSONString;
- (NSDictionary *)dictionary;
- (NSData *)messagePack;

- (BOOL)hasKey:(NSString *)key;
- (id)objectForKey:(NSString *)key;
- (id)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id)object forKey:(NSString *)key;
- (void)setObject:(id)object forKeyedSubscript:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;
@end
