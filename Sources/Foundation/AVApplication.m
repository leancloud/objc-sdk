//
//  AVApplication.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 18/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVApplication.h"
#import "AVApplication+Internal.h"

@implementation AVApplication

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
    NSString *environment = self.environment;
    AVApplicationRegion region = self.region;

    AVApplication *application = [[[self class] alloc] initWithID:ID key:key region:region];
    application.environment = environment;

    return application;
}

- (void)doInitialize {
    _environment = @"Production";
}

@end
