//
//  LCChatController.h
//  ChatApp
//
//  Created by Qihe Bian on 12/24/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "JSMessagesViewController.h"
#import "LCCommon.h"

@interface LCChatController : JSMessagesViewController
@property (nonatomic, strong) AVIMConversation *conversation;

@end
