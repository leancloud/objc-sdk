//
//  LCObjectUtils.h
//  AVOSCloud
//
//  Created by Zhu Zeng on 7/4/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LCGlobal.h"
#import "LCGeoPoint.h"
#import "LCACL.h"
#import "LCObject.h"

@interface AVDate : NSObject

+ (NSDateFormatter *)iso8601DateFormatter;

+ (NSString *)stringFromDate:(NSDate *)date;
+ (NSDictionary *)dictionaryFromDate:(NSDate *)date;
+ (NSDate *)dateFromString:(NSString *)string;
+ (NSDate *)dateFromDictionary:(NSDictionary *)dictionary;
+ (NSDate *)dateFromValue:(id)value;

@end

@interface LCObjectUtils : NSObject


#pragma mark - Simple objecitive-c object from cloud side dictionary
+(NSData *)dataFromDictionary:(NSDictionary *)dict;
+(LCGeoPoint *)geoPointFromDictionary:(NSDictionary *)dict;
+(LCACL *)aclFromDictionary:(NSDictionary *)dict;
+(NSObject *)objectFromDictionary:(NSDictionary *)dict;
+ (NSObject *)objectFromDictionary:(NSDictionary *)dict recursive:(BOOL)recursive;
+(NSArray *)arrayFromArray:(NSArray *)array;

#pragma mark - Update Objecitive-c object from server side dictionary
+(void)copyDictionary:(NSDictionary *)src
             toObject:(LCObject *)target;

#pragma mark - Cloud side dictionary representation of objective-c object.
+(NSMutableDictionary *)dictionaryFromDictionary:(NSDictionary *)dic;
+(NSMutableArray *)dictionaryFromArray:(NSArray *)array;
+(NSDictionary *)dictionaryFromObjectPointer:(LCObject *)object;
+(NSDictionary *)dictionaryFromGeoPoint:(LCGeoPoint *)point;
+(NSDictionary *)dictionaryFromData:(NSData *)data;
+(NSDictionary *)dictionaryFromFile:(LCFile *)file;
+(NSDictionary *)dictionaryFromACL:(LCACL *)acl;
+ (id)dictionaryFromObject:(id)obj;
+ (id)dictionaryFromObject:(id)obj topObject:(BOOL)topObject;
+(NSDictionary *)childDictionaryFromObject:(LCObject *)object
                                     withKey:(NSString *)key;

#pragma mark - Object snapshot, usually for local cache.

+ (id)snapshotDictionary:(id)object;
+ (id)snapshotDictionary:(id)object recursive:(BOOL)recursive;

+ (NSMutableDictionary *)objectSnapshot:(LCObject *)object;
+ (NSMutableDictionary *)objectSnapshot:(LCObject *)object recursive:(BOOL)recursive;

+(LCObject *)lcObjectFromDictionary:(NSDictionary *)dict;
+(LCObject *)lcObjectForClass:(NSString *)className;
+(LCObject *)targetObjectFromRelationDictionary:(NSDictionary *)dict;

+(NSSet *)allObjectProperties:(Class)objectClass;

#pragma mark - Rebuild Relation
+(void)setupRelation:(LCObject *)parent
      withDictionary:(NSDictionary *)relationMap;


#pragma mark - batch request from operation list
+(BOOL)isUserClass:(NSString *)className;
+(BOOL)isRoleClass:(NSString *)className;
+(BOOL)isFileClass:(NSString *)className;
+(BOOL)isInstallationClass:(NSString *)className;
+(NSString *)objectPath:(NSString *)className
                   objectId:(NSString *)objectId;

#pragma mark - Array utils
+(BOOL)safeAdd:(NSDictionary *)dict
       toArray:(NSMutableArray *)array;

#pragma mark - key utils
+(BOOL)hasAnyKeys:(id)object;

+(NSString *)batchPath;
+(NSString *)batchSavePath;

@end
