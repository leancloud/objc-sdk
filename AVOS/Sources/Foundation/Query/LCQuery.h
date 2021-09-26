// LCQuery.m
// Copyright 2013 LeanCloud Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import "LCGeoPoint.h"
#import "LCObject.h"
#import "LCCloudQueryResult.h"

/// Cache policies
typedef NS_ENUM(NSInteger, LCCachePolicy) {
    /// Query from server and do not save result to the local cache.
    kLCCachePolicyIgnoreCache = 0,
    /// Only query from the local cache.
    kLCCachePolicyCacheOnly,
    /// Only query from server, and save result to the local cache.
    kLCCachePolicyNetworkOnly,
    /// Firstly query from the local cache, if fails, query from server.
    kLCCachePolicyCacheElseNetwork,
    /// Firstly query from server, if fails, query the local cache.
    kLCCachePolicyNetworkElseCache,
    /// Firstly query from the local cache, return result. Then query from server, return result. The callback will be called twice.
    kLCCachePolicyCacheThenNetwork,
};

/*!
 * Distance unit for query.
 */
typedef NS_ENUM(NSInteger, LCQueryDistanceUnit) {
    LCQueryDistanceUnitMile = 1,
    LCQueryDistanceUnitKilometer,
    LCQueryDistanceUnitRadian
};

NS_ASSUME_NONNULL_BEGIN

/*!
 A class that defines a query that is used to query for LCObjects.
 */
@interface LCQuery : NSObject

#pragma mark Query options

/** @name Creating a Query for a Class */

/*!
 Returns a LCQuery for a given class.
 @param className The class to query on.
 @return A LCQuery object.
 */
+ (instancetype)queryWithClassName:(NSString *)className;

/*!
 *  使用 CQL 查询
 *  @param cql CQL 字符串
 *  @return 查询结果
 */
+ (nullable LCCloudQueryResult *)doCloudQueryWithCQL:(NSString *)cql;

/*!
 *  使用 CQL 查询
 *  @param cql CQL 字符串
 *  @param error 用于返回错误结果
 *  @return 查询结果
 */
+ (nullable LCCloudQueryResult *)doCloudQueryWithCQL:(NSString *)cql error:(NSError **)error;

/*!
 *  使用 CQL 查询
 *  @param cql CQL 字符串
 *  @param pvalues 参数列表
 *  @param error 用于返回错误结果
 *  @return 查询结果
 */
+ (nullable LCCloudQueryResult *)doCloudQueryWithCQL:(NSString *)cql pvalues:(nullable NSArray *)pvalues error:(NSError **)error;

/*!
 *  使用 CQL 异步查询
 *  @param cql CQL 字符串
 *  @param callback 查询结果回调
 */
+ (void)doCloudQueryInBackgroundWithCQL:(NSString *)cql callback:(LCCloudQueryCallback)callback;

/*!
 *  使用 CQL 异步查询
 *  @param cql CQL 字符串
 *  @param pvalues 参数列表
 *  @param callback 查询结果回调
 */
+ (void)doCloudQueryInBackgroundWithCQL:(NSString *)cql pvalues:(nullable NSArray *)pvalues callback:(LCCloudQueryCallback)callback;

/*!
 Initializes the query with a class name.
 @param newClassName The class name.
 */
- (instancetype)initWithClassName:(NSString *)newClassName;

/*!
  The class name to query for
 */
@property (nonatomic, copy) NSString *className;

/** @name Adding Basic Constraints */

/*!
 Make the query include LCObjects that have a reference stored at the provided key.
 This has an effect similar to a join.  You can use dot notation to specify which fields in
 the included object are also fetch.
 @param key The key to load child LCObjects for.
 */
- (void)includeKey:(NSString *)key;

/// Reset included keys.
- (void)resetIncludeKey;

/*!
 Make the query restrict the fields of the returned LCObjects to include only the provided keys.
 If this is called multiple times, then all of the keys specified in each of the calls will be included.
 @param keys The keys to include in the result.
 */
