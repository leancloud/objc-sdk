//
//  AVSDK.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 13/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 The AVSDK class provides a singleton instance representing the current SDK.
 From this instance you can obtain information about the SDK such as version number.
 */
@interface AVSDK : NSObject

/// The SDK version.
@property (nonatomic, readonly, strong) NSString *version;

/**
 Get an AVSDK singleton instance.
 
 @return An AVSDK singleton instance.
 */
+ (instancetype)current;

@end
