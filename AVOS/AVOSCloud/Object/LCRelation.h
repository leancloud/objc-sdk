//
//  LCRelation.h
//  LeanCloud
//
//

#import <Foundation/Foundation.h>
#import "LCObject.h"
#import "LCQuery.h"

NS_ASSUME_NONNULL_BEGIN

/*!
 A class that is used to access all of the children of a many-to-many relationship.  Each instance
 of LCRelation is associated with a particular parent object and key.
 */
@interface LCRelation : NSObject {
    
}

@property (nonatomic, copy, nullable) NSString *targetClass;


#pragma mark Accessing objects
/*!
 @return A LCQuery that can be used to get objects in this relation.
 */
- (LCQuery *)query;


#pragma mark Modifying relations

/*!
 Adds a relation to the passed in object.
 @param object LCObject to add relation to.
 */
- (void)addObject:(LCObject *)object;

/*!
 Removes a relation to the passed in object.
 @param object LCObject to add relation to.
 */
- (void)removeObject:(LCObject *)object;

/*!
 @return A LCQuery that can be used to get parent objects in this relation.
 */

/**
 *  A LCQuery that can be used to get parent objects in this relation.
 *
 *  @param parentClassName parent Class Name
 *  @param relationKey     relation Key
 *  @param child           child object
 *
 *  @return the Query
 */
+(LCQuery *)reverseQuery:(NSString *)parentClassName
             relationKey:(NSString *)relationKey
             childObject:(LCObject *)child;

@end

NS_ASSUME_NONNULL_END
