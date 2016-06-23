//
//  AVRequestManager.m
//  paas
//
//  Created by Zhu Zeng on 9/10/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "AVRequestManager.h"
#import "AVObject.h"
#import "AVObjectUtils.h"
#import "AVObject_Internal.h"
#import "AVACL_Internal.h"

@implementation AVRequestManager

+(NSDictionary *)unsetOp:(NSString *)key {
    NSDictionary * op = @{key: @{@"__op": @"Delete"}};
    return op;
}

+(NSDictionary *)addObjectOp:(NSString *)key
                     objects:(NSArray *)objects {
    NSMutableArray * array = [NSMutableArray array];
    for(AVObject * obj in objects) {
        NSDictionary * dict = [AVObjectUtils dictionaryFromObject:obj];
        [array addObject:dict];
    }
    NSDictionary * op = @{key: @{@"__op": @"Add", @"objects": array}};
    return op;
}

+(NSDictionary *)addUniqueObjectOp:(NSString *)key
                           objects:(NSArray *)objects {
    NSMutableArray * array = [NSMutableArray array];
    for(AVObject * obj in objects) {
        NSDictionary * dict = [AVObjectUtils dictionaryFromObject:obj];
        [array addObject:dict];
    }
    NSDictionary * op = @{key: @{@"__op": @"AddUnique", @"objects": array}};
    return op;
}

+(NSDictionary *)addRelationObjectOp:(NSString *)key
                             objects:(NSArray *)objects {
    NSMutableArray * array = [NSMutableArray array];
    for(AVObject * obj in objects) {
        NSDictionary * dict = [AVObjectUtils dictionaryFromObject:obj];
        [array addObject:dict];
    }
    NSDictionary * op = @{key: @{@"__op": @"AddRelation", @"objects": array}};
    return op;
}


+(NSDictionary *)removeObjectOp:(NSString *)key
                        objects:(NSArray *)objects {
    NSMutableArray * array = [NSMutableArray array];
    for(AVObject * obj in objects) {
        NSDictionary * dict = [AVObjectUtils dictionaryFromObject:obj];
        [array addObject:dict];
    }
    NSDictionary * op = @{key: @{@"__op": @"Remove", @"objects": array}};
    return op;
}

+(NSDictionary *)removeRelationObjectOp:(NSString *)key
                                objects:(NSArray *)objects {
    NSMutableArray * array = [NSMutableArray array];
    for(AVObject * obj in objects) {
        NSDictionary * dict = [AVObjectUtils dictionaryFromObject:obj];
        [array addObject:dict];
    }
    NSDictionary * op = @{key: @{@"__op": @"RemoveRelation", @"objects": array}};
    return op;
}

+(NSDictionary *)incOp:(NSString *)key
                 value:(double)value {
    NSDictionary * op = @{key: @{@"__op": @"Increment", @"amount": @(value)}};
    return op;
}

-(id)init {
    self = [super init];
    _dictArray = [NSMutableArray array];
    for(int i = SET; i <= REMOVE_RELATION; ++i) {
        NSMutableDictionary * dict = [NSMutableDictionary dictionary];
        [_dictArray addObject:dict];
    }
    return self;
}

-(NSMutableArray *)array:(NSMutableDictionary *)dict
                 withKey:(NSString *)key
                  create:(BOOL)create {
    NSMutableArray * list = [dict objectForKey:key];
    if (!create) {
        return list;
    }
    if (list == nil) {
        list = [[NSMutableArray alloc] init];
        [dict setObject:list forKey:key];
    }
    return list;
}

-(NSMutableDictionary *)requestDict:(RequestDict)type {
    return [self.dictArray objectAtIndex:type];
}

-(NSMutableDictionary *)setDict {
    return [self requestDict:SET];
}

-(NSMutableDictionary *)unsetDict {
    return [self requestDict:UNSET];
}

-(NSMutableDictionary *)incDict {
    return [self requestDict:INC];
}

-(NSMutableDictionary *)addDict {
    return [self requestDict:ADD];
}

-(NSMutableDictionary *)addUniqueDict {
    return [self requestDict:ADD_UNIQUE];
}

-(NSMutableDictionary *)addRelationDict {
    return [self requestDict:ADD_RELATION];
}

-(NSMutableDictionary *)removeDict {
    return [self requestDict:REMOVE];
}

-(NSMutableDictionary *)removeRelationDict {
    return [self requestDict:REMOVE_RELATION];
}

-(void)removeAll:(NSString *)key
          except:(NSMutableDictionary *)dict {
    for(int i = 0; i < self.dictArray.count; ++i) {
        if ([self.dictArray objectAtIndex:i] != dict) {
            [[self.dictArray objectAtIndex:i] removeObjectForKey:key];
        }
    }
}