- (void)selectKeys:(NSArray<NSString *> *)keys;

/// Reset selected keys.
- (void)resetSelectKey;

/*!
 Add a constraint that requires a particular key exists.
 @param key The key that should exist.
 */
- (void)whereKeyExists:(NSString *)key;

/*!
 Add a constraint that requires a key not exist.
 @param key The key that should not exist.
 */
- (void)whereKeyDoesNotExist:(NSString *)key;

/*!
  Add a constraint to the query that requires a particular key's object to be equal to the provided object.
 @param key The key to be constrained.
 @param object The object that must be equalled.
 */
- (void)whereKey:(NSString *)key equalTo:(id)object;

/*!
  Add a constraint to the query that requires a particular key's object to be less than the provided object.
 @param key The key to be constrained.
 @param object The object that provides an upper bound.
 */
- (void)whereKey:(NSString *)key lessThan:(id)object;

/*!
  Add a constraint to the query that requires a particular key's object to be less than or equal to the provided object.
 @param key The key to be constrained.
 @param object The object that must be equalled.
 */
- (void)whereKey:(NSString *)key lessThanOrEqualTo:(id)object;

/*!
  Add a constraint to the query that requires a particular key's object to be greater than the provided object.
 @param key The key to be constrained.
 @param object The object that must be equalled.
 */
- (void)whereKey:(NSString *)key greaterThan:(id)object;

/*!
  Add a constraint to the query that requires a particular key's object to be greater than or equal to the provided object.
 @param key The key to be constrained.
 @param object The object that must be equalled.
 */
- (void)whereKey:(NSString *)key greaterThanOrEqualTo:(id)object;

/*!
  Add a constraint to the query that requires a particular key's object to be not equal to the provided object.
 @param key The key to be constrained.
 @param object The object that must not be equalled.
 */
- (void)whereKey:(NSString *)key notEqualTo:(id)object;

/*!
  Add a constraint to the query that requires a particular key's object to be contained in the provided array.
 @param key The key to be constrained.
 @param array The possible values for the key's object.
 */
- (void)whereKey:(NSString *)key containedIn:(NSArray *)array;

/*!
 Add a constraint to the query that requires a particular key's object not be contained in the provided array.
 @param key The key to be constrained.
 @param array The list of values the key's object should not be.
 */
- (void)whereKey:(NSString *)key notContainedIn:(NSArray *)array;

/*!
 Add a constraint to the query that requires a particular key's array contains every element of the provided array.
 @param key The key to be constrained.
 @param array The array of values to search for.
 */
- (void)whereKey:(NSString *)key containsAllObjectsInArray:(NSArray *)array;

/** @name Adding Location Constraints */

/*!
 Add a constraint to the query that requires a particular key's coordinates (specified via LCGeoPoint) be near
 a reference point.  Distance is calculated based on angular distance on a sphere.  Results will be sorted by distance
 from reference point.
 @param key The key to be constrained.
 @param geoPoint The reference point.  A LCGeoPoint.
 */
- (void)whereKey:(NSString *)key nearGeoPoint:(LCGeoPoint *)geoPoint;

/*!
 Add a constraint to the query that requires a particular key's coordinates (specified via LCGeoPoint) be near
 a reference point and within the maximum distance specified (in miles).  Distance is calculated based on
 a spherical coordinate system.  Results will be sorted by distance (nearest to farthest) from the reference point.
 @param key The key to be constrained.
 @param geoPoint The reference point.  A LCGeoPoint.
 @param maxDistance Maximum distance in miles.
 */
- (void)whereKey:(NSString *)key nearGeoPoint:(LCGeoPoint *)geoPoint withinMiles:(double)maxDistance;

/*!
 Add a constraint to the query that requires a particular key's coordinates (specified via LCGeoPoint) be near
 a reference point and within the maximum distance specified (in kilometers).  Distance is calculated based on
 a spherical coordinate system.  Results will be sorted by distance (nearest to farthest) from the reference point.
 @param key The key to be constrained.
 @param geoPoint The reference point.  A LCGeoPoint.
 @param maxDistance Maximum distance in kilometers.
 */
