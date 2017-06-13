//
//  LCDevice.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 13/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 The LCDevice class provides a singleton instance representing the current device.
 From this instance you can obtain current states of device, such as networking provider, platform, etc.
 */
@interface LCDevice : NSObject

/**
 Get an LCDevice singleton instance.

 @return An LCDevice singleton instance.
 */
+ (instancetype)current;

@end
