//
//  SQPProperty.h
//  SQPersist
//
//  Created by Christopher Ney on 29/10/2014.
//  Copyright (c) 2014 Christopher Ney. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/**
 Objective-C types of property.
 */
typedef enum SQPPropertyType : NSUInteger {
    kPropertyTypeInt,
    kPropertyTypeLong,
    kPropertyTypeLongLong,
    kPropertyTypeBool,
    kPropertyTypeDouble,
    kPropertyTypeFloat,
    kPropertyTypeChar,
    kPropertyTypeShort,
    kPropertyTypeNumber,
    kPropertyTypeDecimalNumber,
    kPropertyTypeString,
    kPropertyTypeDate,
    kPropertyTypeData,
    kPropertyTypeArray,
    kPropertyTypeMutableArray,
    kPropertyTypeImage,
    kPropertyTypeURL,
    kPropertyTypeObject
} SQPPropertyType;

/**
 *  Informations of one property of an entity object.
 */
@interface SQPProperty : NSObject

/**
 *  Property name.
 */
@property (nonatomic, strong) NSString *name;

/**
 *  Property value.
 */
@property (nonatomic, strong) id value;

/**
 *  Property type (enum SQPPropertyType).
 */
@property (nonatomic) SQPPropertyType type;

/**
 *  Indicate if the property is a primitive type (not complex).
 */
@property (nonatomic) BOOL isPrimitive;

/**
 *  Indicate that is nonatomic property.
 */
@property (nonatomic) BOOL isNonatomic;

/**
 *  Indicate that the property is a SQPObject type (entity object).
 */
@property (nonatomic) BOOL isSQPObject;

/**
 *  Indicate if the property is compatible for storage in SQLite database.
 */
@property (nonatomic) BOOL isCompatibleType;

/**
 *  If property if complex type, this member return the name of the complex type.
 */
@property (nonatomic, strong) NSString *complexTypeName;

/**
 *  Build the SQPProperty with the attribute informations.
 *
 *  @param attributes Attribut informations.
 */
- (void)getPropertyType:(const char *)attributes;

/**
 *  Return the SQLite type equal to the Objective-C type.
 *
 *  @return SQLite Type (INTEGER|REAL|TEXT|BLOB).
 */
- (NSString*)getSQLiteType;

@end
