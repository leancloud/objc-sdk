//
//  AVApplication.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 18/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVNamedTable.h"

typedef NS_ENUM(NSInteger, AVApplicationRegion) {
    AVApplicationRegionCN = 1,
    AVApplicationRegionUS
};

@interface AVApplicationIdentity : AVNamedTable

@property (nonatomic, readonly,   copy) NSString *ID;
@property (nonatomic, readonly,   copy) NSString *key;
@property (nonatomic, readonly, assign) AVApplicationRegion region;

- (instancetype)initWithID:(NSString *)ID
                       key:(NSString *)key
                    region:(AVApplicationRegion)region;

@end

@interface AVApplicationModuleHosts : AVNamedTable

@property (nonatomic, copy) NSString *API;
@property (nonatomic, copy) NSString *engine;
@property (nonatomic, copy) NSString *push;
@property (nonatomic, copy) NSString *RTM;
@property (nonatomic, copy) NSString *statistics;

@end

@interface AVApplicationConfiguration : AVNamedTable

@property (nonatomic, readonly, copy) AVApplicationModuleHosts *moduleHosts;

@end

@interface AVApplication : AVNamedTable

@property (nonatomic, readonly, copy) AVApplicationIdentity *identity;
@property (nonatomic, readonly, copy) AVApplicationConfiguration *configuration;

- (instancetype)initWithIdentity:(AVApplicationIdentity *)identity
                   configuration:(AVApplicationConfiguration *)configuration;

@end