- (void)whereKey:(NSString *)key nearGeoPoint:(LCGeoPoint *)geoPoint withinKilometers:(double)maxDistance;

/*!
 Add a constraint to the query that requires a particular key's coordinates (specified via LCGeoPoint) be near
 a reference point and within the maximum distance specified (in radians).  Distance is calculated based on
 angular distance on a sphere.  Results will be sorted by distance (nearest to farthest) from the reference point.
 @param key The key to be constrained.
 @param geoPoint The reference point.  A LCGeoPoint.
 @param maxDistance Maximum distance in radians.
 */
- (void)whereKey:(NSString *)key nearGeoPoint:(LCGeoPoint *)geoPoint withinRadians:(double)maxDistance;

/*!
 * Add a constraint to the query that requires a particular key's coordinates (specified via LCGeoPoint) be near
 * a reference point and within the maximum and minimum distance. Distance is calculated based on
 * angular distance on a sphere. Results will be sorted by distance (nearest to farthest) from the reference point.
 *
 * @param key              The key to be constrained.
 * @param geoPoint         The reference point, a LCGeoPoint.
 * @param maxDistance      Maximum distance value. If negative (like -1), the maximum constraint will be ignored.
 * @param maxDistanceUnit  Maximum distance unit.
 * @param minDistance      Minimum distance value. If negative (like -1), the minimum constraint will be ignored.
 * @param minDistanceUnit  Minimum distance unit.
 */
- (void)whereKey:(NSString *)key
    nearGeoPoint:(LCGeoPoint *)geoPoint
     maxDistance:(double)maxDistance
 maxDistanceUnit:(LCQueryDistanceUnit)maxDistanceUnit
     minDistance:(double)minDistance
 minDistanceUnit:(LCQueryDistanceUnit)minDistanceUnit;

/*!
 * Add a constraint to the query that requires a particular key's coordinates (specified via LCGeoPoint) be near
 * a reference point and within the minimum distance. Distance is calculated based on
 * angular distance on a sphere. Results will be sorted by distance (nearest to farthest) from the reference point.
 *
 * @param key              The key to be constrained.
 * @param geoPoint         The reference point, a LCGeoPoint.
 * @param minDistance      Minimum distance value. If negative (like -1), the minimum constraint will be ignored.
 * @param minDistanceUnit  Minimum distance unit.
 */
- (void)whereKey:(NSString *)key
    nearGeoPoint:(LCGeoPoint *)geoPoint
     minDistance:(double)minDistance
 minDistanceUnit:(LCQueryDistanceUnit)minDistanceUnit;

/*!
 Add a constraint to the query that requires a particular key's coordinates (specified via LCGeoPoint) be
 contained within a given rectangular geographic bounding box.
 @param key The key to be constrained.
 @param southwest The lower-left inclusive corner of the box.
 @param northeast The upper-right inclusive corner of the box.
 */
- (void)whereKey:(NSString *)key withinGeoBoxFromSouthwest:(LCGeoPoint *)southwest toNortheast:(LCGeoPoint *)northeast;

/** @name Adding String Constraints */

/*!
 Add a regular expression constraint for finding string values that match the provided regular expression.
 This may be slow for large datasets.
 @param key The key that the string to match is stored in.
 @param regex The regular expression pattern to match.
 */
- (void)whereKey:(NSString *)key matchesRegex:(NSString *)regex;

/*!
 Add a regular expression constraint for finding string values that match the provided regular expression.
 This may be slow for large datasets.
 @param key The key that the string to match is stored in.
 @param regex The regular expression pattern to match.
 @param modifiers Any of the following supported PCRE modifiers:<br><code>i</code> - Case insensitive search<br><code>m</code> - Search across multiple lines of input
 */
- (void)whereKey:(NSString *)key matchesRegex:(NSString *)regex modifiers:(nullable NSString *)modifiers;

