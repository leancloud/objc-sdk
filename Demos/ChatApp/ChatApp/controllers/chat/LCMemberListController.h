//
//  LCMemberListController.h
//  ChatApp
//
//  Created by Qihe Bian on 1/6/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCBaseTableController.h"
#import "LCCommon.h"
#import "FXForms.h"

@interface LCMemberListController : LCBaseTableController <FXFormFieldViewController>
@property (nonatomic, strong) FXFormField *field;
@property(nonatomic, strong)AVIMConversation *conversation;
@end
