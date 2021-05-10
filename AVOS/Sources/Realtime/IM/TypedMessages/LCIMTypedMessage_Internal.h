//
//  LCIMTypedMessage_Internal.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 1/8/15.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMTypedMessage.h"
#import "LCIMTypedMessageObject.h"
#import "LCIMMessage_Internal.h"
#import "LCFile_Internal.h"
#import "LCGeoPoint_Internal.h"

extern NSMutableDictionary<NSNumber *, Class> const *_typeDict;

@interface LCIMTypedMessage ()

@property (nonatomic) LCIMTypedMessageObject *messageObject;

+ (instancetype)messageWithMessageObject:(LCIMTypedMessageObject *)messageObject;

- (NSString *)decodingUrl;
- (NSDictionary *)decodingMetaData;
- (NSString *)decodingName;
- (NSString *)decodingFormat;
- (double)decodingSize;
- (double)decodingWidth;
- (double)decodingHeight;
- (double)decodingDuration;

@end
