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