/*!
 Add a constraint for finding string values that contain a provided substring.
 This will be slow for large datasets.
 @param key The key that the string to match is stored in.
 @param substring The substring that the value must contain.
 */
- (void)whereKey:(NSString *)key containsString:(NSString *)substring;

/*!
 Add a constraint for finding string values that start with a provided prefix.
 This will use smart indexing, so it will be fast for large datasets.
 @param key The key that the string to match is stored in.
 @param prefix The substring that the value must start with.
 */
- (void)whereKey:(NSString *)key hasPrefix:(NSString *)prefix;

/*!
 Add a constraint for finding string values that end with a provided suffix.
 This will be slow for large datasets.
 @param key The key that the string to match is stored in.
 @param suffix The substring that the value must end with.
 */
- (void)whereKey:(NSString *)key hasSuffix:(NSString *)suffix;

/** @name Adding Subqueries */

/*!
 Returns a LCQuery that is the or of the passed in LCQuerys.
 @param queries The list of queries to or together.
 @return a LCQuery that is the or of the passed in LCQuerys.
 */
+ (nullable LCQuery *)orQueryWithSubqueries:(NSArray<LCQuery *> *)queries;

/*!
 Returns a LCQuery that is the AND of the passed in LCQuerys.
 @param queries The list of queries to AND together.
 @return a LCQuery that is the AND of the passed in LCQuerys.
 */
+ (nullable LCQuery *)andQueryWithSubqueries:(NSArray<LCQuery *> *)queries;

/*!
 Adds a constraint that requires that a key's value matches a value in another key
 in objects returned by a sub query.
 @param key The key that the value is stored
 @param otherKey The key in objects in the returned by the sub query whose value should match
 @param query The query to run.
 */
- (void)whereKey:(NSString *)key matchesKey:(NSString *)otherKey inQuery:(LCQuery *)query;

/*!
 Adds a constraint that requires that a key's value NOT match a value in another key
 in objects returned by a sub query.
 @param key The key that the value is stored
 @param otherKey The key in objects in the returned by the sub query whose value should match
 @param query The query to run.
 */
- (void)whereKey:(NSString *)key doesNotMatchKey:(NSString *)otherKey inQuery:(LCQuery *)query;

/*!
 Add a constraint that requires that a key's value matches a LCQuery constraint.
 This only works where the key's values are LCObjects or arrays of LCObjects.
 @param key The key that the value is stored in
 @param query The query the value should match
 */
- (void)whereKey:(NSString *)key matchesQuery:(LCQuery *)query;

/*!
 Add a constraint that requires that a key's value to not match a LCQuery constraint.
 This only works where the key's values are LCObjects or arrays of LCObjects.
 @param key The key that the value is stored in
 @param query The query the value should not match
 */
- (void)whereKey:(NSString *)key doesNotMatchQuery:(LCQuery *)query;


/*!
 Matches any array with the number of elements specified by count
 @param key The key that the value is stored in, value should be kind of array
 @param count the array size
 */
- (void)whereKey:(NSString *)key sizeEqualTo:(NSUInteger)count;

#pragma mark -
#pragma mark Sorting

/** @name Sorting */

/*!
 Sort the results in ascending order with the given key.
 @param key The key to order by.
 */
- (void)orderByAscending:(NSString *)key;

/*!
 Also sort in ascending order by the given key.  The previous keys provided will
 precedence over this key.
 @param key The key to order bye
 */
- (void)addAscendingOrder:(NSString *)key;

/*!
 Sort the results in descending order with the given key.
 @param key The key to order by.
 */
- (void)orderByDescending:(NSString *)key;
/*!
 Also sort in descending order by the given key.  The previous keys provided will
 precedence over this key.
 @param key The key to order bye
 */
- (void)addDescendingOrder:(NSString *)key;

/*!
 Sort the results in descending order with the given descriptor.
 @param sortDescriptor The NSSortDescriptor to order by.
 */
- (void)orderBySortDescriptor:(NSSortDescriptor *)sortDescriptor;

