//
//  LCContactDetailController.h
//  ChatApp
//
//  Created by Qihe Bian on 12/24/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCBaseController.h"
#import "LCUser.h"
@interface LCContactDetailController : LCBaseController
@property(nonatomic, strong) LCUser *user;

- (instancetype)initWithUser:(LCUser *)user;
@end
