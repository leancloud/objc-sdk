//
//  LCACL.m
//  AVOSCloud
//
//  Created by Zhu Zeng on 3/13/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "LCACL.h"
#import "LCACL_Internal.h"
#import "AVUser.h"
#import "LCRole.h"
#import "LCPaasClient.h"

static NSString * readTag = @"read";
static NSString * writeTag = @"write";

@implementation LCACL

@synthesize permissionsById = _permissionsById;

-(id)copyWithZone:(NSZone *)zone
{
    LCACL *newObject = [[[self class] allocWithZone:zone] init];
    if(newObject) {
        newObject.permissionsById = [self.permissionsById mutableCopy];
    }
    return newObject;
}

+ (LCACL *)ACL
{
    LCACL * result = [[LCACL alloc] init];
    return result;
}

+ (LCACL *)ACLWithUser:(AVUser *)user
{
    LCACL * result = [[LCACL alloc] init];
    [result setReadAccess:YES forUser:user];
    [result setWriteAccess:YES forUser:user];
    return result;
}

-(instancetype)init
{
    self = [super init];
    if (self) {
        _permissionsById = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(NSDictionary *)dictionary:(BOOL)read
                      write:(BOOL)write
{
    NSDictionary * dictionary = @{readTag: [NSNumber numberWithBool:read], writeTag: [NSNumber numberWithBool:write]};
    return dictionary;
}

-(NSString *)publicTag
{
    return @"*";
}

- (NSMutableDictionary *)dictionaryForKey:(NSString *)key
                                   create:(BOOL)create
{
    NSMutableDictionary *dictionary = nil;
    id object = self.permissionsById[key];

    if (object) {
        if ([object isKindOfClass:[NSMutableDictionary class]]) {
            dictionary = (NSMutableDictionary *)object;
        } else {
            dictionary = [object mutableCopy];
            self.permissionsById[key] = dictionary;
        }
    } else if (create) {
        dictionary = [NSMutableDictionary dictionary];
        self.permissionsById[key] = dictionary;
    }

    return dictionary;
}

-(void)allowRead:(BOOL)allowed
             key:(NSString *)key
{
    NSMutableDictionary * data = [self dictionaryForKey:key create:allowed];
    if (allowed)
    {
        [data setObject:[NSNumber numberWithBool:allowed] forKey:readTag];
    }
    else
    {
        [data removeObjectForKey:readTag];
    }
}

-(BOOL)isReadAllowed:(NSString *)key
{
    NSMutableDictionary * data = [self dictionaryForKey:key create:NO];
    return [[data objectForKey:readTag] boolValue];
}

-(void)allowWrite:(BOOL)allowed
              key:(NSString *)key
{
    NSMutableDictionary * data = [self dictionaryForKey:key create:allowed];
    if (allowed)
    {
        [data setObject:[NSNumber numberWithBool:allowed] forKey:writeTag];
    }
    else
    {
        [data removeObjectForKey:writeTag];
    }
}

-(BOOL)isWriteAllowed:(NSString *)key
{
    NSMutableDictionary * data = [self dictionaryForKey:key create:NO];
    return [[data objectForKey:writeTag] boolValue];
}

- (void)setPublicReadAccess:(BOOL)allowed
{
    [self allowRead:allowed key:[self publicTag]];
}

- (BOOL)getPublicReadAccess
{
    return [self isReadAllowed:[self publicTag]];
}

- (void)setPublicWriteAccess:(BOOL)allowed
{
    [self allowWrite:allowed key:[self publicTag]];
}

- (BOOL)getPublicWriteAccess
{
    return [self isWriteAllowed:[self publicTag]];
}

- (void)setReadAccess:(BOOL)allowed forUserId:(NSString *)userId
{
    [self allowRead:allowed key:userId];
}

- (BOOL)getReadAccessForUserId:(NSString *)userId
{
    return [self isReadAllowed:userId];
}

- (void)setWriteAccess:(BOOL)allowed forUserId:(NSString *)userId
{
    [self allowWrite:allowed key:userId];
}

- (BOOL)getWriteAccessForUserId:(NSString *)userId
{
    return [self isWriteAllowed:userId];
}

- (void)setReadAccess:(BOOL)allowed forUser:(AVUser *)user
{
    [self allowRead:allowed key:user.objectId];
}

- (BOOL)getReadAccessForUser:(AVUser *)user
{
    return [self getReadAccessForUserId:user.objectId];
}

- (void)setWriteAccess:(BOOL)allowed forUser:(AVUser *)user
{
    [self setWriteAccess:allowed forUserId:user.objectId];
}

- (BOOL)getWriteAccessForUser:(AVUser *)user
{
    return [self getWriteAccessForUserId:user.objectId];
}

-(NSString *)roleName:(NSString *)name
{
    return [NSString stringWithFormat:@"role:%@", name];
}

- (BOOL)getReadAccessForRoleWithName:(NSString *)name
{
    return [self isReadAllowed:[self roleName:name]];
}

- (void)setReadAccess:(BOOL)allowed forRoleWithName:(NSString *)name
{
    [self allowRead:allowed key:[self roleName:name]];
}

- (BOOL)getWriteAccessForRoleWithName:(NSString *)name
{
    return [self isWriteAllowed:[self roleName:name]];
}

- (void)setWriteAccess:(BOOL)allowed forRoleWithName:(NSString *)name
{
    return [self allowWrite:allowed key:[self roleName:name]];
}

- (BOOL)getReadAccessForRole:(LCRole *)role
{
    return [self isReadAllowed:[self roleName:role.name]];
}

- (void)setReadAccess:(BOOL)allowed forRole:(LCRole *)role
{
    [self allowRead:allowed key:[self roleName:role.name]];
}

- (BOOL)getWriteAccessForRole:(LCRole *)role
{
    return [self isWriteAllowed:[self roleName:role.name]];
}

- (void)setWriteAccess:(BOOL)allowed forRole:(LCRole *)role
{
    [self allowWrite:allowed key:[self roleName:role.name]];
}

+ (void)setDefaultACL:(LCACL *)acl withAccessForCurrentUser:(BOOL)currentUserAccess
{
    [LCPaasClient sharedInstance].defaultACL = acl;
    [LCPaasClient sharedInstance].currentUserAccessForDefaultACL = currentUserAccess;
}


@end
