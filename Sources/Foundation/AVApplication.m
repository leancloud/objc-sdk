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

- (void)doInitialize {
    _environment = @"Production";
}

@end

@implementation AVApplicationModuleHosts

@end

@implementation AVApplicationConfiguration

- (instancetype)init {
    self = [super init];

    if (self) {
        _moduleHosts = [[AVApplicationModuleHosts alloc] init];
    }

    return self;
}

@end

@implementation AVApplication

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

@end
