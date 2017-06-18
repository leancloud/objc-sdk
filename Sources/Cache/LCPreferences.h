//
//  LCPreferences.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 17/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVOSCloudFoundation.h"

@interface LCPreferences : NSObject

@property (nonatomic, readonly, copy) AVApplication *application;

- (instancetype)initWithApplication:(AVApplication *)application;

- (id<NSSecureCoding>)objectForKey:(NSString *)key;
- (void)setObject:(id<NSSecureCoding>)object forKey:(NSString *)key;

- (id<NSSecureCoding>)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id<NSSecureCoding>)object forKeyedSubscript:(NSString *)key;

@end
