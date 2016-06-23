//
//  LCMessageEntity.h
//  ChatApp
//
//  Created by Qihe Bian on 12/16/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "SQPObject.h"
#import "JSMessageData.h"

@interface LCMessageEntity : SQPObject <JSMessageData>
@property (nonatomic, strong) NSString *messageId;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSString *sender;
@property (nonatomic, strong) NSString *clientId;
@property (nonatomic, strong) NSString *conversationId;
@property (nonatomic, strong) NSDate *date;


@end
