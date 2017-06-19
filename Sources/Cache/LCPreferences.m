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
#else
    #import "LCKeyValueStore.h"
    #import "LCPath.h"
#endif

@interface LCPreferences ()

@property (nonatomic, copy) AVApplication *application;

#if !LC_TARGET_OS_TV
@property (nonatomic, strong) LCKeyValueStore *userDefaultsStore;
#endif

@end

@implementation LCPreferences

- (instancetype)init {
    return [self initWithApplication:nil];
}

- (instancetype)initWithApplication:(AVApplication *)application {
    self = [super init];

    if (self) {
        _application = [application copy];

        [self doInitialize];
    }

    return self;
}

#if LC_TARGET_OS_TV

- (void)doInitialize {
    /* Do nothing for tvOS target. */
}

- (id<NSSecureCoding>)objectForKey:(NSString *)key {
    LCUserDefaults *userDefaults = [[LCUserDefaults alloc] initWithApplication:self.application];
    return userDefaults[key];
}

- (void)setObject:(id<NSSecureCoding>)object forKey:(NSString *)key {
    LCUserDefaults *userDefaults = [[LCUserDefaults alloc] initWithApplication:self.application];
    userDefaults[key] = object;
}

#else

- (void)doInitialize {
    LCPath *path = [[LCPath alloc] initWithApplication:_application];
    NSString *userDefaultsPath = path.userDefaults;
    NSString *databasePath = [[[NSURL fileURLWithPath:userDefaultsPath] URLByAppendingPathComponent:@"UserDefaults.db"] path];

    _userDefaultsStore = [[LCKeyValueStore alloc] initWithDatabasePath:databasePath tableName:@"UserDefaults"];
}

- (id<NSSecureCoding>)objectForKey:(NSString *)key {
    NSData *data = [self.userDefaultsStore dataForKey:key];

    if (!data)
        return nil;

    id object = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    return object;
}

- (void)setObject:(id<NSSecureCoding>)object forKey:(NSString *)key {
    if (object) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
        [self.userDefaultsStore setData:data forKey:key];
    } else {
        [self.userDefaultsStore removeDataForKey:key];
    }
}

#endif

- (id<NSSecureCoding>)objectForKeyedSubscript:(NSString *)key {
    return [self objectForKey:key];
}

- (void)setObject:(id<NSSecureCoding>)object forKeyedSubscript:(NSString *)key {
    [self setObject:object forKey:key];
}

@end
