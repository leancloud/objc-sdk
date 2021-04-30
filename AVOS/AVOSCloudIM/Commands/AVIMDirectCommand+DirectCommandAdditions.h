//
//  AVIMDirectCommand+DirectCommandAdditions.h
//  AVOS
//
//  Created by 陈宜龙 on 16/1/8.
//  Copyright © 2016年 LeanCloud Inc. All rights reserved.
//

#import "MessagesProtoOrig.pbobjc.h"
#import "LCIMMessage.h"

@interface AVIMDirectCommand (DirectCommandAdditions)

@property(nonatomic, strong) LCIMMessage *message;

@end
