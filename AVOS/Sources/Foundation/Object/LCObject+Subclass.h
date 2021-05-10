//
//  LCObject+Subclass.h
//  paas
//
//  Created by Summer on 13-4-2.
//  Copyright (c) 2013年 LeanCloud. All rights reserved.
//

#import "LCObject.h"

@class LCQuery;

NS_ASSUME_NONNULL_BEGIN

/*!
 <h3>Subclassing Notes</h3>
 
 Developers can subclass LCObject for a more native object-oriented class structure. Strongly-typed subclasses of LCObject must conform to the LCSubclassing protocol and must call registerSubclass to be returned by LCQuery and other LCObject factories. All methods in LCSubclassing except for [LCSubclassing parseClassName] are already implemented in the LCObject(Subclass) category. Inculding LCObject+Subclass.h in your implementation file provides these implementations automatically.
 
 Subclasses support simpler initializers, query syntax, and dynamic synthesizers.
 
 */

@interface LCObject(Subclass)

///*! @name Methods for Subclasses */
//
///*!
// Designated initializer for subclasses.
// This method can only be called on subclasses which conform to LCSubclassing.
// This method should not be overridden.
// */
//- (id)init;

/*!
 Creates an instance of the registered subclass with this class's parseClassName.
 This helps a subclass ensure that it can be subclassed itself. For example, [LCUser object] will
 return a MyUser object if MyUser is a registered subclass of LCUser. For this reason, [MyClass object] is
 preferred to [[MyClass alloc] init].
 This method can only be called on subclasses which conform to LCSubclassing.
 A default implementation is provided by LCObject which should always be sufficient.
 */
+ (instancetype)object;

/*!
 Registers an Objective-C class for LeanCloud to use for representing a given LeanCloud class.
 Once this is called on a LCObject subclass, any LCObject LeanCloud creates with a class
 name matching [self parseClassName] will be an instance of subclass.
 This method can only be called on subclasses which conform to LCSubclassing.
 A default implementation is provided by LCObject which should always be sufficient.
 */
+ (void)registerSubclass;

/*!
 Returns a query for objects of type +parseClassName.
 This method can only be called on subclasses which conform to LCSubclassing.
 A default implementation is provided by LCObject which should always be sufficient.
 */
+ (LCQuery *)query;

@end

NS_ASSUME_NONNULL_END
