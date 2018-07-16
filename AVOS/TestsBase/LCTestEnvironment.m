//
//  LCTestEnvironment.m
//  AVOS
//
//  Created by zapcannon87 on 2018/7/13.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "LCTestEnvironment.h"

@implementation LCTestEnvironment

+ (instancetype)sharedInstance
{
    static LCTestEnvironment *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LCTestEnvironment alloc] init];
        NSString *defaultString = @"default";
        sharedInstance.URL_API = ([LC_URL_API isEqualToString:defaultString] ? nil : LC_URL_API);
        sharedInstance.URL_RTM = ([LC_URL_RTM isEqualToString:defaultString] ? nil : LC_URL_RTM);
        sharedInstance.APP_ID = ([LC_APP_ID isEqualToString:defaultString] ? nil : LC_APP_ID);
        sharedInstance.APP_KEY = ([LC_APP_KEY isEqualToString:defaultString] ? nil : LC_APP_KEY);
        sharedInstance.APP_REGION = ([LC_APP_REGION isEqualToString:defaultString] ? nil : LC_APP_REGION);
        sharedInstance.isServerTesting = (LC_SERVER_TESTING ? true : false);
    });
    return sharedInstance;
}

@end
