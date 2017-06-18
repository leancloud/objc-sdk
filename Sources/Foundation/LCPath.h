//
//  LCPath.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 18/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVApplication.h"

@interface LCPath : NSObject

@property (nonatomic, readonly, copy) NSString *sandbox;
@property (nonatomic, readonly, copy) NSString *userDefaults;

@property (nonatomic, readonly, copy) AVApplication *application;

- (instancetype)initWithApplication:(AVApplication *)application;

@end
