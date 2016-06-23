//
//  LCConversationEntity.h
//  ChatApp
//
//  Created by Qihe Bian on 12/16/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "SQPObject.h"

@interface LCConversationEntity : SQPObject
@property (nonatomic, strong) NSString *conversationId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSArray *members;
@end
