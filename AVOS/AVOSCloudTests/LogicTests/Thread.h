//
//  Thread.h
//  
//
//  Created by Albert on 13-9-13.
//  Copyright (c) 2013年 Albert. All rights reserved.
//

#import "AVObject.h"
#import "AVSubclassing.h"
#import "UserArmor.h"


@interface Thread : AVObject <AVSubclassing>

@property (nonatomic, retain) NSString *title;//主题名


@property (nonatomic, retain) UserArmor *postUser;//作者
@property (nonatomic, retain) UserArmor *lastPoster;//最后回帖人
@property (nonatomic, retain) NSString *tags;//标签 [tag]xxx[/tag]
@property (nonatomic, assign) int price;//积分

@property (nonatomic, assign) int views;//阅览次数

@property (nonatomic, assign) int viewsOfToday;//今天阅览次数

@property (nonatomic, assign) int viewsOfYesterday;//昨天阅览次数

@property (nonatomic, retain) AVRelation *faviconUser;//收藏人 //user

@property (nonatomic, retain) AVGeoPoint *location;//发帖地点

@property (nonatomic, retain) NSString *place;//发帖地点

@property (nonatomic, assign) int state;//状态 -1:关闭 0:一般 1:完成

@property (nonatomic, assign) int numberOfPosts;

@property (nonatomic, retain) AVRelation *posts;//回复主题的帖子 //Post


@end


@interface AVComment : AVObject <AVSubclassing>


@property (nonatomic, assign) int state;//状态 0:一般

@end

@interface AVSubComment : AVComment <AVSubclassing>


@property (nonatomic, assign) int subState;//状态 0:一般

@end



