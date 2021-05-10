//
//  LCRole_Internal.h
//  paas
//
//  Created by Zhu Zeng on 3/13/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import "LCRole.h"

@class LCACL;

@interface LCRole ()

@property (nonatomic, readwrite, strong) LCACL * acl;
@property (nonatomic, readwrite, strong) NSMutableDictionary * relationData;

+(instancetype)role;

+(NSString *)className;
+(NSString *)endPoint;

@end
