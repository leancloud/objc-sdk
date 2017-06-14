//
//  LCDevice.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 13/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

/**
 The LCDevice class provides a singleton instance representing the current device.
 From this instance you can obtain current states of device, such as networking provider, platform, etc.
 */
@interface LCDevice : NSObject

/**
 Detect whether an device is jailbroken.

 @note There's no reliable way to check whether a device is truely jailbroken.
 */
@property (nonatomic, readonly, assign) BOOL jailbroken;

/**
 The model of current device.
 */
@property (nonatomic, readonly, strong) NSString *model;

/**
 Screen size of current device, in pixels.
 */
@property (nonatomic, readonly, assign) CGSize screenSize;

/**
 System version of current OS.
 */
@property (nonatomic, readonly, strong) NSString *systemVersion;

/**
 Language of current system.
 */
@property (nonatomic, readonly, strong) NSString *language;

/**
 Timezone of current system.
 */
@property (nonatomic, readonly, strong) NSString *timezone;

/**
 Get an LCDevice singleton instance.

 @return An LCDevice singleton instance.
 */
+ (instancetype)current;

@end
