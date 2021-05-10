//
//  AVIMGenericCommand+AVIMMessagesAdditions.h
//  LeanCloud
//
//  Created by 陈宜龙 on 15/11/18.
//  Copyright © 2015年 LeanCloud Inc. All rights reserved.
//

#import "MessagesProtoOrig.pbobjc.h"

@class LCIMConversationOutCommand;

typedef void (^LCIMCommandResultBlock)(AVIMGenericCommand *outCommand, AVIMGenericCommand *inCommand, NSError *error);

@interface AVIMGenericCommand (AVIMMessagesAdditions)

@property (nonatomic, copy) LCIMCommandResultBlock callback;

/*!
 做 conversation 缓存时，为了使 key 能兼容，需要将 AVIMGenericCommand 对象转换为 LCIMConversationOutCommand 对象
 @return AVIMGenericCommand 对应的 LCIMConversationOutCommand 对象
 */
- (LCIMConversationOutCommand *)avim_conversationForCache;

@end
