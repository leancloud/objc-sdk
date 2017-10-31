//
//  LCExtension+Cocoa.h
//  AVOS
//
//  Created by ZapCannon87 on 26/10/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Utility for all cocoa object.
 */
@interface NSObject (LCExtension)

/**
 Type checking for a cocoa instance in runtime.

 @param instance a cocoa object's instance.
 @return if the result is valid, then return True, else return False.
 */
+ (BOOL)lc_isValidForCheckingTypeWith:(id)instance;

/**
 Type checking for a cocoa instance in runtime.

 @param instance a cocoa object's instance.
 @return if the result is invalid, then return True, else return False.
 */
+ (BOOL)lc_isInvalidForCheckingTypeWith:(id)instance;

/**
 Strict type checking for a cocoa instance in runtime.

 @param instance a cocoa object's instance.
 @return if the result is valid, then return True, else return False.
 */
+ (BOOL)lc_isValidForCheckingStrictTypeWith:(id)instance;

/**
 Strict type checking for a cocoa instance in runtime.

 @param instance a cocoa object's instance.
 @return if the result is invalid, then return True, else return False.
 */
+ (BOOL)lc_isInvalidForCheckingStrictTypeWith:(id)instance;

@end
