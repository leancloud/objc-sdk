//
//  AVIMMessageObject.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/28/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMDynamicObject.h"
#import "AVIMMessage.h"

@interface AVIMMessageObject : AVIMDynamicObject

@property(nonatomic, assign) AVIMMessageIOType ioType;
@property(nonatomic, assign) AVIMMessageStatus status;
@property(nonatomic, strong) NSString *messageId;
@property(nonatomic, strong) NSString *clientId;
@property(nonatomic, strong) NSString *conversationId;
@property(nonatomic, strong) NSString *content;
@property(nonatomic, assign) int64_t sendTimestamp;
@property(nonatomic, assign) int64_t deliveredTimestamp;
@property(nonatomic, assign) int64_t readTimestamp;

@end