/*!
 Sort the results in descending order with the given descriptors.
 @param sortDescriptors An NSArray of NSSortDescriptor instances to order by.
 */
- (void)orderBySortDescriptors:(NSArray *)sortDescriptors;

#pragma mark -
#pragma mark Get methods

/** @name Getting Objects by ID */

/*!
 Returns a LCObject with a given class and id.
 @param objectClass The class name for the object that is being requested.
 @param objectId The id of the object that is being requested.
 @return The LCObject if found. Returns nil if the object isn't found, or if there was an error.
 */
+ (nullable LCObject *)getObjectOfClass:(NSString *)objectClass
                               objectId:(NSString *)objectId;

/*!
 Returns a LCObject with a given class and id and sets an error if necessary.
 @param objectClass The class name for the object that is being requested.
 @param objectId The id of the object that is being requested.
 @param error Pointer to an NSError that will be set if necessary.
 @return The LCObject if found. Returns nil if the object isn't found, or if there was an error.
 */
+ (nullable LCObject *)getObjectOfClass:(NSString *)objectClass
                               objectId:(NSString *)objectId
                                  error:(NSError **)error;

/*!
 Returns a LCObject with the given id.
 
 This mutates the LCQuery.
 
 @param objectId The id of the object that is being requested.
 @return The LCObject if found. Returns nil if the object isn't found, or if there was an error.
 */
- (nullable LCObject *)getObjectWithId:(NSString *)objectId;

/*!
 Returns a LCObject with the given id and sets an error if necessary.
 
 This mutates the LCQuery
 
 @param objectId The id of the object that is being requested.
 @param error Pointer to an NSError that will be set if necessary.
 @return The LCObject if found. Returns nil if the object isn't found, or if there was an error.
 */
- (nullable LCObject *)getObjectWithId:(NSString *)objectId error:(NSError **)error;

/*!
 Gets a LCObject asynchronously and calls the given block with the result. 
 
 This mutates the LCQuery
 @param objectId The id of the object being requested.
 @param block The block to execute. The block should have the following argument signature: (NSArray *object, NSError *error)
 */
- (void)getObjectInBackgroundWithId:(NSString *)objectId
                              block:(LCObjectResultBlock)block;

#pragma mark -
#pragma mark Getting Users

/*! @name Getting User Objects */

/*!
 Returns a LCUser with a given id.
 @param objectId The id of the object that is being requested.
 @return The LCUser if found. Returns nil if the object isn't found, or if there was an error.
 */
+ (nullable LCUser *)getUserObjectWithId:(NSString *)objectId;

/*!
 Returns a LCUser with a given class and id and sets an error if necessary.
 
 @param objectId The id of the object that is being requested.
 @param error Pointer to an NSError that will be set if necessary.
 @return The LCUser if found. Returns nil if the object isn't found, or if there was an error.
 */
+ (nullable LCUser *)getUserObjectWithId:(NSString *)objectId
                                   error:(NSError **)error;

#pragma mark -
#pragma mark Find methods

/** @name Getting all Matches for a Query */

/*!
 Finds objects based on the constructed query.
 @return an array of LCObjects that were found.
 */
- (nullable NSArray *)findObjects;

/*!
 Finds objects based on the constructed query and sets an error if there was one.
 @param error Pointer to an NSError that will be set if necessary.
 @return an array of LCObjects that were found.
 */
- (nullable NSArray *)findObjects:(NSError **)error;

/*!
 An alias of `-[LCQuery findObjects:]` methods that supports Swift exception.
 @seealso `-[LCQuery findObjects:]`
 */
- (nullable NSArray *)findObjectsAndThrowsWithError:(NSError **)error;

/*!
 Finds objects asynchronously and calls the given block with the results.
 @param block The block to execute. The block should have the following argument signature:(NSArray *objects, NSError *error) 
 */
- (void)findObjectsInBackgroundWithBlock:(LCArrayResultBlock)block;

/*!
 Remove objects asynchronously and calls the given block with the results.
 @param block The block to execute. The block should have the following argument signature:(NSArray *objects, NSError *error)
 */
