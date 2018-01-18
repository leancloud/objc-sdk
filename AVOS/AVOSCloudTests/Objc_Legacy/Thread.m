//
//  Thread.m
//
//
//  Created by Albert on 13-9-13.
//  Copyright (c) 2013年 Albert. All rights reserved.
//

#import "Thread.h"
#import "AVObject+Subclass.h"

@implementation Thread

@dynamic title,  postUser, lastPoster, tags;
@dynamic price, views, viewsOfToday,  viewsOfYesterday;//昨天阅览次数

@dynamic faviconUser, location, place, state, numberOfPosts;

@dynamic posts;

+ (NSString *)parseClassName
{
    return @"Thread";
}   

@end



@implementation AVComment

@dynamic state;

+ (NSString *)parseClassName
{
    return @"SubclassComment";
}

@end


@implementation AVSubComment

@dynamic subState;

@end

