//
//  LCApplication.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 14/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LCApplication : NSObject

/**
 Bundle version string.
 */
@property (nonatomic, readonly, strong) NSString *version;

/**
 Bundle short version string.
 */
@property (nonatomic, readonly, strong) NSString *shortVersion;

/**
 Bundle identifier.
 */
@property (nonatomic, readonly, strong) NSString *identifier;

/**
 Application name, aka. the display name.
 */
@property (nonatomic, readonly, strong) NSString *name;

/**
 Get an LCApplication singleton instance.

 @return An LCApplication singleton instance.
 */
+ (instancetype)current;

@end
