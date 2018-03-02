//
//  AVIMTypedMessage.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/8/15.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <AVOSCloud/AVOSCloud.h>

#import "AVIMTypedMessage.h"
#import "AVIMTypedMessage_Internal.h"
#import "AVIMGeneralObject.h"
#import "AVIMMessage_Internal.h"
#import "AVFile_Internal.h"

NSMutableDictionary const *_typeDict = nil;

@interface AVGeoPoint ()

+(NSDictionary *)dictionaryFromGeoPoint:(AVGeoPoint *)point;
+(AVGeoPoint *)geoPointFromDictionary:(NSDictionary *)dict;

@end

@implementation AVIMTypedMessage

@synthesize file = _file;
@synthesize location = _location;

+ (void)registerSubclass {
    if ([self conformsToProtocol:@protocol(AVIMTypedMessageSubclassing)]) {
        Class<AVIMTypedMessageSubclassing> class = self;
        AVIMMessageMediaType mediaType = [class classMediaType];
        [self registerClass:class forMediaType:mediaType];
    }
}

+ (Class)classForMediaType:(AVIMMessageMediaType)mediaType {
    Class class = [_typeDict objectForKey:@(mediaType)];
    if (!class) {
        class = [AVIMTypedMessage class];
    }
    return class;
}

+ (void)registerClass:(Class)class forMediaType:(AVIMMessageMediaType)mediaType {
    if (!_typeDict) {
        _typeDict = [[NSMutableDictionary alloc] init];
    }
    Class c = [_typeDict objectForKey:@(mediaType)];
    if (!c || [class isSubclassOfClass:c]) {
        [_typeDict setObject:class forKey:@(mediaType)];
    }
}

+ (instancetype)messageWithText:(NSString *)text
               attachedFilePath:(NSString *)attachedFilePath
                     attributes:(NSDictionary *)attributes
{
    NSError *error = nil;
    
    AVFile *file = [AVFile fileWithLocalPath:attachedFilePath error:&error];
    
    if (error) {
        
        AVLoggerError(AVLoggerDomainStorage, @"Error: %@", error);
        
        return nil;
    }
    
    return [self messageWithText:text file:file attributes:attributes];
}

+ (instancetype)messageWithText:(NSString *)text
                           file:(AVFile *)file
                     attributes:(NSDictionary *)attributes {
    AVIMTypedMessage *message = [[self alloc] init];
    message.text = text;
    message.attributes = attributes;
    message.file = file;
    return message;
}

+ (AVFile *)fileFromDictionary:(NSDictionary *)dictionary {
    return dictionary ? [[AVFile alloc] initWithRawJSONData:dictionary.mutableCopy] : nil;
}

+ (AVGeoPoint *)locationFromDictionary:(NSDictionary *)dictionary {
    if (dictionary) {
        AVIMGeneralObject *object = [[AVIMGeneralObject alloc] initWithDictionary:dictionary];
        AVGeoPoint *location = [AVGeoPoint geoPointWithLatitude:object.latitude longitude:object.longitude];
        return location;
    } else {
        return nil;
    }
}

+ (instancetype)messageWithMessageObject:(AVIMTypedMessageObject *)messageObject {
    AVIMMessageMediaType mediaType = messageObject._lctype;
    Class class = [self classForMediaType:mediaType];
    AVIMTypedMessage *message = [[class alloc] init];
    message.messageObject = messageObject;
    message.file = [self fileFromDictionary:messageObject._lcfile];
    message.location = [self locationFromDictionary:messageObject._lcloc];
    return message;
}

+ (instancetype)messageWithDictionary:(NSDictionary *)dictionary {
    AVIMTypedMessageObject *messageObject = [[AVIMTypedMessageObject alloc] initWithDictionary:dictionary];
    return [self messageWithMessageObject:messageObject];
}

- (id)copyWithZone:(NSZone *)zone {
    AVIMTypedMessage *message = [super copyWithZone:zone];
    if (message) {
        message.messageObject = self.messageObject;
        message.file = self.file;
        message.location = self.location;
    }
    return message;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    NSData *data = [self.messageObject messagePack];
    [coder encodeObject:data forKey:@"typedMessage"];
}

- (instancetype)init {
    if (![self conformsToProtocol:@protocol(AVIMTypedMessageSubclassing)]) {
        [NSException raise:@"AVIMNotSubclassException" format:@"Class does not conform AVIMTypedMessageSubclassing protocol."];
    }
    if ((self = [super init])) {
        self.mediaType = [[self class] classMediaType];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        NSData *data = [coder decodeObjectForKey:@"typedMessage"];
        AVIMTypedMessageObject *object = [[AVIMTypedMessageObject alloc] initWithMessagePack:data];
        self.messageObject = object;
        self.file = [[self class] fileFromDictionary:object._lcfile];
        self.location = [[self class] locationFromDictionary:object._lcloc];
    }
    return self;
}

- (AVIMTypedMessageObject *)messageObject {
    if (!_messageObject) {
        _messageObject = [[AVIMTypedMessageObject alloc] init];
    }
    return _messageObject;
}

- (AVIMMessageMediaType)mediaType {
    return self.messageObject._lctype;
}

- (void)setMediaType:(AVIMMessageMediaType)mediaType {
    self.messageObject._lctype = mediaType;
}

- (NSString *)text {
    return self.messageObject._lctext;
}

- (void)setText:(NSString *)text {
    self.messageObject._lctext = text;
}

- (NSDictionary *)attributes {
    return self.messageObject._lcattrs;
}

- (void)setAttributes:(NSDictionary *)attributes {
    self.messageObject._lcattrs = attributes;
}

- (AVFile *)file {
    if (_file)
        return _file;

    NSDictionary *dictionary = self.messageObject._lcfile;

    if (dictionary)
        return [[AVFile alloc] initWithRawJSONData:dictionary.mutableCopy];

    return nil;
}

- (void)setFile:(AVFile *)file {
    _file = file;
    self.messageObject._lcfile = file ? [file rawJSONDataCopy] : nil;
}

- (AVGeoPoint *)location {
    if (_location)
        return _location;

    NSDictionary *dictionary = self.messageObject._lcloc;

    if (dictionary)
        return [AVGeoPoint geoPointFromDictionary:dictionary];

    return nil;
}

- (void)setLocation:(AVGeoPoint *)location {
    _location = location;
    self.messageObject._lcloc = location ? [AVGeoPoint dictionaryFromGeoPoint:location] : nil;
}

- (void)setObject:(id)object forKey:(NSString *)key {
    [self.messageObject setObject:object forKey:key];
}

- (id)objectForKey:(NSString *)key {
    return [self.messageObject objectForKey:key];
}

- (NSString *)payload {
    NSDictionary *dict = [self.messageObject dictionary];

    if (dict.count > 0) {
        return [self.messageObject JSONString];
    } else {
        return self.content;
    }
}

@end
