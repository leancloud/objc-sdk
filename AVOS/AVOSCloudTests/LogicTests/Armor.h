//
//  Armor.h
//  paas
//
//  Created by Summer on 13-4-2.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "AVOSCloud.h"
#import "AVSubclassing.h"
#import "UserBar.h"

typedef enum{
    Type1=1,
    Type2=2
}TypeEnum;

@interface Armor : AVObject<AVSubclassing>

@property (retain) NSString *displayName;
@property TypeEnum type;
@property(nonatomic) AVObject *seller;
@property int rupees;
@property BOOL fireproof;
@property (assign) double testDoubleValue;
@property (copy, nonatomic) NSString *nameForTextCopy;

@property float testFloatValue;
@property CGFloat testCGFloatValue;

@property (nonatomic, strong) UserBar *userBar;

@end

