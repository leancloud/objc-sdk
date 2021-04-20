//
//  AVFriendQuery.m
//  paas
//
//  Created by Travis on 14-1-26.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import "AVFriendQuery.h"
#import "AVQuery_Internal.h"
#import "LCObjectUtils.h"
#import "AVErrorUtils.h"
#import "AVQuery_Internal.h"

@implementation AVFriendQuery

// only called in findobjects, these object's data is ready
- (NSMutableArray *)processResults:(NSArray *)results className:(NSString *)className
{
    NSMutableArray * users = [NSMutableArray array];
    
    for (NSDictionary *dict in [results copy]) {
        id target = dict[self.targetFeild];
        if (target && [target isKindOfClass:[NSDictionary class]]) {
            LCObject *obj= [LCObjectUtils lcObjectFromDictionary:target];
            [users addObject:obj];
        }
    }
    
    return (id)users;
}

@end
