//
//  LCRole.h
//  LeanCloud
//

#import <Foundation/Foundation.h>
#import "LCObject.h"

@class LCQuery;

NS_ASSUME_NONNULL_BEGIN

/*!
 Represents a Role on the LeanCloud server. LCRoles represent groupings
 of LCUsers for the purposes of granting permissions (e.g. specifying a
 LCACL for a LCObject). Roles are specified by their sets of child users
 and child roles, all of which are granted any permissions that the
 parent role has.<br />
 <br />
 Roles must have a name (which cannot be changed after creation of the role),
 and must specify an ACL.
 */
@interface LCRole : LCObject

#pragma mark Creating a New Role

/** @name Creating a New Role */

/*!
 Constructs a new LCRole with the given name. If no default ACL has been
 specified, you must provide an ACL for the role.
 
 @param name The name of the Role to create.
 */
- (instancetype)initWithName:(NSString *)name;

/*!
 Constructs a new LCRole with the given name.
 
 @param name The name of the Role to create.
 @param acl The ACL for this role. Roles must have an ACL.
 */
- (instancetype)initWithName:(NSString *)name acl:(nullable LCACL *)acl;

/*!
 Constructs a new LCRole with the given name. If no default ACL has been
 specified, you must provide an ACL for the role.
 
 @param name The name of the Role to create.
 */
+ (instancetype)roleWithName:(NSString *)name;

/*!
 Constructs a new LCRole with the given name.
 
 @param name The name of the Role to create.
 @param acl The ACL for this role. Roles must have an ACL.
 */
+ (instancetype)roleWithName:(NSString *)name acl:(nullable LCACL *)acl;

#pragma mark -
#pragma mark Role-specific Properties

/** @name Role-specific Properties */

/*!
 Gets or sets the name for a role. This value must be set before the role
 has been saved to the server, and cannot be set once the role has been
 saved.<br />
 <br />
 A role's name can only contain alphanumeric characters, _, -, and spaces.
 */
@property (nonatomic, copy) NSString *name;

/*!
 Gets the LCRelation for the LCUsers that are direct children of this role.
 These users are granted any privileges that this role has been granted
 (e.g. read or write access through ACLs). You can add or remove users from
 the role through this relation.
 
 @return the relation for the users belonging to this role.
 */
- (LCRelation *)users;

/*!
 Gets the LCRelation for the LCRoles that are direct children of this role.
 These roles' users are granted any privileges that this role has been granted
 (e.g. read or write access through ACLs). You can add or remove child roles
 from this role through this relation.
 
 @return the relation for the roles belonging to this role.
 */
- (LCRelation *)roles;

#pragma mark -
#pragma mark Querying for Roles

/** @name Querying for Roles */
+ (LCQuery *)query;

@end

NS_ASSUME_NONNULL_END
