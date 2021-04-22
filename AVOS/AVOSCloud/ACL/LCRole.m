
#import <Foundation/Foundation.h>
#import "LCObject.h"
#import "LCObject_Internal.h"
#import "LCRole.h"
#import "LCRole_Internal.h"
#import "AVQuery.h"
#import "LCRelation.h"
#import "LCRelation_Internal.h"
#import "LCACL.h"
#import "AVPaasClient.h"
#import "AVGlobal.h"
#import "AVUtils.h"

@implementation LCRole

@synthesize name = _name;
@synthesize acl = _acl;
@synthesize relationData = _relationData;

+(NSString *)className
{
    return @"_Role";
}

+(NSString *)endPoint
{
    return @"roles";
}

- (instancetype)initWithName:(NSString *)name
{
    self = [super initWithClassName:[LCRole className]];
    if (self)
    {
        self.name = name;
        _relationData = [[NSMutableDictionary alloc] init];
    }
    return self;
}

+(instancetype)role {
    LCRole * r = [[LCRole alloc] initWithName:@""];
    return r;
}

- (instancetype)initWithName:(NSString *)name acl:(LCACL *)acl
{
    self = [self initWithName:name];
    if (self)
    {
        self.acl = acl;
    }
    return self;
}

+ (instancetype)roleWithName:(NSString *)name
{
    LCRole * role = [[LCRole alloc] initWithName:name];
    return role;
}

+ (instancetype)roleWithName:(NSString *)name acl:(LCACL *)acl
{
    LCRole * role = [[LCRole alloc] initWithName:name acl:acl];
    return role;
}

- (LCRelation *)users
{
    return [self relationForKey:@"users"];
}

- (LCRelation *)roles
{
    return [self relationForKey:@"roles"];
}

+ (AVQuery *)query
{
    AVQuery *query = [[AVQuery alloc] initWithClassName:[LCRole className]];
    return query;
}

-(NSMutableDictionary *)initialBodyData {
    return [self._requestManager initialSetAndAddRelationDict];
}

-(void)setName:(NSString *)name {
    _name = name;
    [self addSetRequest:@"name" object:name];
}

-(void)setAcl:(LCACL *)acl {
    _acl = acl;
    [self addSetRequest:ACLTag object:acl];
}

@end
