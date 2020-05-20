//
//  LCRTMConnection.m
//  AVOSCloudIM
//
//  Created by pzheng on 2020/05/20.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

#import "LCRTMConnection.h"

@implementation LCRTMConnectionManager

+ (instancetype)sharedManager
{
    static LCRTMConnectionManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LCRTMConnectionManager alloc] init];
    });
    return sharedInstance;
}

@end

@implementation LCRTMConnection

@end
