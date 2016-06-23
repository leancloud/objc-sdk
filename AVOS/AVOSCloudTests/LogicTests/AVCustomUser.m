//
//  AVCustomUser.m
//  AVOS
//
//  Created by lzw on 15/10/22.
//  Copyright © 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVCustomUser.h"

@implementation AVCustomUser

@dynamic title;

+ (NSString *)parseClassName {
    return @"_User";
}

@end
