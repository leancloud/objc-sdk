//
//  UserArmor.m
//  paas
//
//  Created by Summer on 13-9-9.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "UserArmor.h"
#import "AVObject+Subclass.h"

@implementation UserArmor

@dynamic displayName;
@dynamic rupees;
@dynamic fireproof;

@dynamic testDoubleValue;
@dynamic nameForTextCopy;

@dynamic testFloatValue;
@dynamic testCGFloatValue;

@dynamic  headView;
@dynamic nickName, registerIp, credits, numberOfRemind;//新提醒数
@dynamic location, userInfo, QQWeibo, SinaWeibo, RenRen, WeChat;

@dynamic armor;
@dynamic friends;

+ (NSString *)parseClassName {
    return @"_User";
}

@end
