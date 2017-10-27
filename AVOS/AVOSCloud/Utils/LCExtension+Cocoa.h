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

 @param aClass a cocoa class.
 @return if the result is valid, then return True, else return False.
 */
- (BOOL)lc_isValidForTypeCheckingWith:(Class)aClass;

/**
 Type checking for a cocoa instance in runtime.

 @param aClass a cocoa class.
 @return if the result is invalid, then return True, else return False.
 */
- (BOOL)lc_isInvalidForTypeCheckingWith:(Class)aClass;

/**
 Strict type checking for a cocoa instance in runtime.

 @param aClass a cocoa class.
 @return if the result is valid, then return True, else return False.
 */
- (BOOL)lc_isValidForStrictTypeCheckingWith:(Class)aClass;

/**
 Strict type checking for a cocoa instance in runtime.

 @param aClass a cocoa class.
 @return if the result is invalid, then return True, else return False.
 */
- (BOOL)lc_isInvalidForStrictTypeCheckingWith:(Class)aClass;

@end
