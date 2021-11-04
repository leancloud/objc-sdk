//
//  LCTestObject.m
//  LeanCloudObjcTests
//
//  Created by 黄驿峰 on 2021/10/26.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

#import "LCTestObject.h"

@implementation LCTestObject

@dynamic numberField;
@dynamic booleanField;
@dynamic stringField;
@dynamic arrayField;
@dynamic dictionaryField;
@dynamic objectField;
@dynamic relationField;
@dynamic geoPointField;
@dynamic dataField;
@dynamic dateField;
//@dynamic nullField;
@dynamic fileField;

+ (NSString *)parseClassName {
    return @"LCTestObject";
}

+ (void)initialize {
    [self registerSubclass];
}

@end
