//
//  LCExtension+Cocoa.m
//  AVOS
//
//  Created by ZapCannon87 on 26/10/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCExtension+Cocoa.h"

@implementation NSObject (LCExtension)

- (BOOL)lc_isValidForTypeCheckingWith:(Class)aClass
{
    return (self && [self isKindOfClass:aClass]);
}

- (BOOL)lc_isInvalidForTypeCheckingWith:(Class)aClass
{
    return ![self lc_isValidForTypeCheckingWith:aClass];
}

- (BOOL)lc_isValidForStrictTypeCheckingWith:(Class)aClass
{
    return (self && [self isMemberOfClass:aClass]);
}

- (BOOL)lc_isInvalidForStrictTypeCheckingWith:(Class)aClass
{
    return ![self lc_isValidForStrictTypeCheckingWith:aClass];
}

@end
