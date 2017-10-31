//
//  LCExtension+Cocoa.m
//  AVOS
//
//  Created by ZapCannon87 on 26/10/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCExtension+Cocoa.h"

@implementation NSObject (LCExtension)

+ (BOOL)lc_isValidForCheckingTypeWith:(id)instance
{
    return (instance && [instance isKindOfClass:self]);
}

+ (BOOL)lc_isInvalidForCheckingTypeWith:(id)instance
{
    return ![self lc_isValidForCheckingTypeWith:instance];
}

+ (BOOL)lc_isValidForCheckingStrictTypeWith:(id)instance
{
    return (instance && [instance isMemberOfClass:self]);
}

+ (BOOL)lc_isInvalidForCheckingStrictTypeWith:(id)instance
{
    return ![self lc_isValidForCheckingStrictTypeWith:instance];
}

@end