- (void)deleteAllInBackgroundWithBlock:(LCBooleanResultBlock)block;


/** @name Getting the First Match in a Query */

/*!
 Gets an object based on the constructed query.
 
 This mutates the LCQuery.
 
 @return a LCObject, or nil if none was found.
 */
- (nullable LCObject *)getFirstObject;

/*!
 Gets an object based on the constructed query and sets an error if any occurred.

 This mutates the LCQuery.
 
 @param error Pointer to an NSError that will be set if necessary.
 @return a LCObject, or nil if none was found.
 */
- (nullable LCObject *)getFirstObject:(NSError **)error;

/*!
 An alias of `-[LCQuery getFirstObject:]` methods that supports Swift exception.
 @seealso `-[LCQuery getFirstObject:]`
 */
- (nullable LCObject *)getFirstObjectAndThrowsWithError:(NSError **)error;

/*!
 Gets an object asynchronously and calls the given block with the result.
 
 This mutates the LCQuery.
 
 @param block The block to execute. The block should have the following argument signature:(LCObject *object, NSError *error) result will be nil if error is set OR no object was found matching the query. error will be nil if result is set OR if the query succeeded, but found no results.
 */
- (void)getFirstObjectInBackgroundWithBlock:(LCObjectResultBlock)block;

#pragma mark -
#pragma mark Count methods

/** @name Counting the Matches in a Query */

/*!
  Counts objects based on the constructed query.
 @return the number of LCObjects that match the query, or -1 if there is an error.
 */
- (NSInteger)countObjects;

/*!
  Counts objects based on the constructed query and sets an error if there was one.
 @param error Pointer to an NSError that will be set if necessary.
 @return the number of LCObjects that match the query, or -1 if there is an error.
 */
- (NSInteger)countObjects:(NSError **)error;

/*!
 An alias of `-[LCQuery countObjects:]` methods that supports Swift exception.
 @seealso `-[LCQuery countObjects:]`
 */
- (NSInteger)countObjectsAndThrowsWithError:(NSError **)error;

/*!
 Counts objects asynchronously and calls the given block with the counts.
 @param block The block to execute. The block should have the following argument signature:
 (int count, NSError *error) 
 */
- (void)countObjectsInBackgroundWithBlock:(LCIntegerResultBlock)block;

#pragma mark -
#pragma mark Cancel methods

/** @name Cancelling a Query */

/*!
 Cancels the current network request (if any). Ensures that callbacks won't be called.
 */
- (void)cancel;

#pragma mark -
#pragma mark Pagination properties


/** @name Paginating Results */
/*!
 A limit on the number of objects to return.  Note: If you are calling findObject with limit=1, you may find it easier to use getFirst instead.
 */
@property (nonatomic, assign) NSInteger limit;

/*!
 The number of objects to skip before returning any.
 */
@property (nonatomic, assign) NSInteger skip;

/**
 Include ACL for object.
 */
@property (nonatomic, assign) BOOL includeACL;

#pragma mark -
#pragma mark Cache methods

/** @name Controlling Caching Behavior */

/*!
 The cache policy to use for requests.
 */
@property (readwrite, assign) LCCachePolicy cachePolicy;

/* !
 The age(seconds) after which a cached value will be ignored.
 */
@property (readwrite, assign) NSTimeInterval maxCacheAge;

/*!
 Returns whether there is a cached result for this query.
 @return YES if there is a cached result for this query, and NO otherwise.
 */
- (BOOL)hasCachedResult;

/*!
 Clears the cached result for this query.  If there is no cached result, this is a noop.
 */
- (void)clearCachedResult;

/*!
 Clears the cached results for all queries.
 */
+ (void)clearAllCachedResults; 

#pragma mark - Advanced Settings

/** @name Advanced Settings */

/*!
 Whether or not performance tracing should be done on the query.
 This should not be set in most cases.
 */
@property (nonatomic, assign) BOOL trace;


@end

NS_ASSUME_NONNULL_END
