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
    NSString *defaultString = @"default";
    static LCTestEnvironment *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LCTestEnvironment alloc] init];
        sharedInstance.URL_API = ([LC_URL_API isEqualToString:defaultString] ? nil : LC_URL_API);
        sharedInstance.URL_RTMRouter = ([LC_URL_RTMRouter isEqualToString:defaultString] ? nil : LC_URL_RTMRouter);
        sharedInstance.URL_RTMServer = ([LC_URL_RTMServer isEqualToString:defaultString] ? nil : LC_URL_RTMServer);
        sharedInstance.APP_ID = ([LC_APP_ID isEqualToString:defaultString] ? nil : LC_APP_ID);
        sharedInstance.APP_KEY = ([LC_APP_KEY isEqualToString:defaultString] ? nil : LC_APP_KEY);
        sharedInstance.isServerTesting = (LC_SERVER_TESTING ? true : false);
    });
    NSLog(@"LCTestEnvironment: URL_API = %@", (sharedInstance.URL_API ?: defaultString));
    NSLog(@"LCTestEnvironment: URL_RTMRouter = %@", (sharedInstance.URL_RTMRouter ?: defaultString));
    NSLog(@"LCTestEnvironment: URL_RTMServer = %@", (sharedInstance.URL_RTMServer ?: defaultString));
    NSLog(@"LCTestEnvironment: APP_ID = %@", (sharedInstance.APP_ID ?: defaultString));
    NSLog(@"LCTestEnvironment: APP_KEY = %@", (sharedInstance.APP_KEY ?: defaultString));
    NSLog(@"LCTestEnvironment: isServerTesting = %@", (sharedInstance.isServerTesting ? @"true" : @"false"));
    return sharedInstance;
}

@end
