//
//  LCPush_Internal.h
//  Paas
//
//  Created by Zhu Zeng on 3/28/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import "LCPush.h"
#import "LCQuery.h"

@interface LCPush ()

@property (nonatomic, readwrite, strong) LCQuery * pushQuery;
@property (nonatomic, readwrite, strong) NSMutableArray * pushChannels;
@property (nonatomic, readwrite, strong) NSMutableDictionary * pushData;
@property (nonatomic, readwrite, strong) NSDate * expirationDate;
@property (nonatomic, readwrite, strong) NSDate * pushTime;
@property (nonatomic, readwrite) NSTimeInterval expireTimeInterval;
@property (nonatomic, readwrite, strong) NSMutableArray * pushTarget;

@end
