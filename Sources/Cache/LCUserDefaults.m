//
//  LCUserDefaults.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 17/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCUserDefaults.h"
#import "AVApplication+Internal.h"

static NSString *const LCRootKeyPrefix = @"LeanCloud";

@interface LCUserDefaults ()

@property (nonatomic,   copy) AVApplication *application;
@property (nonatomic, strong) NSUserDefaults *userDefaults;

@property (nonatomic, readonly, strong) NSString *rootKey;
@property (nonatomic, readonly, strong) NSMutableDictionary *rootObject;

@end

@implementation LCUserDefaults

@synthesize rootObject = _rootObject;

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
    _userDefaults = [NSUserDefaults standardUserDefaults];
}

- (NSString *)rootKey {
    NSString *relativePath = self.application.relativePath;

    if (!relativePath)
        return nil;

    NSURL *URL = [[[NSURL fileURLWithPath:LCRootKeyPrefix]
                   URLByAppendingPathComponent:relativePath]
                   URLByAppendingPathComponent:@"UserDefaults"];

    NSString *rootKey = [URL path];

    return rootKey;
}

- (NSMutableDictionary *)rootObject {
    if (_rootObject)
        return _rootObject;

    @synchronized (self) {
        if (_rootObject)
            return _rootObject;

        NSString *rootKey = self.rootKey;

        if (!rootKey)
            return nil;

        NSDictionary *rootObject = [self.userDefaults objectForKey:rootKey];

        if (rootObject)
            _rootObject = [[NSMutableDictionary alloc] initWithDictionary:rootObject copyItems:YES];
        else
            _rootObject = [NSMutableDictionary dictionary];

        return _rootObject;
    }
}

- (id<NSSecureCoding>)objectForKey:(NSString *)key {
    if (!key)
        return nil;

    @synchronized (self) {
        NSDictionary *rootObject = self.rootObject;
        return rootObject[key];
    }
}

- (void)setObject:(id<NSSecureCoding>)object forKey:(NSString *)key {
    if (!key)
        return;

    @synchronized (self) {
        NSMutableDictionary *rootObject = self.rootObject;
        rootObject[key] = object;
        [self synchronize];
    }
}

- (id<NSSecureCoding>)objectForKeyedSubscript:(NSString *)key {
    return [self objectForKey:key];
}

- (void)setObject:(id<NSSecureCoding>)object forKeyedSubscript:(NSString *)key {
    [self setObject:object forKey:key];
}

- (void)synchronize {
    NSString *rootKey = self.rootKey;
    NSDictionary *rootObject = [self.rootObject copy];

    if (!rootKey)
        return;
    if (!rootObject)
        return;

    [self.userDefaults setObject:rootObject forKey:rootKey];
    [self.userDefaults synchronize];
}

@end
