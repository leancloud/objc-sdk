//
//  LCTestEnvironment.h
//  AVOS
//
//  Created by zapcannon87 on 2018/7/13.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LCTestEnvironment : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, strong) NSString *URL_API;
@property (nonatomic, strong) NSString *URL_RTM;
@property (nonatomic, strong) NSString *APP_ID;
@property (nonatomic, strong) NSString *APP_KEY;
@property (nonatomic, strong) NSString *APP_REGION;
@property (nonatomic, assign) BOOL isServerTesting;

@end
