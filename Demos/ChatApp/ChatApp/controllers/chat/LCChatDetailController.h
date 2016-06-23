//
//  LCChatDetailController.h
//  ChatApp
//
//  Created by Qihe Bian on 12/31/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "FXForms.h"
#import "LCCommon.h"

@interface LCChatDetailController : FXFormViewController
@property(nonatomic, strong)AVIMConversation *conversation;

- (id)initWithConversation:(AVIMConversation *)conversation;
@end
