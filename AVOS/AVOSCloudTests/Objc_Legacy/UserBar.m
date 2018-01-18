//
//  UserBar.m
//  
//
//  Created by Summer on 13-9-9.
//
//

#import "UserBar.h"
#import "AVObject+Subclass.h"

@implementation UserBar

@dynamic displayName;
@dynamic rupees;
@dynamic fireproof;

@dynamic testDoubleValue;
@dynamic nameForTextCopy;

@dynamic testFloatValue;
@dynamic testCGFloatValue;

+ (NSString *)parseClassName {
    return @"_User";
}

@end
