//
//  LeanCloudIM.h
//  LeanCloudIM
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
#import "LCIMMessage.h"
#import "LCIMMessageOption.h"
#import "LCIMTypedMessage.h"
#import "LCIMTextMessage.h"
#import "LCIMImageMessage.h"
#import "LCIMAudioMessage.h"
#import "LCIMVideoMessage.h"
#import "LCIMLocationMessage.h"
#import "LCIMFileMessage.h"
#import "LCIMRecalledMessage.h"
// signature
#import "LCIMSignature.h"

NS_ASSUME_NONNULL_BEGIN

@interface AVIMOptions : NSObject

@property (nonatomic, copy, nullable) NSString *RTMServer;

@end

@interface AVOSCloudIM : NSObject

+ (AVIMOptions *)defaultOptions;

@end

NS_ASSUME_NONNULL_END
