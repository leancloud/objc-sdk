//
//  LCRelation_Internal.h
//  paas
//
//  Created by Zhu Zeng on 3/8/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import "LCRelation.h"

@interface LCRelation ()

@property (nonatomic, readwrite, copy) NSString * key;
@property (nonatomic, readwrite, weak) LCObject * parent;

+(LCRelation *)relationFromDictionary:(NSDictionary *)dict;

@end
