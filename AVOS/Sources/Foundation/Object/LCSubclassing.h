//
//  LCSubclassing.h
//  paas
//
//  Created by Summer on 13-4-2.
//  Copyright (c) 2013年 LeanCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LCQuery;

NS_ASSUME_NONNULL_BEGIN

/*!
 If a subclass of LCObject conforms to LCSubclassing and calls registerSubclass, LeanCloud will be able to use that class as the native class for a LeanCloud object.

 Classes conforming to this protocol should subclass LCObject and include LCObject+Subclass.h in their implementation file. This ensures the methods in the Subclass category of LCObject are exposed in its subclasses only.
 */
@protocol LCSubclassing

@optional

/*! The name of the class as seen in the REST API. */
+ (NSString *)parseClassName;

/*!
 Creates a reference to an existing LCObject for use in creating associations between LCObjects.  Calling isDataAvailable on this
 object will return NO until fetchIfNeeded or refresh has been called.  No network request will be made.
 A default implementation is provided by LCObject which should always be sufficient.
 @param objectId The object id for the referenced object.
 @return A LCObject without data.
 */
+ (instancetype)objectWithoutDataWithObjectId:(NSString *)objectId;

/*!
 Create a query which returns objects of this type.
 A default implementation is provided by LCObject which should always be sufficient.
 */
+ (LCQuery *)query;

/*!
 Lets LeanCloud know this class should be used to instantiate all objects with class type parseClassName.
 This method must be called before [LCApplication setApplicationId:clientKey:]
 */
+ (void)registerSubclass;

@end

NS_ASSUME_NONNULL_END
