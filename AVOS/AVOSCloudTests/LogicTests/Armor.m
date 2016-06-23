//
//  Armor.m
//  paas
//
//  Created by Summer on 13-4-2.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "Armor.h"
#import "AVObject+Subclass.h"

@implementation Armor

@dynamic displayName;
@dynamic rupees;
@dynamic fireproof;

@dynamic testDoubleValue;
@dynamic nameForTextCopy;

@dynamic testFloatValue;
@dynamic testCGFloatValue;
@dynamic type,seller;

@dynamic userBar;

+ (NSString *)parseClassName {
    return @"Armor";
}

@end
