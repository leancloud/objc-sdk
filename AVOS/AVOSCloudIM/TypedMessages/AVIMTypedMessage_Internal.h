//
//  AVIMTypedMessage_Internal.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/8/15.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMTypedMessage.h"
#import "AVIMTypedMessageObject.h"
#import "AVIMMessage_Internal.h"

extern NSMutableDictionary const *_typeDict;

@interface AVIMTypedMessage ()

@property (nonatomic, strong) AVFile *file;
@property (nonatomic, strong) AVGeoPoint *location;
@property (nonatomic, strong) AVIMTypedMessageObject *messageObject;

+ (Class)classForMediaType:(AVIMMessageMediaType)mediaType;

+ (instancetype)messageWithMessageObject:(AVIMTypedMessageObject *)messageObject;
+ (instancetype)messageWithDictionary:(NSDictionary *)dictionary;

@end
