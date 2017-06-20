//
//  AVApplication.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 18/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVApplication.h"
#import "AVApplication+Internal.h"

@implementation AVApplicationIdentity

- (instancetype)init {
    return [self initWithID:nil key:nil region:0];
}

- (instancetype)initWithID:(NSString *)ID
                       key:(NSString *)key
                    region:(AVApplicationRegion)region
{
    self = [super init];

    if (self) {
        _ID = [ID copy];
        _key = [key copy];
        _region = region;

        [self doInitialize];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    NSString *ID = [aDecoder decodeObjectForKey:@"ID"];
    NSString *key = [aDecoder decodeObjectForKey:@"key"];
    AVApplicationRegion region = [aDecoder decodeIntegerForKey:@"region"];

    self = [self initWithID:ID key:key region:region];

    if (self) {
        _environment = [aDecoder decodeObjectForKey:@"environment"];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.ID forKey:@"ID"];
    [aCoder encodeObject:self.key forKey:@"key"];
    [aCoder encodeObject:self.environment forKey:@"environment"];
    [aCoder encodeInteger:self.region forKey:@"region"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    NSString *ID = self.ID;
    NSString *key = self.key;
    AVApplicationRegion region = self.region;
    NSString *environment = self.environment;

    AVApplicationIdentity *identity = [[[self class] alloc] initWithID:ID key:key region:region];
    identity.environment = environment;

    return identity;
}

- (void)doInitialize {
    _environment = @"Production";
}

@end

@implementation AVApplicationModuleHosts

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];

    if (self) {
        _API        = [aDecoder decodeObjectForKey:@"API"];
        _engine     = [aDecoder decodeObjectForKey:@"engine"];
        _push       = [aDecoder decodeObjectForKey:@"push"];
        _RTM        = [aDecoder decodeObjectForKey:@"RTM"];
        _statistics = [aDecoder decodeObjectForKey:@"statistics"];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.API           forKey:@"API"];
    [aCoder encodeObject:self.engine        forKey:@"engine"];
    [aCoder encodeObject:self.push          forKey:@"push"];
    [aCoder encodeObject:self.RTM           forKey:@"RTM"];
    [aCoder encodeObject:self.statistics    forKey:@"statistics"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    AVApplicationModuleHosts *moduleHosts = [[[self class] alloc] init];

    moduleHosts.API         = self.API;
    moduleHosts.engine      = self.engine;
    moduleHosts.push        = self.push;
    moduleHosts.RTM         = self.RTM;
    moduleHosts.statistics = self.statistics;

    return moduleHosts;
}

@end

@interface AVApplicationConfiguration ()

@property (nonatomic, copy) AVApplicationModuleHosts *moduleHosts;

@end

@implementation AVApplicationConfiguration

- (instancetype)init {
    self = [super init];

    if (self) {
        _moduleHosts = [[AVApplicationModuleHosts alloc] init];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];

    if (self) {
        _moduleHosts = [aDecoder decodeObjectForKey:@"moduleHosts"];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.moduleHosts forKey:@"moduleHosts"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    AVApplicationConfiguration *configuration = [[[self class] alloc] init];

    configuration.moduleHosts = self.moduleHosts;

    return configuration;
}

@end

@implementation AVApplication

- (instancetype)init {
    return [self initWithIdentity:nil configuration:nil];
}

- (instancetype)initWithIdentity:(AVApplicationIdentity *)identity
                   configuration:(AVApplicationConfiguration *)configuration
{
    self = [super init];

    if (self) {
        _identity = [identity copy];
        _configuration = [configuration copy];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    AVApplicationIdentity *identity = [aDecoder decodeObjectForKey:@"identity"];
    AVApplicationConfiguration *configuration = [aDecoder decodeObjectForKey:@"configuration"];

    self = [self initWithIdentity:identity configuration:configuration];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.identity forKey:@"identity"];
    [aCoder encodeObject:self.configuration forKey:@"configuration"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    AVApplicationIdentity *identity = self.identity;
    AVApplicationConfiguration *configuration = self.configuration;

    AVApplication *application = [[[self class] alloc] initWithIdentity:identity configuration:configuration];

    return application;
}

@end
