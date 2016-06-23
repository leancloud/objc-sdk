//
//  userInfo.m
//  AVOS_DEMO
//
//  Created by Albert on 13-9-8.
//  Copyright (c) 2013年 Albert. All rights reserved.
//

#import "UserInfo.h"
#import <AVOSCloud/AVObject+Subclass.h>

@implementation UserInfo

//@dynamic brithday,constellation,zodiac,telephone,mobile,address,zipcode,nationality,brithProvince,graduateSchool,company,education,bloodType,QQ,MSN,interest,abums;


+ (NSString *)parseClassName {
    return @"UserInfoSub";
}


@end
