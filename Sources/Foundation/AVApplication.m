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
    self = [super init];

    if (self) {
        [self doInitialize];
    }

    return self;
}

- (instancetype)initWithID:(NSString *)ID key:(NSString *)key {
    self = [self init];

    if (self) {
        _ID = [ID copy];
        _key = [key copy];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [self init];

    if (self) {
        _ID = [aDecoder decodeObjectForKey:@"ID"];
        _key = [aDecoder decodeObjectForKey:@"key"];
        _environment = [aDecoder decodeObjectForKey:@"environment"];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.ID forKey:@"ID"];
    [aCoder encodeObject:self.key forKey:@"key"];
    [aCoder encodeObject:self.environment forKey:@"environment"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    AVApplication *application = [[[self class] alloc] initWithID:self.ID key:self.key];

    return application;
}

- (void)doInitialize {
    _environment = @"production";
}

@end
