//
//  LCChatMemberListCell.h
//  ChatApp
//
//  Created by Qihe Bian on 1/5/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "FXForms.h"
#import "LCCommon.h"

@interface LCChatMemberListCell : FXFormBaseCell
@property(nonatomic, strong)AVIMConversation *conversation;
@end
