//
//  UserArmor.h
//  paas
//
//  Created by Summer on 13-9-9.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import <AVOSCloud/AVOSCloud.h>
#import "AVSubclassing.h"
#import "UserInfo.h"
#import "Armor.h"


@interface UserArmor : AVUser<AVSubclassing>

+ (NSString *)parseClassName;

@property (retain) NSString *displayName;
@property int rupees;
@property BOOL fireproof;
@property (assign) double testDoubleValue;
@property (copy, nonatomic) NSString *nameForTextCopy;

@property float testFloatValue;
@property CGFloat testCGFloatValue;
@property (nonatomic, retain) UserInfo *userInfo;


@property (nonatomic, retain) NSString *nickName;//昵称

@property (nonatomic, retain) AVFile *headView;//头像

@property (nonatomic, retain) NSString *registerIp;//注册ip

@property (nonatomic, readonly) double credits;//积分

@property (nonatomic, readonly) NSInteger numberOfRemind;//新提醒数

@property (nonatomic, retain) AVGeoPoint *location;


//@property (nonatomic, retain) UserCount *userCount;

@property (nonatomic, retain) NSString *QQWeibo;

@property (nonatomic, retain) NSString *SinaWeibo;

@property (nonatomic, retain) NSString *RenRen;

@property (nonatomic, retain) NSString *WeChat;

@property (nonatomic, strong) Armor *armor;

@property (nonatomic, strong) AVRelation * friends;

@end
