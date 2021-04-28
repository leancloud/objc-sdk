//
//  AVOSCloudIM.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// constant
#import "LCIMCommon.h"
// client
#import "LCIMClientProtocol.h"
#import "LCIMClient.h"
#import "LCIMClientInternalConversationManager.h"
// conversation
#import "LCIMConversation.h"
#import "LCIMConversationMemberInfo.h"
#import "LCIMKeyedConversation.h"
// query
#import "LCIMConversationQuery.h"
// message
#import "AVIMMessage.h"
#import "AVIMMessageOption.h"
#import "AVIMTypedMessage.h"
#import "AVIMTextMessage.h"
#import "AVIMImageMessage.h"
#import "AVIMAudioMessage.h"
#import "AVIMVideoMessage.h"
#import "AVIMLocationMessage.h"
#import "AVIMFileMessage.h"
#import "AVIMRecalledMessage.h"
// signature
#import "AVIMSignature.h"

NS_ASSUME_NONNULL_BEGIN

@interface AVIMOptions : NSObject

@property (nonatomic, copy, nullable) NSString *RTMServer;

@end

@interface AVOSCloudIM : NSObject

+ (AVIMOptions *)defaultOptions;

@end

NS_ASSUME_NONNULL_END
