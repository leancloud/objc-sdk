
#import "LCRelation.h"
#import "LCQuery.h"
#import "LCUtils.h"
#import "LCObject_Internal.h"
#import "LCQuery_Internal.h"
#import "LCRelation_Internal.h"
#import "LCObjectUtils.h"

@implementation LCRelation

- (LCQuery *)query
{
    NSString *targetClass;
    if (!self.targetClass) {
        targetClass = self.parent.className;
    } else {
        targetClass = self.targetClass;
    }
    LCQuery * query = [LCQuery queryWithClassName:targetClass];
    NSMutableDictionary * dict = [@{@"$relatedTo": @{@"object": [LCObjectUtils dictionaryFromObjectPointer:self.parent], @"key":self.key}} mutableCopy];
    [query setValue:[NSMutableDictionary dictionaryWithDictionary:dict] forKey:@"where"];
    if (!self.targetClass) {
        query.extraParameters = [@{@"redirectClassNameForKey":self.key} mutableCopy];
    }
    return query;
}

- (void)addObject:(LCObject *)object
{
    // check object id
    if (![object hasValidObjectId]) {
        NSException * exception = [NSException exceptionWithName:NSInvalidArgumentException
                                                          reason:@"All objects in a relation must have object ids."
                                                        userInfo:nil];
        [exception raise];
    }
    self.targetClass = object.className;
    [self.parent addRelation:object forKey:self.key submit:YES];
}

- (void)removeObject:(LCObject *)object
{
    [self.parent removeRelation:object forKey:self.key];
}

+(LCQuery *)reverseQuery:(NSString *)parentClassName
             relationKey:(NSString *)relationKey
             childObject:(LCObject *)child
{
    NSDictionary * dict = @{relationKey: [LCObjectUtils dictionaryFromObjectPointer:child]};
    LCQuery * query = [LCQuery queryWithClassName:parentClassName];
    [query setValue:[NSMutableDictionary dictionaryWithDictionary:dict] forKey:@"where"];
    return query;
}

+(LCRelation *)relationFromDictionary:(NSDictionary *)dict {
    LCRelation * relation = [[LCRelation alloc] init];
    relation.targetClass = [dict objectForKey:classNameTag];
    return relation;
}

@end


