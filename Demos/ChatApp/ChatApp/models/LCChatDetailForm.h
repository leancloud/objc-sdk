//
//  LCChatDetailForm.h
//  ChatApp
//
//  Created by Qihe Bian on 12/31/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FXForms.h"
#import "LCCommon.h"

@interface LCChatDetailForm : NSObject <FXForm>
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) AVIMConversation *conversation;
@end
