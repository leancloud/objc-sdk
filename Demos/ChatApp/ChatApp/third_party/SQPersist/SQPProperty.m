//
//  SQPProperty.m
//  SQPersist
//
//  Created by Christopher Ney on 29/10/2014.
//  Copyright (c) 2014 Christopher Ney. All rights reserved.
//

#import "SQPProperty.h"

#define kAttributeInt @"Ti"
#define kAttributeBool @"TB"
#define kAttributeChar @"Tc"
#define kAttributeShort @"Ts"
#define kAttributeLong @"Tl"
#define kAttributeLongLong @"Tq"
#define kAttributeFloat @"Tf"
#define kAttributeDouble @"Td"

#define kAttributeNSNumber @"T@\"NSNumber\""
#define kAttributeNSDecimalNumber @"T@\"NSDecimalNumber\""
#define kAttributeNSString @"T@\"NSString\""
#define kAttributeNSDate @"T@\"NSDate\""
#define kAttributeNSData @"T@\"NSData\""
#define kAttributeNSArray @"T@\"NSArray\""
#define kAttributeNSMutableArray @"T@\"NSMutableArray\""
#define kAttributeUIImage @"T@\"UIImage\""
#define kAttributeNSURL @"T@\"NSURL\""
#define kAttributeObject @"T@"

@interface SQPProperty ()
- (BOOL)string:(NSString*)s containsSubString:(NSString*)ss;
- (NSString*)propertyTypeToString:(SQPPropertyType)type;
- (NSString*)getComplexTypeNameFromPropertyAttributes:(NSString*)propertyAttributes;
@end

/**
 *  Informations of one property of an entity object.
 */
@implementation SQPProperty

/**
 *  Build the SQPProperty with the attribute informations.
 *
 *  @param attributes Attribut informations.
 */
- (void)getPropertyType:(const char *)attributes {
    
    NSString *propertyAttributes = [NSString stringWithFormat:@"%s", attributes];
    
    // NSLog(@"%@", propertyAttributes);
    
    // Si c'est un type primitif :
    if ([self string:propertyAttributes containsSubString:@",&,"]) {
        
        self.isPrimitive = NO;
        
        if ([self string:propertyAttributes containsSubString:kAttributeNSNumber]) {
            self.type = kPropertyTypeNumber;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeNSDecimalNumber]) {
            self.type = kPropertyTypeDecimalNumber;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeNSString]) {
            self.type = kPropertyTypeString;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeNSDate]) {
            self.type = kPropertyTypeDate;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeNSData]) {
            self.type = kPropertyTypeData;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeNSArray]) {
            self.type = kPropertyTypeArray;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeNSMutableArray]) {
            self.type = kPropertyTypeMutableArray;
            self.isCompatibleType = NO;
        } else if ([self string:propertyAttributes containsSubString:kAttributeUIImage]) {
            self.type = kPropertyTypeImage;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeNSURL]) {
            self.type = kPropertyTypeURL;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeObject]) {
            self.type = kPropertyTypeObject;
            self.isCompatibleType = NO;
            self.complexTypeName = [self getComplexTypeNameFromPropertyAttributes:propertyAttributes];
        }
        
    } else {
        
        self.isPrimitive = YES;
        
        if ([self string:propertyAttributes containsSubString:kAttributeInt]) {
            self.type = kPropertyTypeInt;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeBool]) {
            self.type = kPropertyTypeBool;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeChar]) {
            self.type = kPropertyTypeChar;
            self.isCompatibleType = NO;
        } else if ([self string:propertyAttributes containsSubString:kAttributeShort]) {
            self.type = kPropertyTypeShort;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeLong]) {
            self.type = kPropertyTypeLong;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeLongLong]) {
            self.type = kPropertyTypeLongLong;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeFloat]) {
            self.type = kPropertyTypeFloat;
            self.isCompatibleType = YES;
        } else if ([self string:propertyAttributes containsSubString:kAttributeDouble]) {
            self.type = kPropertyTypeDouble;
            self.isCompatibleType = YES;
        }
        
    }
    
    // Si attirbut Non Atomic :
    if ([self string:propertyAttributes containsSubString:@",N,"]) {
        self.isNonatomic = YES;
    } else {
        self.isNonatomic = NO;
    }
}

/**
 *  Method extract the Class name of complex preperty attributes.
 *
 *  @param propertyAttributes Complex preperty attributes.
 *
 *  @return Class name.
 */
- (NSString*)getComplexTypeNameFromPropertyAttributes:(NSString*)propertyAttributes {
    
    NSString *typeName = nil;
    
    NSString *pattern = @"\\T@\"(.*?)\\\"";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
    NSArray *results = [regex matchesInString:propertyAttributes options:0 range:NSMakeRange(0, [propertyAttributes length])];
    
    if ([results count]) {
        NSTextCheckingResult *match = [results firstObject];
        NSRange matchRange = [match rangeAtIndex:1];
        typeName = [propertyAttributes substringWithRange:matchRange];
    }

    return typeName;
}

