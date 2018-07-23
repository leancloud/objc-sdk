//
//  AVOSCloudIM.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

// misc
#import "AVIMAvailability.h"
#import "AVIMCommon.h"
#import "AVIMUserOptions.h"
#import "AVIMOptions.h"
// client
#import "AVIMClient.h"
#import "AVIMClientInternalConversationManager.h"
// conversation
#import "AVIMConversation.h"
#import "AVIMConversationMemberInfo.h"
#import "AVIMKeyedConversation.h"
// query
#import "AVIMConversationQuery.h"
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

@interface AVOSCloudIM : NSObject

+ (AVIMOptions *)defaultOptions;

@end

NS_ASSUME_NONNULL_END
