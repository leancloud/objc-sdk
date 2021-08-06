//
//  LCIMConversationQuery.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 2/3/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMCommon.h"

#define LCIMAttr(attr) ([NSString stringWithFormat:@"attr.%@", attr])

NS_ASSUME_NONNULL_BEGIN

@interface LCIMConversationQuery : NSObject

/*!
 The max count of the query result, default is 10. 
 */
@property (nonatomic, assign) NSInteger limit;

/*!
 The offset of the query, default is 0.
 */
@property (nonatomic, assign) NSInteger skip;

/*!
 Configures cache policy, default is kLCCachePolicyCacheElseNetwork
 */
@property (nonatomic, assign) LCIMCachePolicy cachePolicy;

/*!
 Configures cache time, default is one hour (1 * 60 * 60)
 */
@property (nonatomic, assign) NSTimeInterval cacheMaxAge;

/*!
 * Query conditions.
 */
@property (nonatomic, assign) LCIMConversationQueryOption option;

/*!
 * Build an query that is the OR of the passed in queries.
 * @param queries The list of queries to OR together.
 * @return an query that is the OR of the passed in queries.
 */
+ (nullable instancetype)orQueryWithSubqueries:(NSArray<LCIMConversationQuery *> *)queries;

/*!
 * Build an query that is the AND of the passed in queries.
 * @param queries The list of queries to AND together.
 * @return an query that is the AND of the passed in queries.
 */
+ (nullable instancetype)andQueryWithSubqueries:(NSArray<LCIMConversationQuery *> *)queries;

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
 The value corresponding to key is equal to object,
 or the array corresponding to key contains object.
 */
- (void)whereKey:(NSString *)key equalTo:(id)object;

/*!
 The value corresponding to key is less than object.
 */
- (void)whereKey:(NSString *)key lessThan:(id)object;

/*!
 The value corresponding to key is less than or equal to object.
 */
- (void)whereKey:(NSString *)key lessThanOrEqualTo:(id)object;

/*!
 The value corresponding to key is greater than object.
 */
- (void)whereKey:(NSString *)key greaterThan:(id)object;

/*!
 The value corresponding to key is greater than or equal to object.
 */
- (void)whereKey:(NSString *)key greaterThanOrEqualTo:(id)object;

/*!
 The value corresponding to key is not equal to object,
 or the array corresponding to key does not contain object.
 */
- (void)whereKey:(NSString *)key notEqualTo:(id)object;

/*!
 array contains value corresponding to key,
 or array contains at least one element in the array value corresponding to key.
 */
- (void)whereKey:(NSString *)key containedIn:(NSArray *)array;

/*!
 array does not contain value corresponding to key,
 or the field corresponding to key does not exist.
 */
- (void)whereKey:(NSString *)key notContainedIn:(NSArray *)array;

/*!
 The array corresponding to key contains all elements in array.
 */
- (void)whereKey:(NSString *)key containsAllObjectsInArray:(NSArray *)array;

/*!
 Near a geopoint. Returned results will be sorted in distances to the geopoint.
 */
- (void)whereKey:(NSString *)key nearGeoPoint:(LCGeoPoint *)geopoint;

/*!
 Near a geopoint. Returned results will be sorted in distances to the geopoint.
 @param maxDistance in miles
 */
- (void)whereKey:(NSString *)key nearGeoPoint:(LCGeoPoint *)geopoint withinMiles:(double)maxDistance;

/*!
 Near a geopoint. Returned results will be sorted in distances to the geopoint.
 @param maxDistance in kilometers
 */
- (void)whereKey:(NSString *)key nearGeoPoint:(LCGeoPoint *)geopoint withinKilometers:(double)maxDistance;

/*!
 Near a geopoint. Returned results will be sorted in distances to the geopoint.
 @param maxDistance in radians
 */
- (void)whereKey:(NSString *)key nearGeoPoint:(LCGeoPoint *)geopoint withinRadians:(double)maxDistance;

/*!
 Within a rectangle.
 @param southwest the lower left corner of the rectangle
 @param northeast the upper right corner of the rectangle
 */
- (void)whereKey:(NSString *)key withinGeoBoxFromSouthwest:(LCGeoPoint *)southwest toNortheast:(LCGeoPoint *)northeast;

/*!
 Matches a regex. This query may have a significant performance impact.
 */
- (void)whereKey:(NSString *)key matchesRegex:(NSString *)regex;

/*!
 Matches a regex. This query may have a significant performance impact.
 @param modifiers PCRE regex modifiers such as i and m.
 */
- (void)whereKey:(NSString *)key matchesRegex:(NSString *)regex modifiers:(nullable NSString *)modifiers;

/*!
 The string corresponding to key has a substring.
 */
- (void)whereKey:(NSString *)key containsString:(NSString *)substring;

/*!
 The string corresponding to key has a prefix.
 */
- (void)whereKey:(NSString *)key hasPrefix:(NSString *)prefix;

/*!
 The string corresponding to key has a suffix.
 */
- (void)whereKey:(NSString *)key hasSuffix:(NSString *)suffix;

/*!
 The size of the array corresponding to key is equal to count.
 */
- (void)whereKey:(NSString *)key sizeEqualTo:(NSUInteger)count;


/*!
 The ascending order by the value corresponding to key, support for multi-field sorting with comma.
 */
- (void)orderByAscending:(NSString *)key;

/*!
 Adding a ascending order by the value corresponding to key to the order.
 */
- (void)addAscendingOrder:(NSString *)key;

/*!
 The descending order by the value corresponding to key, support for multi-field sorting with comma.
 */
- (void)orderByDescending:(NSString *)key;

/*!
 Adding a descending order by the value corresponding to key to the order.
 @param key 降序的 key
 */
- (void)addDescendingOrder:(NSString *)key;

/*!
 Sort with sortDescriptor.
 @param sortDescriptor NSSortDescriptor object
 */
- (void)orderBySortDescriptor:(NSSortDescriptor *)sortDescriptor;

/*!
 Sort with sortDescriptors.
 @param sortDescriptors NSSortDescriptor object array
 */
- (void)orderBySortDescriptors:(NSArray *)sortDescriptors;

/*!
 Queries for an LCIMConversation object based on its conversationId.
 @param callback on returned results
 */
- (void)getConversationById:(NSString *)conversationId
                   callback:(void (^)(LCIMConversation * _Nullable conversation, NSError * _Nullable error))callback;

/*!
 Queries for an array of LCIMConversation objects.
 If limit is unspecified or invalid, it will return 10 results by default.
 @param callback on returned results
 */
- (void)findConversationsWithCallback:(void (^)(NSArray<LCIMConversation *> * _Nullable conversations, NSError * _Nullable error))callback;


/**
 Find temporary conversations from server.

 @param tempConvIds ID array of temporary conversations.
 @param callback Result callback.
 */
- (void)findTemporaryConversationsWith:(NSArray<NSString *> *)tempConvIds
                              callback:(void (^)(NSArray<LCIMTemporaryConversation *> * _Nullable conversations, NSError * _Nullable error))callback;

@end

NS_ASSUME_NONNULL_END