/**
 *  Return the name of Objective-C type (enum) - private method.
 *
 *  @param type Type of property.
 *
 *  @return Name of the type (NSString).
 */
- (NSString*)propertyTypeToString:(SQPPropertyType)type {
    
    if (type == kPropertyTypeInt) {
        return @"int";
    } else if (type == kPropertyTypeLong) {
        return @"long";
    } else if (type == kPropertyTypeLongLong) {
        return @"long long";
    } else if (type == kPropertyTypeBool) {
        return @"BOOL";
    } else if (type == kPropertyTypeDouble) {
        return @"double";
    } else if (type == kPropertyTypeFloat) {
        return @"float";
    } else if (type == kPropertyTypeChar) {
        return @"char";
    } else if (type == kPropertyTypeShort) {
        return @"short";
    } else if (type == kPropertyTypeNumber) {
        return @"NSNumber";
    } else if (type == kPropertyTypeDecimalNumber) {
        return @"NSDecimalNumber";
    } else if (type == kPropertyTypeString) {
        return @"NSString";
    } else if (type == kPropertyTypeDate) {
        return @"NSDate";
    } else if (type == kPropertyTypeData) {
        return @"NSData";
    } else if (type == kPropertyTypeArray) {
        return @"NSArray";
    } else if (type == kPropertyTypeMutableArray) {
        return @"NSMutableArray";
    } else if (type == kPropertyTypeImage) {
        return @"UIImage";
    } else if (type == kPropertyTypeURL) {
        return @"NSURL";
    } else if (type == kPropertyTypeObject) {
        
        if (self.isSQPObject == YES) {
            return @"SQPObject";
        } else {
            return @"id";
        }
 
    } else {
        return @"unknown";
    }
}

/**
 *  Return the SQLite type equal to the Objective-C type.
 *
 *  @return SQLite Type (INTEGER|REAL|TEXT|BLOB).
 */
- (NSString*)getSQLiteType {
    
    if (self.type == kPropertyTypeInt) {
        return @"INTEGER";
    } else if (self.type == kPropertyTypeLong) {
        return @"INTEGER";
    } else if (self.type == kPropertyTypeLongLong) {
        return @"INTEGER";
    } else if (self.type == kPropertyTypeBool) {
        return @"INTEGER";
    } else if (self.type == kPropertyTypeDouble) {
        return @"REAL";
    } else if (self.type == kPropertyTypeFloat) {
        return @"REAL";
    } else if (self.type == kPropertyTypeChar) {
        return @"TEXT";
    } else if (self.type == kPropertyTypeShort) {
        return @"INTEGER";
    } else if (self.type == kPropertyTypeNumber) {
        return @"REAL";
    } else if (self.type == kPropertyTypeDecimalNumber) {
        return @"REAL";
    } else if (self.type == kPropertyTypeString) {
        return @"TEXT";
    } else if (self.type == kPropertyTypeDate) {
        return @"INTEGER";
    } else if (self.type == kPropertyTypeData) {
        return @"BLOB";
    } else if (self.type == kPropertyTypeArray) {
        return @"BLOB";
    } else if (self.type == kPropertyTypeMutableArray) {
        return @"BLOB";
    } else if (self.type == kPropertyTypeObject) {
        
        if (self.isSQPObject == YES) {
            return @"TEXT";
        } else {
            return @"BLOB";
        }
        
    } else if (self.type == kPropertyTypeImage) {
        return @"BLOB";
    } else if (self.type == kPropertyTypeURL) {
        return @"TEXT";
    } else {
        return @"unknown";
    }
}

/**
 *  Description of the property.
 *
 *  @return Description. Example : @property (nonatomic) BOOL isExample;
 */
- (NSString *)description {
    
    NSMutableString *propertyLine = [[NSMutableString alloc] initWithString:@"@property"];
    
    if (self.isNonatomic) [propertyLine appendString:@" (nonatomic)"];
    
    [propertyLine appendFormat:@" %@", [self propertyTypeToString:self.type]];
    
    if (self.isPrimitive == NO) [propertyLine appendString:@" *"];
    
    [propertyLine appendFormat:@" %@;", self.name];
    
    if (self.value != nil) {
        [propertyLine appendFormat:@" // value = %@", [self.value description]];
    } else {
        [propertyLine appendString:@" // value = (null)"];
    }
    
    return propertyLine;
}

/**
 *  Check if string contains substring.
 *
 *  @param s  String chere search
 *  @param ss Substring to search
 *
 *  @return Return YES if the string contains substring.
 */
- (BOOL)string:(NSString*)s containsSubString:(NSString*)ss {
    if ([s rangeOfString:ss].location == NSNotFound) {
        return NO;
    } else {
        return YES;
    }
}

@end
