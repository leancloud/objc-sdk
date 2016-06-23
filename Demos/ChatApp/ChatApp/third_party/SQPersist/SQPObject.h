//
//  SQPObject.h
//  SQPersist
//
//  Created by Christopher Ney on 29/10/2014.
//  Copyright (c) 2014 Christopher Ney. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <objc/objc.h>
#include <objc/NSObjCRuntime.h>
#import <UIKit/UIKit.h>

#import "SQPDatabase.h"
#import "SQPProperty.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

/**
 *  Protocole of SQPObject
 */
@protocol SQPObjectDelegate
@optional
- (BOOL)ignoredProperty:(SQPProperty*)property;
- (id)defaultValueForProperty:(SQPProperty*)property;
@end

/**
 *  Entity object.
 */
@interface SQPObject : NSObject <SQPObjectDelegate> {
    
    /**
     *  Flag delete in cascade.
     */
    BOOL _deleteInCascade;
}

/**
 *  The name of the entity class.
 */
@property (nonatomic, strong) NSString *SQPClassName;

/**
 *  The name of teh associed table of the entity.
 */
@property (nonatomic, strong) NSString *SQPTableName;

/**
 *  Array of class properties.
 */
@property (nonatomic, strong) NSArray *SQPProperties;

/**
 *  Unique entity object identifier.
 */
@property (nonatomic, strong) NSString *objectID;

/**
 *  Set at YES, if you want remove the entity object.
 *  Need to call the SQPSaveEntity method to apply de DELETE SQL order.
 */
@property (nonatomic) BOOL deleteObject;

/**
 *  Create an entity of your object.
 *
 *  @return Entity object
 */
+ (id)SQPCreateEntity;

#pragma mark - Save

/**
 *  Save the modification of the entity object (by default save children objects with cascade option).
 *
 *  @return Return YES if the changes apply with succes.
 */
- (BOOL)SQPSaveEntity;

/**
  *  Save the modification of the entity object.
 *
 *  @param cascade Save children object in cascade.
 *
 *  @return Return YES if the changes apply with succes.
 */
- (BOOL)SQPSaveEntityWithCascade:(BOOL)cascade;

/**
 *  Delete the entity into the database (by default remove children objects with cascade option).
 *
 *  @return Return YES if the changes apply with succes.
 */
- (BOOL)SQPDeleteEntity;

/**
 *  Delete the entity into the database.
 *
 *  @param cascade Remove children object in cascade.
 *
 *  @return Return YES if the changes apply with succes.
 */
- (BOOL)SQPDeleteEntityWithCascade:(BOOL)cascade;

#pragma mark - Fetch

/**
 *  Return every entities save of table.
 *
 *  @return Array of entities.
 */
+ (NSMutableArray*)SQPFetchAll;

/**
 *  Return every entities save of table, with filtering conditions.
 *
 *  @param queryOptions Filtering conditions (clause SQL WHERE).
 *
 *  @return Array of entities.
 */
+ (NSMutableArray*)SQPFetchAllWhere:(NSString*)queryOptions;

/**
 *  Return every entities save of table, with filtering conditions and order.
 *
 *  @param queryOptions Filtering conditions (clause SQL WHERE).
 *  @param orderOptions Ordering conditions (clause SQL ORDER BY).
 *
 *  @return Array of entities.
 */
+ (NSMutableArray*)SQPFetchAllWhere:(NSString*)queryOptions orderBy:(NSString*)orderOptions;

/**
 *  Return every entities save of table, with filtering conditions and order, and pagination system.
 *
 *  @param queryOptions Filtering conditions (clause SQL WHERE).
 *  @param orderOptions Ordering conditions (clause SQL ORDER BY).
 *  @param pageIndex    Page index (start at 0 value).
 *  @param itemsPerPage Number of items per page.
 *
 *  @return Array of entities.
 */
+ (NSMutableArray*)SQPFetchAllWhere:(NSString*)queryOptions orderBy:(NSString*)orderOptions pageIndex:(NSInteger)pageIndex itemsPerPage:(NSInteger)itemsPerPage;

/**
 *  Return the first entity object.
 *
 *  @return The resulting entity object.
 */
+ (id)SQPFetchOne;

/**
 *  Return one entity object by filtering conditions.
 *
 *  @param queryOptions Filtering conditions (clause SQL WHERE).
 *
 *  @return The resulting entity object.
 */
+ (id)SQPFetchOneWhere:(NSString*)queryOptions;

/**
 *  Return one entity object.
 *
 *  @param objectID Unique entity object identifier.
 *
 *  @return The resulting entity object.
 */
+ (id)SQPFetchOneByID:(NSString*)objectID;

/**
 *  Return one entity object where the attrbute is equal to the value.
 *
 *  @param attribut Attribut name (entity object property name).
 *  @param value    Value of attribut.
 *
 *  @return The resulting entity object.
 */
+ (id)SQPFetchOneByAttribut:(NSString*)attribut withValue:(NSString*)value;

#pragma mark - Count

/**
 *  Return the number of entities save into the associated table.
 *
 *  @return Number of entities.
 */
+ (long long)SQPCountAll;

/**
 *  Return the number of entities save into the associated table, with filtering conditions.
 *
 *  @param queryOptions Filtering conditions (clause SQL WHERE).
 *
 *  @return Number of entities.
 */
+ (long long)SQPCountAllWhere:(NSString*)queryOptions;

#pragma mark - Truncate

/**
 *  Remove all entities of the table (TRUNCATE).
 *
 *  @return Return YES when the table is truncate.
 */
+ (BOOL)SQPTruncateAll;

#pragma mark - JSON

/**
 *  Serialized the object to Dictionary.
 *
 *  @return Dictionary
 */
- (NSMutableDictionary*)toDictionary;

/**
 *  Populate the object from Dictionary.
 *
 *  @param dictionary Dictionary
 *
 *  @return Return YES if all properties are set.
 */
- (BOOL)populateWithDictionary:(NSDictionary*)dictionary;

@end
