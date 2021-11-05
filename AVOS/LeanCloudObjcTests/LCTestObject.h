//
//  LCTestObject.h
//  LeanCloudObjcTests
//
//  Created by 黄驿峰 on 2021/10/26.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

#import <LeanCloudObjc/LeanCloudObjc.h>


@interface LCTestObject : LCObject <LCSubclassing>

@property (nonatomic, assign) NSInteger numberField;
@property (nonatomic, assign) BOOL booleanField;
@property (nonatomic, strong) NSString *stringField;
@property (nonatomic, strong) NSArray *arrayField;
@property (nonatomic, strong) NSDictionary *dictionaryField;
@property (nonatomic, strong) LCObject *objectField;
@property (nonatomic, strong) LCRelation *relationField;
@property (nonatomic, strong) LCGeoPoint *geoPointField;
@property (nonatomic, strong) NSData *dataField;
@property (nonatomic, strong) NSDate *dateField;
//@property (nonatomic, strong) NSMutableString *nullField;
@property (nonatomic, strong) NSMutableString *fileField;

@end