-(void)setRequest:(NSString *)key
           object:(id)object {
    [self removeAll:key except:nil];
    if (object) {
        [[self setDict] setObject:object forKey:key];
    }else{
        [[self setDict] removeObjectForKey:key];
    }
    
}

-(void)unsetKeyRequest:(NSString *)key {
    [self removeAll:key except:nil];
    [[self unsetDict] setObject:@"" forKey:key];
}

-(void)addObjectRequest:(NSString *)key
                 object:(id)object {
    NSMutableArray * list = nil;
    list = [self array:[self addDict] withKey:key create:YES];
    [list addObject:object];
}

-(void)addUniqueObjectRequest:(NSString *)key
                 object:(id)object {
    NSMutableArray * list = nil;
    list = [self array:[self addUniqueDict] withKey:key create:YES];
    [list addObject:object];
}

-(void)addRelationRequest:(NSString *)key
                   object:(id)object {
    NSMutableArray * rm = [self array:[self removeRelationDict] withKey:key create:NO];
    [rm removeObject:object];
    NSMutableArray * array = [self array:[self addRelationDict] withKey:key create:YES];
    [array addObject:object];
}

-(void)removeObjectRequest:(NSString *)key
                    object:(id)object {
    NSMutableArray * rm = [self array:[self addDict] withKey:key create:NO];
    [rm removeObject:object];
    NSMutableArray * array = [self array:[self removeDict] withKey:key create:YES];
    [array addObject:object];
}

-(void)removeRelationRequest:(NSString *)key
                      object:(id)object {
    NSMutableArray * rm = [self array:[self addRelationDict] withKey:key create:NO];
    [rm removeObject:object];
    NSMutableArray * array = [self array:[self removeRelationDict] withKey:key create:YES];
    [array addObject:object];
}

-(void)incRequest:(NSString *)key
            value:(double)value {
    [self removeAll:key except:[self incDict]];
    double current = [[[self incDict] objectForKey:key] doubleValue];
    current += value;
    [[self incDict] setObject:@(current) forKey:key];
}

-(NSDictionary *)jsonForSet:(BOOL)ignoreAVObject {
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
    for(NSString * key in [self setDict]) {
        id object = [self.setDict objectForKey:key];
        
        // object without object id will be stored in
         // batch request, so just ignore them here.
        if (ignoreAVObject &&
            [object isKindOfClass:[AVObject class]] &&
            ![object hasValidObjectId]) {
            continue;
        }
        NSDictionary * jsonDict = [AVObjectUtils dictionaryFromObject:object];
        [dict setObject:jsonDict forKey:key];
    }
    return dict;
}

-(NSDictionary *)jsonForUnset {
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
    for(NSString * key in [self unsetDict]) {
        NSDictionary * jsonDict = [AVRequestManager unsetOp:key];
        [dict addEntriesFromDictionary:jsonDict];
    }
    return dict;
}

-(NSDictionary *)jsonForAddRelation {
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
    for(NSString * key in [self addRelationDict]) {
        NSArray * objects = [[self addRelationDict] objectForKey:key];
        NSDictionary * jsonDict = [AVRequestManager addRelationObjectOp:key objects:objects];
        [dict addEntriesFromDictionary:jsonDict];
    }
    return dict;
}

-(NSDictionary *)jsonForRemoveRelation {
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
    for(NSString * key in [self removeRelationDict]) {
        NSArray * objects = [[self removeRelationDict] objectForKey:key];
        NSDictionary * jsonDict = [AVRequestManager removeRelationObjectOp:key objects:objects];
        [dict addEntriesFromDictionary:jsonDict];
    }
    return dict;
}

-(NSDictionary *)jsonForInc {
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
    for(NSString * key in [self incDict]) {
        double value = [[[self incDict] objectForKey:key] doubleValue];
        NSDictionary * jsonDict = [AVRequestManager incOp:key value:value];
        [dict addEntriesFromDictionary:jsonDict];
    }
    return dict;
}

-(NSDictionary *)jsonForAdd {
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
    for(NSString * key in [self addDict]) {
        NSArray * array = [[self addDict] objectForKey:key];
        NSDictionary * jsonDict = [AVRequestManager addObjectOp:key objects:array];
        [dict addEntriesFromDictionary:jsonDict];
    }
    return dict;
}

-(NSDictionary *)jsonForAddUnique {
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
    for(NSString * key in [self addUniqueDict]) {
        NSArray * array = [[self addUniqueDict] objectForKey:key];
        NSDictionary * jsonDict = [AVRequestManager addUniqueObjectOp:key objects:array];
        [dict addEntriesFromDictionary:jsonDict];
    }
    return dict;
}

