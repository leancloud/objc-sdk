//
//  AVOSCloudIM.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//


// In this header, you should import all the public headers of your framework using statements like #import <AVOSCloudIM/PublicHeader.h>

// Public headers
#import "AVIMAvailability.h"
#import "AVIMCommon.h"
#import "AVIMClient.h"
#import "AVIMConversation.h"
#import "AVIMConversationMemberInfo.h"
#import "AVIMKeyedConversation.h"
#import "AVIMConversationQuery.h"
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
#import "AVIMSignature.h"
#import "AVIMUserOptions.h"
#import "AVIMOptions.h"

NS_ASSUME_NONNULL_BEGIN

@interface AVOSCloudIM : NSObject

+ (AVIMOptions *)defaultOptions;

@end

NS_ASSUME_NONNULL_END
