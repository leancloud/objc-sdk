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
    return [self initWithID:nil key:nil];
}

- (instancetype)initWithID:(NSString *)ID key:(NSString *)key {
    self = [super init];

    if (self) {
        _ID = [ID copy];
        _key = [key copy];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    NSString *ID = [aDecoder decodeObjectForKey:@"ID"];
    NSString *key = [aDecoder decodeObjectForKey:@"key"];

    self = [self initWithID:ID key:key];

    if (self) {
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
    NSString *ID = self.ID;
    NSString *key = self.key;
    NSString *environment = self.environment;

    AVApplication *application = [[[self class] alloc] initWithID:ID key:key];
    application.environment = environment;

    return application;
}

- (void)doInitialize {
    _environment = @"Production";
}

@end