-(NSDictionary *)jsonForRemove {
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
    for(NSString * key in [self removeDict]) {
        NSArray * objects = [[self removeDict] objectForKey:key];
        NSDictionary * jsonDict = [AVRequestManager removeObjectOp:key objects:objects];
        [dict addEntriesFromDictionary:jsonDict];
    }
    return dict;
}

// add entry from dict to parent and remove the entry from target.
-(void)addDictionary:(NSDictionary *)dict
                  to:(NSMutableDictionary *)parent
              update:(NSMutableDictionary *)target {
    for(NSString * key in dict) {
        id valueObject = [parent objectForKey:key];
        if (valueObject == nil) {
            valueObject = [dict valueForKey:key];
            [parent setObject:valueObject forKey:key];
            [target removeObjectForKey:key];
        }
    }
}

-(NSMutableDictionary *)initialSetDict {
    NSMutableDictionary * result = [NSMutableDictionary dictionary];
    NSDictionary * dict = [self jsonForSet:YES];
    [self addDictionary:dict to:result update:[self setDict]];
    
    // for op, cannot be used in initial save, ignore.
    /*    
    dict = [self jsonForUnset];
    [self addDictionary:dict to:result update:[self unsetDict]];

    dict = [self jsonForAddRelation];
    [self addDictionary:dict to:result update:[self addRelationDict]];
    
    dict = [self jsonForRemoveRelation];
    [self addDictionary:dict to:result update:[self removeRelationDict]];
    
    dict = [self jsonForInc];
    [self addDictionary:dict to:result update:[self incDict]];
    
    dict = [self jsonForAddUnique];
    [self addDictionary:dict to:result update:[self addUniqueDict]];
    */
    return result;
}

-(NSMutableDictionary *)initialSetAndAddRelationDict {
    NSMutableDictionary * result = [NSMutableDictionary dictionary];
    NSDictionary * dict = [self jsonForSet:YES];
    [self addDictionary:dict to:result update:[self setDict]];

    dict = [self jsonForAddRelation];
    [self addDictionary:dict to:result update:[self addRelationDict]];
    return result;
}

-(NSMutableArray *)allJsonDict {
    NSMutableArray * array = [NSMutableArray array];
    NSDictionary * dict = [self jsonForSet:YES];
    if (dict.count > 0) {
        [array addObject:dict];
    }
    dict = [self jsonForUnset];
    if (dict.count > 0) {
        [array addObject:dict];
    }    
    dict = [self jsonForAddRelation];
    if (dict.count > 0) {
        [array addObject:dict];
    }
    dict = [self jsonForRemoveRelation];
    if (dict.count > 0) {
        [array addObject:dict];
    }
    dict = [self jsonForInc];
    if (dict.count > 0) {
        [array addObject:dict];
    }
    dict = [self jsonForAdd];
    if (dict.count > 0) {
        [array addObject:dict];
    }
    dict = [self jsonForAddUnique];
    if (dict.count > 0) {
        [array addObject:dict];
    }
    dict = [self jsonForRemove];
    if (dict.count > 0) {
        [array addObject:dict];
    }
    return array;
}

-(BOOL)hasCommonKeys:(NSDictionary *)source
              target:(NSDictionary *)target {
    NSMutableSet * a = [NSMutableSet setWithArray:[source allKeys]];
    NSMutableSet * b = [NSMutableSet setWithArray:[target allKeys]];
    [a intersectSet:b];
    return a.count > 0;
}

// generate a list of json dictionary for LeanCloud.
-(NSMutableArray *)jsonForCloud {
    NSMutableArray * array = [self allJsonDict];
    NSMutableArray * result = [NSMutableArray array];
    NSMutableDictionary * current = [NSMutableDictionary dictionary];
    for(NSMutableDictionary * item in array) {
        if (![self hasCommonKeys:current target:item]) {
            [current addEntriesFromDictionary:item];
        } else {
            [result addObject:current];
            current =  [NSMutableDictionary dictionaryWithDictionary:item];
        }
    }
    if (current.count > 0) {
        [result addObject:current];
    }
    return result;
}

-(BOOL)containsRequest {
    for(NSDictionary * dict in self.dictArray) {
        if (dict.count > 0) {
            return YES;
        }
    }
    return NO;
}

-(void)clear {
    for(NSMutableDictionary * dict in self.dictArray) {
        [dict removeAllObjects];
    }
}

-(void)addObjectACL:(AVObject *)object
               dict:(NSMutableDictionary *)dict {
    if (object.ACL)
    {
        NSDictionary * aclDict = @{ACLTag: object.ACL.permissionsById};
        [dict addEntriesFromDictionary:aclDict];
    }
}


@end
