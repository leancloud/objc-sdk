//
//  LCPreferences.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 17/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCPreferences.h"
#import "LCFoundation.h"

#if LC_TARGET_OS_TV
#import "LCUserDefaults.h"
#endif

@interface LCPreferences ()

@property (nonatomic, copy) AVApplication *application;

@end

@implementation LCPreferences

- (instancetype)init {
    self = [super init];

    if (self) {
        [self doInitialize];
    }

    return self;
}

- (instancetype)initWithApplication:(AVApplication *)application {
    self = [self init];

    if (self) {
        _application = [application copy];
    }

    return self;
}

- (void)doInitialize {
    /* TODO */
}

#if LC_TARGET_OS_TV

- (id<NSSecureCoding>)objectForKey:(NSString *)key {
    LCUserDefaults *userDefaults = [[LCUserDefaults alloc] initWithApplication:self.application];
    return userDefaults[key];
}

- (void)setObject:(id<NSSecureCoding>)object forKey:(NSString *)key {
    LCUserDefaults *userDefaults = [[LCUserDefaults alloc] initWithApplication:self.application];
    userDefaults[key] = object;
}

#endif

- (id<NSSecureCoding>)objectForKeyedSubscript:(NSString *)key {
    return [self objectForKey:key];
}

- (void)setObject:(id<NSSecureCoding>)object forKeyedSubscript:(NSString *)key {
    [self setObject:object forKey:key];
}

@end
