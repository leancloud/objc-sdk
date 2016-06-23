//
//  CDContactDetailController.h
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/28/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDBaseController.h"
#import "CDCommon.h"

@interface CDContactDetailController : CDBaseController
@property(nonatomic, strong) AVUser *user;

- (instancetype)initWithUser:(AVUser *)user;
@end
