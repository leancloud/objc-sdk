//
//  LCUUID.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 14/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 This class can be used to generate universally unique identifier.
 */
@interface LCUUID : NSObject

/**
 Generate an UUID.

 @return A new UUID.
 */
+ (NSString *)createUUID;

@end
