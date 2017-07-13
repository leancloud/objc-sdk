//
//  AVApplication.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 18/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVNamedTable.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AVApplicationRegion) {
    AVApplicationRegionCN = 1,
    AVApplicationRegionUS
};

@interface AVApplicationIdentity : AVNamedTable

@property (nonatomic, readonly,   copy) NSString *ID;
@property (nonatomic, readonly,   copy) NSString *key;
@property (nonatomic, readonly, assign) AVApplicationRegion region;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithID:(NSString *)ID
                       key:(NSString *)key
                    region:(AVApplicationRegion)region NS_DESIGNATED_INITIALIZER;

@end

@interface AVApplicationModuleHosts : AVNamedTable

@property (nonatomic, copy, nullable) NSString *API;
@property (nonatomic, copy, nullable) NSString *engine;
@property (nonatomic, copy, nullable) NSString *push;
@property (nonatomic, copy, nullable) NSString *RTM;
@property (nonatomic, copy, nullable) NSString *statistics;

@end

@interface AVApplicationConfiguration : AVNamedTable

- (instancetype)init NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly, copy) AVApplicationModuleHosts *moduleHosts;

@end

@interface AVApplication : AVNamedTable

@property (nonatomic, readonly, copy) AVApplicationIdentity *identity;
@property (nonatomic, readonly, copy, nullable) AVApplicationConfiguration *configuration;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithIdentity:(AVApplicationIdentity *)identity
                   configuration:(nullable AVApplicationConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
