//
//  AVApplication.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 18/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, AVApplicationRegion) {
    AVApplicationRegionCN = 1,
    AVApplicationRegionUS
};

@interface AVApplication : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, readonly,   copy) NSString *ID;
@property (nonatomic, readonly,   copy) NSString *key;
@property (nonatomic, readonly, assign) AVApplicationRegion region;

- (instancetype)initWithID:(NSString *)ID key:(NSString *)key region:(AVApplicationRegion)region;

@end
