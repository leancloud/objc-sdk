//
//  AVIMTestBase.h
//  AVOS
//
//  Created by lzw on 15/7/6.
//  Copyright (c) 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVTestBase.h"
#import "AVOSCloudIM.h"

@interface AVIMTestBase : AVTestBase

- (void)openClientForTest;

- (AVIMConversation *)queryConversationById:(NSString *)convid;

- (AVIMConversation *)conversationForTest;
- (AVIMConversation *)transientConversationForTest;

@end
