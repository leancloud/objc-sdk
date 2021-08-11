// LCObject.h
// Copyright 2011 LeanCloud Inc. All rights reserved.

#import "LCObject_Internal.h"
#import "LCPaasClient.h"
#import "LCUtils.h"
#import "LCRelation.h"
#import "LCObject_Internal.h"
#import "LCRelation_Internal.h"
#import "LCACL.h"
#import "LCACL_Internal.h"
#import "LCGeoPoint_Internal.h"
#import "LCObjectUtils.h"
#import "LCErrorUtils.h"
#import "LCQuery_Internal.h"

#import "LCObject+Subclass.h"
#import "LCSubclassing.h"
#import "LCSaveOption.h"
#import "LCSaveOption_internal.h"

#import <objc/runtime.h>
#import <objc/message.h>
#import <libkern/OSAtomic.h>

#import "LCUser_Internal.h"
#import "LCInstallation_Internal.h"

#define LC_BATCH_SAVE_SIZE 100
#define LC_BATCH_CONCURRENT_SIZE 20

NSString *const internalIdTag = @"__internalId";

/*!
 A LeanCloud Framework Object that is a local representation of data persisted to the LeanCloud. This is the
 main class that is used to interact with objects in your app.
 */

static BOOL convertingNullToNil = YES;

@interface LCObject ()

+ (NSArray *)invalidKeys;
+ (NSString *)parseClassName;

- (void)iteratePropertiesWithBlock:(void(^)(id object))block withAccessed:(NSMutableSet *)accessed;
- (void)iterateDescendantObjectsWithBlock:(void(^)(id object))block;

@end

NS_INLINE
void iterate_object_with_accessed(id object, void(^block)(id object), NSMutableSet *accessed) {
    if (!object || [accessed containsObject:object]) {
        return;
    }

    [accessed addObject:object];

    if ([object isKindOfClass:[LCObject class]]) {
        [object iteratePropertiesWithBlock:block withAccessed:accessed];
    } else if ([object respondsToSelector:@selector(objectEnumerator)]) {
        for (id value in [[object copy] objectEnumerator]) {
            iterate_object_with_accessed(value, block, accessed);
        }
    }

    if (block) {
        block(object);
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused"

NS_INLINE
BOOL requests_contain_request(NSArray *requests, NSDictionary *request) {
    NSString *internalId = request_internal_id(request);

    for (NSDictionary *request in [requests copy]) {
        if ([internalId isEqualToString:request_internal_id(request)]) {
            return YES;
        }
    }

    return NO;
}

#pragma clang diagnostic pop

@implementation LCObject {
    NSLock *__lock;
    NSRecursiveLock *__requestLock;
}

// MARK: - Internal Sync Lock

- (void)internalSyncLock:(void (^)(void))block
{
    [self->__lock lock];
    block();
    [self->__lock unlock];
}

#pragma mark - Utils Methods

- (BOOL)isDirty {
    BOOL isNewborn = ![self hasValidObjectId];
    BOOL isModified = [self._requestManager containsRequest];

    return isNewborn || isModified;
}

- (NSDictionary *)snapshot {
    return [LCObjectUtils objectSnapshot:self recursive:NO];
}

- (NSString *)description {
    NSDictionary *snapshot = [self snapshot];

    return [NSString stringWithFormat:@"<%@, %@, %@, %@>",
            NSStringFromClass([self class]),
            self.className,
            self.objectId,
            snapshot];
}

#pragma mark - Accessor
- (NSString *)_uuid {
    if (__uuid == nil) {
        __uuid = [LCUtils generateCompactUUID];
    }
    return __uuid;
}

#pragma mark - API

+ (instancetype)objectWithObjectId:(NSString *)objectId {
    LCObject *object = [[[self class] alloc] init];
    object.objectId = objectId;
    return object;
}

+ (instancetype)objectWithClassName:(NSString *)className
{
    LCObject *object = [[self alloc] initWithClassName:className];
    return object;
}

+ (instancetype)objectWithClassName:(NSString *)className objectId:(NSString *)objectId {
    LCObject *object = [self objectWithClassName:className];
    object.objectId = objectId;
    return object;
}

+ (instancetype)objectWithClassName:(NSString *)className dictionary:(NSDictionary *)dictionary
{
    LCObject * object = [self objectWithClassName:className];
    for (NSString *key in [dictionary allKeys]) {
        id value = [dictionary objectForKey:key];
        [object setObject:value forKey:key];
    }
    return object;
}

+ (NSString *)parseClassName {
    return NSStringFromClass([self class]);
}

+ (void)setConvertingNullToNil:(BOOL)yesOrNo {
    convertingNullToNil = yesOrNo;
}

+ (NSArray *)invalidKeys {
    static NSArray *_invalidKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _invalidKeys = @[
            @"objectId",
            @"createdAt",
            @"updatedAt"
        ];
    });
    return _invalidKeys;
}

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        self->__lock = [[NSLock alloc] init];
        self->__requestLock = [[NSRecursiveLock alloc] init];
        _className = [[self class] parseClassName];
        __localData = [[NSMutableDictionary alloc] init];
        __estimatedData = [[NSMutableDictionary alloc] init];
        __relationData = [[NSMutableDictionary alloc] init];
        __operationQueue = [[LCRequestOperationQueue alloc] init];
        __requestManager = [[LCRequestManager alloc] init];
        __submit = YES;
    }
    return self;
}

- (instancetype)initWithClassName:(NSString *)newClassName
{
    self = [self init];
    if (self)
    {
        self.className = newClassName;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [self init];

    if (self) {
        _ACL = [aDecoder decodeObjectForKey:@"ACL"];
        _objectId = [aDecoder decodeObjectForKey:@"objectId"];
        _createdAt = [aDecoder decodeObjectForKey:@"createdAt"];
        _updatedAt = [aDecoder decodeObjectForKey:@"updatedAt"];
        _className = [aDecoder decodeObjectForKey:@"className"];
        __localData = [[aDecoder decodeObjectForKey:@"localData"] mutableCopy] ?: [NSMutableDictionary dictionary];
        __estimatedData = [[aDecoder decodeObjectForKey:@"estimatedData"] mutableCopy] ?: [NSMutableDictionary dictionary];
        __relationData = [[aDecoder decodeObjectForKey:@"relationData"] mutableCopy] ?: [NSMutableDictionary dictionary];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_ACL forKey:@"ACL"];
    [aCoder encodeObject:_objectId forKey:@"objectId"];
    [aCoder encodeObject:_createdAt forKey:@"createdAt"];
    [aCoder encodeObject:_updatedAt forKey:@"updatedAt"];
    [aCoder encodeObject:_className forKey:@"className"];
    [aCoder encodeObject:__localData forKey:@"localData"];
    [aCoder encodeObject:__estimatedData forKey:@"estimatedData"];
    [aCoder encodeObject:__relationData forKey:@"relationData"];
}

- (NSArray *)allKeys
{
    __block NSMutableArray *result = [NSMutableArray array];
    [self internalSyncLock:^{
        for (NSMutableDictionary *dic in @[self._localData, self._estimatedData, self._relationData]) {
            [result addObjectsFromArray:dic.allKeys];
        }
    }];
    return result.copy;
}

-(id)valueForUndefinedKey:(NSString *)key {
    // search in local data and estimated data
    __block id object = nil;
    [self internalSyncLock:^{
        object = self._localData[key];
        if (!object) {
            object = self._estimatedData[key];
        }
    }];
    if (object) {
        return object;
    }
    // dynamic property
    if ([self._relationData objectForKey:key] != nil) {
        object = [self relationForKey:key];
        return object;
    }
    
    // check if it's dynamic relation
    if ([LCUtils isDynamicProperty:key inClass:[self class] withType:[LCRelation class] containSuper:YES]) {
        // need to create relation for the key
        return [self relationForKey:key];
    }
    
    return nil;
}

- (id)objectForKey:(NSString *)key
{
    if (key == nil) {
        return nil;
    }
    id value;
    if ([LCUtils containsProperty:key inClass:[self class] containSuper:YES filterDynamic:YES]) {
        value = [self valueForKey:key];
    } else {
        value = [self valueForUndefinedKey:key];
    }
    if (convertingNullToNil && value == [NSNull null]) {
        return nil;
    } else {
        return value;
    }
}

- (void)updateValue:(id)value forKey:(NSString *)key {
    @synchronized (self) {
        if (!key)
            return;
        if ([LCUtils containsProperty:key inClass:[self class] containSuper:YES filterDynamic:YES]) {
            self._inSetter = YES;
            if ([self isKindOfClass:[LCInstallation class]] &&
                [key isEqualToString:@"channels"]) {
                if ([value isKindOfClass:[NSArray class]]) {
                    [((LCInstallation *)self) updateChannels:(NSArray *)value];
                }
            } else {
                [self setValue:value forKey:key];
            }
            self._inSetter = NO;
        } else {
            [self internalSyncLock:^{
                if (value) {
                    [self._localData setObject:value forKey:key];
                } else {
                    [self._localData removeObjectForKey:key];
                }
            }];
        }
    }
}

- (void)setObject:(id)object
           forKey:(NSString *)key
           submit:(BOOL)s
{
    if (object == nil) {
        if (s) {
            // When manaully set it nil, we remove it.
            [self removeObjectForKey:key];
        }
        return;
    }
    
    // Special case when object is [NSNull null], we also set it like NSDictionary did.
    
    self._submit = s;
    [self updateValue:object forKey:key];
    if (s) {
        [self addSetRequest:key object:object];
    }
    self._submit = YES;
}

- (void)setObject:(id)object forKey:(NSString *)key
{
    if ([key isEqualToString:@"ACL"]) {
        [self setACL:object];
        return;
    }

    if ([[LCObject invalidKeys] containsObject:key]) {
        [NSException raise:NSInvalidArgumentException format:@"The key '%@' is reserved.", key];
    }
    
    if (self._inSetter) {
        return;
    }
    [self setObject:object forKey:key submit:YES];
}

- (void)removeObjectForKey:(NSString *)key
{
    __block BOOL hasKey = NO;
    [self internalSyncLock:^{
        for (NSMutableDictionary *dic in @[self._localData, self._estimatedData, self._relationData]) {
            if ([dic objectForKey:key]) {
                hasKey = YES;
            }
            [dic removeObjectForKey:key];
        }
    }];
    if ([LCUtils containsProperty:key inClass:[self class] containSuper:YES filterDynamic:YES]) {
        /* Create a clean object to produce an empty value. */
        [self setValue:[[[self class] alloc] valueForKey:key] forKey:key];
        hasKey = YES;
    }
    if (hasKey || [self hasValidObjectId]) {
        [self._requestManager unsetRequestForKey:key];
    }
}

- (id)objectForKeyedSubscript:(NSString *)key
{
    return [self objectForKey:key];
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)key
{
    return [self setObject:object forKey:key];
}

-(void)addRelation:(LCObject *)object
            forKey:(NSString *)key
            submit:(BOOL)submit
{
    NSMutableArray * array = [self findArrayForKey:key inDictionary:self._relationData create:YES];
    if (![array containsObject:object])
    {
        [array addObject:object];
    }
    if (submit)
    {
        [self._requestManager addRelationRequestForKey:key object:object];
    }
}

-(void)removeRelation:(LCObject *)object
               forKey:(NSString *)key
{
    NSMutableArray * array = [self findArrayForKey:key  inDictionary:self._relationData create:NO];
    if ([array containsObject:object])
    {
        [array removeObject:object];
    }
    [self._requestManager removeRelationRequestForKey:key object:object];
}

-(NSString *)internalClassName
{
    return self.className;
}

- (LCRelation *)relationForKey:(NSString *)key {
    NSArray * array = [self._relationData objectForKey:key];
    LCObject *target = nil;
    if (array.count > 0)
    {
        target = [array objectAtIndex:0];
    }
    LCRelation *relation = [[LCRelation alloc] init];
    relation.parent = self;
    relation.key = key;
    relation.targetClass = target.className;
    return relation;
}

- (NSString *)childClassNameForRelation:(NSString *)key {
    NSArray * array = [self._relationData objectForKey:key];
    LCObject *target = nil;
    if (array.count > 0)
    {
        target = [array objectAtIndex:0];
    }
    return target.className;
}

-(NSMutableArray *)findArrayForKey:(NSString *)key
                      inDictionary:(NSMutableDictionary *)dict
                            create:(BOOL)create
{
    NSMutableArray * array = [dict objectForKey:key];

    if (array) {
        if (![array isKindOfClass:[NSArray class]]) {
            NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException reason:@"Value referenced by key is not an array." userInfo:nil];
            [exception raise];
        }
        if (![array isKindOfClass:[NSMutableArray class]]) {
            array = [array mutableCopy];
            [dict setObject:array forKey:key];
        }
    } else if (create) {
        array = [[NSMutableArray alloc] init];
        [dict setObject:array forKey:key];
    }

    return array;
}

-(NSMutableArray *)createArrayForKey:(NSString *)key {
    __block id object = nil;
    NSMutableArray * array = [NSMutableArray array];
    [self internalSyncLock:^{
        object = self._localData[key];
        self._localData[key] = array;
    }];
    if (object == nil) {
        return array;
    }
    if ([object isKindOfClass:[NSArray class]]) {
        [array addObjectsFromArray:object];
    } else {
        [array addObject:object];
    }
    return array;
}

- (BOOL)addObject:(id)object
           forKey:(NSString *)key
           unique:(BOOL)unique
{
    if ([LCUtils containsProperty:key inClass:[self class] containSuper:YES filterDynamic:YES]) {
        id v = [self valueForKey:key];
        if (!v) {
            v = [[NSArray alloc] init];
        }
        if ([v isKindOfClass:[NSArray class]]) {
            NSMutableArray *array = [v mutableCopy];
            if (unique && [array containsObject:object]) {
                // no need update local data.
            } else {
                [array addObject:object];
                self._inSetter = YES;
                if ([self isKindOfClass:[LCInstallation class]] &&
                    [key isEqualToString:@"channels"]) {
                    [((LCInstallation *)self) updateChannels:array];
                } else {
                    [self setValue:array forKey:key];
                }
                self._inSetter = NO;
            }
            if (unique) {
                [self._requestManager addUniqueObjectRequestForKey:key object:object];
            } else {
                [self._requestManager setRequestForKey:key object:array];
            }
            return YES;
        } else {
            return NO;
        }
    }
    __block NSMutableArray *array = nil;
    [self internalSyncLock:^{
        array = [self findArrayForKey:key inDictionary:self._localData create:YES];
    }];
    if (unique && [array containsObject:object])
    {
        return NO;
    }
    
    // update local data, we always create new array and copy existing data
    // to the new array.
    array = [self createArrayForKey:key];
    [array addObject:object];
    if (unique) {
        [self._requestManager addUniqueObjectRequestForKey:key object:object];
    } else {
        [self._requestManager addObjectRequestForKey:key object:object];
    }
    return YES;
}

- (void)addObject:(id)object forKey:(NSString *)key
{
    [self addObject:object forKey:key unique:NO];
}

- (void)addObjectsFromArray:(NSArray *)objects forKey:(NSString *)key
{
    for(NSObject * object in [objects copy])
    {
        [self addObject:object forKey:key unique:NO];
    }
}

- (void)addUniqueObject:(id)object forKey:(NSString *)key
{
    [self addObject:object forKey:key unique:YES];
}

- (void)addUniqueObjectsFromArray:(NSArray *)objects forKey:(NSString *)key
{
    for(NSObject * object in [objects copy])
    {
        [self addObject:object forKey:key unique:YES];
    }
}

- (void)removeObject:(id)object forKey:(NSString *)key
{
    __block NSMutableArray * array = nil;
    [self internalSyncLock:^{
        array = [self findArrayForKey:key inDictionary:self._localData create:NO];
    }];
    if (!array) {
        if ([LCUtils containsProperty:key inClass:[self class] containSuper:YES filterDynamic:YES]) {
            array = [self valueForKey:key];
            if (array) {
                if (![array isKindOfClass:[NSMutableArray class]]) {
                    array = [array mutableCopy];
                    if ([self isKindOfClass:[LCInstallation class]] &&
                        [key isEqualToString:@"channels"]) {
                        [((LCInstallation *)self) updateChannels:array];
                    } else {
                        [self setValue:array forKey:key];
                    }
                }
            } else {
                array = [[NSMutableArray alloc] init];
                if ([self isKindOfClass:[LCInstallation class]] &&
                    [key isEqualToString:@"channels"]) {
                    [((LCInstallation *)self) updateChannels:array];
                } else {
                    [self setValue:array forKey:key];
                }
            }
        }
    }
    if (!self.hasValidObjectId)
    {
        return;
    }
    [array removeObject:object];
    [self._requestManager removeObjectRequestForKey:key object:object];

    /* Update value again for compatibility with Swift.
     * Or array value will not be updated after element removed via this method.
     */
    [self updateValue:array forKey:key];
}

- (void)removeObjectsInArray:(NSArray *)objects forKey:(NSString *)key
{
    for(NSObject * object in [objects copy])
    {
        [self removeObject:object forKey:key];
    }
}

-(BOOL)moveToEstimated:(NSString *)key
{
    __block NSNumber * localNumber = nil;
    [self internalSyncLock:^{
        localNumber = self._localData[key];
    }];
    NSNumber * estimatedNumber = [self._estimatedData valueForKey:key];
    if (localNumber != nil)
    {
        [self._estimatedData setValue:localNumber forKey:key];
        [self internalSyncLock:^{
            [self._localData removeObjectForKey:key];
        }];
        return YES;
    }
    if (estimatedNumber != nil)
    {
        return YES;
    }
    return NO;
}

- (void)incrementKey:(NSString *)key
{
    [self incrementKey:key byAmount:@(1)];
}

- (void)incrementKey:(NSString *)key byAmount:(NSNumber *)amount
{
    [self moveToEstimated:key];
    NSNumber * number = [self._estimatedData valueForKey:key];
    double value = [number doubleValue];
    value += [amount doubleValue];
    [self._estimatedData setValue:@(value) forKey:key];
    
    if ([self hasValidObjectId]) {
        [self._requestManager incRequestForKey:key value:[amount doubleValue]];
    } else {
        [self._requestManager setRequestForKey:key object:@(value)];
    }
}

-(void)setACL:(LCACL *)ACL {
    if (ACL && ![ACL isKindOfClass:[LCACL class]]) {
        [NSException raise:NSInvalidArgumentException format:@"An instance of LCACL is required for property 'ACL'."];
    }

    _ACL = ACL;
    [self addSetRequest:ACLTag object:ACL.permissionsById];
}

-(void)addSetRequest:(NSString *)key
              object:(NSObject *)object
{
    if (self._submit) {
        [self._requestManager setRequestForKey:key object:object];
    }
}

#pragma mark - Save

- (BOOL)save
{
    return [self save:NULL];
}

- (BOOL)save:(NSError *__autoreleasing *)error
{
    return [self saveWithOption:nil error:error];
}

- (BOOL)saveAndThrowsWithError:(NSError * _Nullable __autoreleasing *)error {
    return [self save:error];
}

- (BOOL)saveWithOption:(LCSaveOption *)option
                 error:(NSError *__autoreleasing *)error
{
    return [self saveWithOption:option eventually:NO error:error];
}

- (BOOL)saveWithOption:(LCSaveOption *)option
            eventually:(BOOL)eventually
                 error:(NSError *__autoreleasing *)error
{
    return [self saveWithOption:option eventually:eventually verifyBefore:YES error:error];
}

- (BOOL)saveWithOption:(LCSaveOption *)option
            eventually:(BOOL)eventually
          verifyBefore:(BOOL)verifyBefore
                 error:(NSError *__autoreleasing *)error
{
    /* Make validation before save. */
    if (verifyBefore) {
        NSError *preError = [self preSave];

        if (preError) {
            if (error)
                *error = preError;
            return NO;
        }
    }

    /* Synthesize request options. */
    if (!option) {
        option = [[LCSaveOption alloc] init];
    }

    NSError *optionError = [self validateSaveOption:option];

    if (optionError) {
        if (error)
            *error = optionError;
        return NO;
    }

    NSError *requestError = nil;

    [self->__requestLock lock];

    /* Perform save request. */
    do {
        /* If object is clean, ignore save request. */
        if (![self isDirty]) {
            LCLoggerInfo(LCLoggerDomainStorage, @"Object not changed, ignore save request.");
            break;
        }
        
        /* Firstly, save all related files. */
        NSError *fileError = [self saveNewFiles];
        
        if (fileError) {
            requestError = fileError;
            break;
        }

        /* Send object batch save request. */
        NSMutableArray *requests = [self buildSaveRequests];

        /* Apply option to requests. */
        [self applySaveOption:option toRequests:requests];

        if (requests.count > 0) {
            [self sendBatchRequest:requests
                        eventually:eventually
                             error:&requestError];
        }
    } while (NO);
    
    [self->__requestLock unlock];

    if (error) {
        *error = requestError;
    }

    return !requestError;
}

- (NSError *)validateSaveOption:(LCSaveOption *)option {
    NSError *error = nil;

    LCQuery *query = option.query;
    NSString *queryClassName = query.className;

    if (queryClassName && ![queryClassName isEqualToString:self.className]) {
        error = LCError(kLCErrorInvalidClassName, @"Invalid query class name.", nil);
    }

    return error;
}

- (void)applySaveOption:(LCSaveOption *)option toRequests:(NSMutableArray *)requests {
    NSDictionary *params = [option dictionary];

    if (!params.count)
        return;

    [requests enumerateObjectsWithOptions:NSEnumerationReverse
                               usingBlock:^(NSMutableDictionary * _Nonnull request, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([request_method(request) isEqualToString:@"PUT"] &&
            [request_internal_id(request) isEqualToString:self.objectId]) {
            request[@"params"] = params;
            *stop = YES;
        }
    }];
}

- (void)postProcessBatchRequests:(NSMutableArray *)requests {
    /* Add parameter 'new' to newborn objects. */
    for (NSMutableDictionary *request in [requests copy]) {
        if ([request_method(request) isEqualToString:@"POST"] && !request_object_id(request)) {
            request[@"new"] = @(YES);
        }
    }
}

- (void)saveInBackground
{
    [self saveInBackgroundWithBlock:^(BOOL succeeded, NSError * _Nullable error) {
        /* Ignore result intentionally. */
    }];
}

- (void)saveInBackgroundWithBlock:(LCBooleanResultBlock)block
{
    [self saveInBackgroundWithOption:nil block:block];
}

- (void)saveInBackgroundWithOption:(LCSaveOption *)option block:(LCBooleanResultBlock)block {
    [self saveInBackgroundWithOption:option eventually:NO block:block];
}

- (void)saveInBackgroundWithOption:(LCSaveOption *)option eventually:(BOOL)eventually block:(LCBooleanResultBlock)block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        [self saveWithOption:option eventually:eventually error:&error];
        [LCUtils callBooleanResultBlock:block error:error];
    });
}

-(NSError *)preSave
{
    return nil;
}

-(void)postSave
{
    [self._requestManager clear];

    // Reset all descendant objects' requests.
    [self iterateDescendantObjectsWithBlock:^(id object) {
        if ([object isKindOfClass:[LCObject class]]) {
            [[object _requestManager] clear];
        }
    }];
}

-(NSMutableDictionary *)initialBodyData {
    return [self._requestManager initialSetDict];
}

-(void)refreshHasDataForInitial {
    NSMutableSet *visitedObjects = [[NSMutableSet alloc] init];
    [self refreshHasDataForInitial:visitedObjects];
}

-(void)refreshHasDataForInitial:(NSMutableSet *)visitedObjects {
    [visitedObjects addObject:self];
    __block BOOL change = NO;
    [self iterateLocalDataWithBlock:^(NSString *key, id object) {
        if ([object isKindOfClass:[LCObject class]]) {
            if (![visitedObjects containsObject:object]) {
                [object refreshHasDataForInitial:visitedObjects];
                if ([object _hasDataForInitial]) {
                    change = YES;
                }
            }
        }
    }];
    if (change || !self.hasValidObjectId) {
        self._hasDataForInitial = YES;
    } else {
        self._hasDataForInitial = NO;
    }
}

// add all initial save request. save all children together.
-(void)addInitialSaveRequest:(NSMutableArray *)initialSaveArray {
    [self refreshHasDataForInitial];
    NSMutableSet *visitedObjects = [[NSMutableSet alloc] init];
    [self addInitialSaveRequest:initialSaveArray visitedObjects:visitedObjects];
}

-(void)addInitialSaveRequest:(NSMutableArray *)initialSaveArray visitedObjects:(NSMutableSet *)visitedObjects {
    [visitedObjects addObject:self];
    if (![self _hasDataForInitial]) {
        return;
    }
    [self iterateLocalDataWithBlock:^(NSString *key, id object) {
        if ([object isKindOfClass:[LCObject class]]) {
            if (![visitedObjects containsObject:object]) {
                [object addInitialSaveRequest:initialSaveArray visitedObjects:visitedObjects];
            }
        }
    }];

//    if ([self hasDataForCloud]) {
//        return;
//    }
    
    /* make it little bit clear, so don't optimize
     // add the save operation only when there is addRelation/removeRelation ops.
     if (self.requestManager.addRelationObjectDict.count <= 0 &&
     self.requestManager.removeRelationDict.count <= 0) {
     return;
     }
     */
    
    NSString *method = [self initialRequestMethod];
    NSMutableDictionary * body = [self initialBodyData];
    [self addInternalId:body];
    // should use addACLIfExists ?
    [self addDefaultACL:body];
    NSMutableDictionary * item = [LCPaasClient batchMethod:method path:[self initialRequestPath] body:body parameters:[self myParams]];
    [initialSaveArray addObject:item];
}

- (NSString *)initialRequestMethod {
    return [self hasValidObjectId] ? @"PUT" : @"POST";
}

- (NSString *)initialRequestPath {
    return [self myObjectPath];
}

- (NSSet *)allAttachedDirtyFiles {
    NSMutableSet *files = [NSMutableSet set];
    
    [self iterateDescendantObjectsWithBlock:^(id object) {
        if ([object isKindOfClass:[LCFile class]] && ![(LCFile *)object objectId]) {
            [files addObject:object];
        }
    }];
    
    return files;
}

- (NSError *)saveNewFiles{
    NSError *error = nil;
    NSSet   *files = [self allAttachedDirtyFiles];
    
    for (LCFile *file in files) {
        if (![file objectId]) {
            [LCObject saveFile:file];
            
            if (error) {
                return error;
            }
        }
    }
    
    return nil;
}

- (BOOL)shouldIncludeUpdateRequests {
    return YES;
}

- (NSMutableArray *)buildSaveRequests {
    NSMutableArray *requests = [NSMutableArray array];

    do {
        BOOL modified = [self._requestManager containsRequest];

        /* If object saved and not modified, no request. */
        if ([self hasValidObjectId] && !modified)
            break;

        [self addInitialSaveRequest:requests];

        if (![self shouldIncludeUpdateRequests])
            break;

        [self refreshHasDataForCloud];

        /* If object has no update requests and not modified, break. */
        if (!self._hasDataForCloud && !modified)
            break;

        NSArray *updateRequests = [self jsonDataForCloudWithClear:YES];

        [requests addObjectsFromArray:updateRequests];
    } while (0);

    if (requests.count) {
        [self postProcessBatchRequests:requests];
        return requests;
    }

    return nil;
}

-(LCObject *)searchObjectByInternalId:(NSString *)internalId {
    return [self searchObjectByInternalId:internalId visitedObjects:[NSMutableSet set]];
}

-(LCObject *)searchObjectByInternalId:(NSString *)internalId visitedObjects:(NSMutableSet *)visitedObjects {
    [visitedObjects addObject:self];
    if ([internalId isEqualToString:self._uuid]) {
        return self;
    }
    __block NSDictionary *localDataCopy = nil;
    [self internalSyncLock:^{
        localDataCopy = self._localData.copy;
    }];
    for (id key in localDataCopy) {
        id object = localDataCopy[key];
        if ([object isKindOfClass:[LCObject class]]) {
            if ([visitedObjects containsObject:object]) {
                continue;
            } else {
                LCObject * result = [object searchObjectByInternalId:internalId visitedObjects:visitedObjects];
                if (result) {
                    return result;
                }
            }
        }
    }
    return nil;
}

-(BOOL)sendBatchRequest:(NSArray *)batchRequest
             eventually:(BOOL)isEventually
                  error:(NSError **)theError
{
    batchRequest = [batchRequest copy];

    // change post to put and object path if we got objectId. also change child object id.
    for(NSMutableDictionary * dict in batchRequest) {
        NSDictionary * body = [dict objectForKey:@"body"];
        NSString * internalId = [body objectForKey:internalIdTag];
        LCObject * object = [self searchObjectByInternalId:internalId];
        if ([object hasValidObjectId]) {
            [LCPaasClient updateBatchMethod:@"PUT" path:[object myObjectPath] dict:dict];
        }
    }
    __block BOOL hasCallback = NO;
    __block NSError *blockError;
    [[LCPaasClient sharedInstance] postBatchSaveObject:batchRequest headerMap:[self headerMap] eventually:isEventually block:^(id object, NSError *error) {
        [self copyByUUIDFromDictionary:object];
        if(![error.domain isEqualToString:kLeanCloudErrorDomain]) {
            [self postSave];
        }
        if (error) {
            blockError = error;
        }
        hasCallback = YES;
    }];
    LC_WAIT_TIL_TRUE(hasCallback, 0.1);
    if (theError != NULL) {
        *theError = blockError;
    }
    return blockError == nil;
}

- (void)iterateLocalDataWithBlock:(void(^)(NSString *key, id object))block {
    __block NSDictionary *localDataCopy = nil;
    [self internalSyncLock:^{
        localDataCopy = self._localData.copy;
    }];
    for (NSString *key in localDataCopy) {
        block(key, localDataCopy[key]);
    }
}

- (void)copyByUUIDFromDictionary:(NSDictionary *)dic {
    [self copyByUUIDFromDictionary:dic visitedObjects:[NSMutableSet set]];
}

- (void)copyByUUIDFromDictionary:(NSDictionary *)dic visitedObjects:(NSMutableSet *)visitedObjects {
    /**
     Item:
     "c2": {
     {
     52274247e4b00334fc423df7 =     {
     createdAt = "2013-09-04T22:23:03.223Z";
     updatedAt = "2013-09-04T22:23:14.326Z";
     value = 2;
     };
     }
     
     }
     */
    [visitedObjects addObject:self];
    // copy the item to self
    id item = dic[self._uuid];
    if (item && [item isKindOfClass:[NSDictionary class]]) {
        [LCObjectUtils copyDictionary:item toObject:self];
    }
    
    // when put, it may contain value from server side,
    // so update local estimated values too.
    item = dic[self.objectId];
    if (item && [item isKindOfClass:[NSDictionary class]]) {
        [LCObjectUtils copyDictionary:item toObject:self];
    }

    [self iterateLocalDataWithBlock:^(NSString *key, id object) {
        if ([object isKindOfClass:[LCObject class]]) {
            if (![visitedObjects containsObject:object]) {
                [object copyByUUIDFromDictionary:dic visitedObjects:visitedObjects];
            }
        }
    }];
}

-(NSDictionary *)myParams
{
    if (self.fetchWhenSave) {
        return @{@"fetchWhenSave" : @(YES)};
    }
    return nil;
}

- (void)saveEventually
{
    [self saveEventually:^(BOOL succeeded, NSError * _Nullable error) {
        /* Ignore result intentionally. */
    }];
}

- (void)saveEventually:(LCBooleanResultBlock)callback
{
    [self saveInBackgroundWithOption:nil eventually:YES block:callback];
}

+ (BOOL)saveAll:(NSArray *)objects
{
    return [[self class] saveAll:objects error:NULL];
}

- (void)iteratePropertiesWithBlock:(void(^)(id object))block withAccessed:(NSMutableSet *)accessed {
    NSSet *propertyNames = [LCObjectUtils allObjectProperties:[self class]];

    for (NSString *key in propertyNames) {
        iterate_object_with_accessed([self valueForKey:key], block, accessed);
    }
}

- (void)iterateDescendantObjectsWithBlock:(void(^)(id object))block {
    iterate_object_with_accessed(self, block, [NSMutableSet set]);
}

- (NSArray *)descendantFiles {
    NSMutableSet *files = [NSMutableSet set];
    
    [self iterateDescendantObjectsWithBlock:^(id object) {
        if ([object isKindOfClass:[LCFile class]] && ![(LCFile *)object objectId]) {
            [files addObject:object];
        }
    }];
    
    return [files allObjects];
}

+ (NSArray *)descendantFilesOfObjects:(NSArray *)objects {
    NSMutableSet *files = [NSMutableSet set];
    
    for (LCObject *object in [objects copy]) {
        [files addObjectsFromArray:[object descendantFiles]];
    }
    
    return [files allObjects];
}

+ (NSArray *)reduceObjectsFromArray:(NSMutableArray *)array count:(NSInteger)count {
    NSArray *subArray = nil;

    if ([array count] <= count) {
        subArray = [array copy];
        [array removeAllObjects];
    } else {
        NSRange range = NSMakeRange(0, count);
        subArray = [array subarrayWithRange:range];
        [array removeObjectsInRange:range];
    }

    return subArray;
}

// 和 sendBatchRequest 有啥区别？是否可重用？
+ (BOOL)postBatchRequests:(NSArray *)requests forObjects:(NSArray *)objects error:(NSError **)error {
    __block BOOL finished = NO;
    __block NSError *blockError;
    
    [[LCPaasClient sharedInstance] postBatchSaveObject:requests
                                             headerMap:nil
                                            eventually:NO
                                                 block:^(id result, NSError *anError)
    {
        if (!anError) {
            for (LCObject *object in [objects copy]) {
                [object copyByUUIDFromDictionary:result];
            }
        }
        blockError = anError;
        finished = YES;
    }];
    
    LC_WAIT_TIL_TRUE(finished, 0.1);
    if (blockError && error != NULL) {
        *error = blockError;
    }
    return blockError == nil;
}

+ (BOOL)saveDescendantFileOfObjects:(NSArray *)objects error:(NSError **)error {
    NSMutableArray *files = [[self descendantFilesOfObjects:objects] mutableCopy];
    
    __block BOOL saveOK = YES;
    __block NSError *blockError;
    
    while ([files count] && saveOK) {
        __block int32_t uploadCount = 0;
        NSArray *subFiles = [self reduceObjectsFromArray:files count:LC_BATCH_CONCURRENT_SIZE];
        
        for (LCFile *file in subFiles) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                NSError *anError = [LCObject saveFile:file];
                if (anError) {
                    blockError = anError;
                    saveOK = NO;
                }
                
                OSAtomicIncrement32(&uploadCount);
            });
        }
        
        LC_WAIT_TIL_TRUE(uploadCount == [subFiles count], 0.1);
    }
    if (blockError && error != NULL) {
        *error = blockError;
    }
    
    return saveOK;
}

+ (BOOL)saveDescendantRequestsOfObjects:(NSArray *)objects error:(NSError **)error {
    NSMutableArray *requestsArray = [NSMutableArray array];
    NSMutableArray *dirtyObjects = [NSMutableArray array];
    for (LCObject *object in [objects copy]) {
        NSMutableArray *requests = [object buildSaveRequests];
        if (requests.count > 0) {
            [dirtyObjects addObject:object];
            [requestsArray addObject:requests];
        }
    }
    __block BOOL saveOK = YES;

    while ([dirtyObjects count] && saveOK) {
        // requests 在 LC_BATCH_SAVE_SIZE 以内，计算这一批可处理多少个 objects
        NSInteger requestCount = 0;
        NSInteger objectCount = 0;
        for (NSArray *requests in requestsArray) {
            if (requestCount + requests.count > LC_BATCH_SAVE_SIZE) {
                break;
            } else {
                requestCount += requests.count;
                objectCount ++;
            }
        }
        
        NSArray *subObjects = [self reduceObjectsFromArray:dirtyObjects count:objectCount];
        NSArray *subRequestsArray = [self reduceObjectsFromArray:requestsArray count:objectCount];
        // 将二维数组平铺开来
        NSMutableArray *subRequests = [NSMutableArray array];
        for (NSArray *array in subRequestsArray) {
            [subRequests addObjectsFromArray:array];
        }
        NSError *anError;
        if (![self postBatchRequests:subRequests forObjects:subObjects error:&anError]) {
            saveOK = NO;
            if (error) {
                *error = anError;
            }
        }
    }
    return saveOK;
}

+ (BOOL)saveAll:(NSArray *)objects error:(NSError **)error
{
    // Upload descendant files of objects
    NSError *fileUploadError = nil;
    
    if (![self saveDescendantFileOfObjects:objects error:&fileUploadError]) {
        if (error) {
            *error = fileUploadError;
        }
        return NO;
    }
    
    // Post descendant batch requests of objects
    NSError *requestPostError = nil;

    if (![self saveDescendantRequestsOfObjects:objects error:&requestPostError]) {
        if (error) {
            *error = requestPostError;
        }
        return NO;
    }

    return YES;
}

+ (void)saveAllInBackground:(NSArray *)objects
{
    [[self class] saveAllInBackground:objects block:^(BOOL succeeded, NSError * _Nullable error) {
        /* Ignore result intentionally. */
    }];
}

+ (void)saveAllInBackground:(NSArray *)objects
                      block:(LCBooleanResultBlock)block
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSError *error;
        [[self class] saveAll:objects error:&error];
        [LCUtils callBooleanResultBlock:block error:error];
    });
}

- (BOOL)isDataAvailable
{
    return self.objectId.length > 0 && self.createdAt != nil;
}

#pragma mark - Refresh

- (void)refresh
{
    [self refresh:NULL];
}

- (void)refreshWithKeys:(NSArray *)keys {
    [self refreshWithBlock:NULL keys:keys waitUntilDone:YES error:nil];
}

- (BOOL)refresh:(NSError **)error
{
    return [self refreshWithBlock:NULL keys:nil waitUntilDone:YES error:error];
}

- (BOOL)refreshAndThrowsWithError:(NSError * _Nullable __autoreleasing *)error {
    return [self refresh:error];
}

- (void)refreshInBackgroundWithBlock:(LCObjectResultBlock)block {
    [self refreshWithBlock:block keys:nil waitUntilDone:NO error:NULL];
}

- (void)refreshInBackgroundWithKeys:(NSArray *)keys
                              block:(LCObjectResultBlock)block {
    [self refreshWithBlock:block keys:keys waitUntilDone:NO error:NULL];
}

- (BOOL)refreshWithBlock:(LCObjectResultBlock)block
                    keys:(NSArray *)keys
           waitUntilDone:(BOOL)wait
                   error:(NSError **)theError {
    
    BOOL __block hasCalledBack = NO;
    NSError __block *blockError = nil;
    
    NSString *path = [self myObjectPath];
    NSDictionary * parameters = nil;
    if (keys) {
        parameters = [LCQuery dictionaryFromIncludeKeys:keys];
    }
    [[LCPaasClient sharedInstance] getObject:path withParameters:parameters block:^(id object, NSError *error) {
        
        if (error == nil)
        {
            [self removeLocalData];
            [LCObjectUtils copyDictionary:object toObject:self];
        }
        else
        {
            
        }
        if (self == [LCUser currentUser]) {
            [[self class] changeCurrentUser:(LCUser *)self save:YES];
        }
        [LCUtils callObjectResultBlock:block object:self error:error];
        
        if (wait) {
            blockError = error;
            hasCalledBack = YES;
        }
    }];
    
    // wait until called back if necessary
    if (wait) {
        [LCUtils warnMainThreadIfNecessary];
        
        LC_WAIT_TIL_TRUE(hasCalledBack, 0.1);
    };
    
    if (theError != NULL && blockError) {
        *theError = blockError;
        return NO;
    }
    return YES;
}

#pragma mark - Fetch

- (BOOL)fetch
{
    return [self fetch:NULL];
}

- (BOOL)fetch:(NSError **)error
{
    return [self fetchWithKeys:nil error:error];
}

- (BOOL)fetchAndThrowsWithError:(NSError * _Nullable __autoreleasing *)error {
    return [self fetch:error];
}

- (void)fetchWithKeys:(NSArray *)keys {
    [self fetchWithKeys:keys error:nil];
}

- (BOOL)fetchWithKeys:(NSArray *)keys
                error:(NSError **)error {
    __block NSError *blockError;
    __block BOOL hasCallback = NO;
    [self internalFetchInBackgroundWithKeys:keys block:^(LCObject *object, NSError *error) {
        blockError = error;
        hasCallback = YES;
    }];
    LC_WAIT_TIL_TRUE(hasCallback, 0.1);
    if (blockError && error != NULL) {
        *error = blockError;
    }
    return blockError == nil;
}

- (LCObject *)fetchIfNeeded
{
    return [self fetchIfNeededWithKeys:nil];
}

- (LCObject *)fetchIfNeeded:(NSError **)error
{
    return [self fetchIfNeededWithKeys:nil error:error];
}

- (LCObject *)fetchIfNeededAndThrowsWithError:(NSError * _Nullable __autoreleasing *)error {
    return [self fetchIfNeeded:error];
}

- (LCObject *)fetchIfNeededWithKeys:(NSArray *)keys {
    return [self fetchIfNeededWithKeys:keys error:nil];
}

- (LCObject *)fetchIfNeededWithKeys:(NSArray *)keys
                              error:(NSError **)error {
    if (![self isDataAvailable]) {
        [self fetchWithKeys:keys error:error];
    }
    return self;
}

- (void)fetchInBackgroundWithBlock:(LCObjectResultBlock)resultBlock
{
    [self fetchInBackgroundWithKeys:nil block:resultBlock];
}

- (void)fetchInBackgroundWithKeys:(NSArray *)keys
                            block:(LCObjectResultBlock)block {
    [self internalFetchInBackgroundWithKeys:keys block:^(LCObject *object, NSError *error) {
        [LCUtils callObjectResultBlock:block object:object error:error];
    }];
}

- (BOOL)handleFetchResult:(id)object error:(NSError * __autoreleasing *)error {
    if ([object allKeys].count <= 0) {
        if (error != NULL) {
            *error = LCError(kLCErrorObjectNotFound, @"not found the object to fetch", nil);
        }
        return false;
    } else {
        [self removeLocalData];
        [LCObjectUtils copyDictionary:object toObject:self];
        if (self == [LCUser currentUser]) {
            [[self class] changeCurrentUser:(LCUser *)self save:YES];
        }
        return true;
    }
}

- (void)internalFetchInBackgroundWithKeys:(NSArray *)keys
                                    block:(LCObjectResultBlock)resultBlock
{
    
    if (![self hasValidObjectId]) {
        NSError *error = LCError(kLCErrorMissingObjectId, @"Missing ObjectId", nil);
        [LCUtils callObjectResultBlock:resultBlock object:nil error:error];
        return;
    }
    
    NSString *path = [self myObjectPath];
    NSDictionary * parameters = nil;
    if (keys) {
        parameters = [LCQuery dictionaryFromIncludeKeys:keys];
    }
    [[LCPaasClient sharedInstance] getObject:path withParameters:parameters block:^(id object, NSError *error) {
        if (!error) {
            NSError *theError;
            [self handleFetchResult:object error:&theError];
            error = theError;
        }
        if (resultBlock) {
            resultBlock(self, error);
        }
    }];
}

- (void)fetchIfNeededInBackgroundWithBlock:(LCObjectResultBlock)block
{
    if (![self isDataAvailable]) {
        [self fetchInBackgroundWithBlock:^(LCObject *object, NSError *error) {
            if (block) block(object, error);
        }];
    } else {
        if (block) block(self, nil);
    }
}

+ (void)fetchAll:(NSArray *)objects
{
    [[self class] fetchAll:objects error:NULL];
}

+ (BOOL)fetchAll:(NSArray *)objects error:(NSError **)error
{
    return [[self class] fetchAll:objects error:error checkIfNeed:NO];
}

+ (void)fetchAllIfNeeded:(NSArray *)objects
{
    [[self class] fetchAllIfNeeded:objects error:NULL];
}

+ (BOOL)fetchAllIfNeeded:(NSArray *)objects error:(NSError **)error
{
    return [[self class] fetchAll:objects error:error checkIfNeed:YES];
}

+ (BOOL)fetchAll:(NSArray *)objects error:(NSError **)error checkIfNeed:(BOOL)check {
    objects = [objects copy];
    NSError __block *retError;
    if (![self isValidObjects:objects error:&retError]) {
        return NO;
    }
    NSMutableArray *fetches = [NSMutableArray array];
    NSMutableArray *fetchObjects = [NSMutableArray array];
    // Add a task to the group
    for (LCObject *obj in objects) {
        if ([obj isKindOfClass:[LCObject class]]) {
            if (!check || ![obj isDataAvailable]) {
                NSDictionary* fetch = [LCPaasClient batchMethod:@"GET" path:[obj myObjectPath] body:nil parameters:nil];
                [fetches addObject:fetch];
                [fetchObjects addObject:obj];
            }
        }
    }
    if (fetches.count > 0) {
        __block BOOL hasCalledBlcok = NO;
        [[LCPaasClient sharedInstance] postBatchObject:fetches block:^(NSArray *results, NSError *error) {
            if (error) {
                retError = error;
            } else {
                if (results.count == fetches.count) {
                    for (NSInteger i = 0; i < fetches.count; i++) {
                        LCObject *object = fetchObjects[i];
                        id result = results[i];
                        if ([result isKindOfClass:[NSDictionary class]]) {
                            NSError *theError;
                            [object handleFetchResult:result error:&theError];
                            if (theError && retError == nil) {
                                // retError 只需记录第一个错误
                                retError = theError;
                            }
                        } else {
                            if (retError == nil) {
                                retError = result;
                            }
                        }
                    }
                }
            }
            hasCalledBlcok = YES;
        }];
        LC_WAIT_TIL_TRUE(hasCalledBlcok, 0.1);
    }
    if (retError && error) {
        *error=retError;
        return NO;
    }
    return YES;
}

+ (void)fetchAllInBackground:(NSArray *)objects
                       block:(LCArrayResultBlock)block
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSError *error;
        [[self class] fetchAll:objects error:&error];
        [LCUtils callArrayResultBlock:block array:objects error:error];
    });
}

+ (void)fetchAllIfNeededInBackground:(NSArray *)objects
                               block:(LCArrayResultBlock)block
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSError *error;
        [[self class] fetchAllIfNeeded:objects error:&error];
        [LCUtils callArrayResultBlock:block array:objects error:error];
    });
}

#pragma mark - delete

- (void)postDelete {
    
}

- (BOOL)delete
{
    return [self delete:NULL];
}

- (BOOL)delete:(NSError **)error
{
    __block NSError *blockError;
    __block BOOL hasCallback = NO;
    [self internalDeleteWithEventually:NO block:^(BOOL succeeded, NSError *error) {
        blockError = error;
        hasCallback = YES;
    }];
    LC_WAIT_TIL_TRUE(hasCallback, 0.1);
    if (blockError && error) {
        *error = blockError;
    }
    return blockError == nil;
}

- (BOOL)deleteAndThrowsWithError:(NSError * _Nullable __autoreleasing *)error {
    return [self delete:error];
}

- (void)deleteInBackground
{
    [self deleteInBackgroundWithBlock:^(BOOL succeeded, NSError * _Nullable error) {
        /* Ignore result intentionally. */
    }];
}

- (void)deleteInBackgroundWithBlock:(LCBooleanResultBlock)block {
    [self internalDeleteWithEventually:NO block:^(BOOL succeeded, NSError *error) {
        [LCUtils callBooleanResultBlock:block error:error];
    }];
}

- (void)internalDeleteWithEventually:(BOOL)eventually block:(LCBooleanResultBlock)block {
    NSError *error;
    if (![[self class] isValidObjects:@[self] error:&error]) {
        [LCUtils callBooleanResultBlock:block error:error];
        return;
    }
    [self._requestManager clear];
    NSString *path = [self myObjectPath];
    [[LCPaasClient sharedInstance] deleteObject:path withParameters:nil eventually:eventually block:^(id object, NSError *error) {
        if (!error) {
            [self postDelete];
        }
        if (block) {
            block(error == nil, error);
        }
    }];
}

- (void)deleteEventually {
    [self deleteEventuallyWithBlock:^(id  _Nullable object, NSError * _Nullable error) {
        /* Ignore result intentionally. */
    }];
}

- (void)deleteEventuallyWithBlock:(LCIdResultBlock)block {
    [self internalDeleteWithEventually:YES block:^(BOOL succeeded, NSError *error) {
        [LCUtils callIdResultBlock:block object:self error:error];
    }];
}

// check className & objectId
+ (BOOL)isValidObjects:(NSArray *)objects error:(NSError **)error {
    for(LCObject * object in [objects copy]) {
        if (object.className.length <= 0 || ![object hasValidObjectId]) {
            if (error != NULL)
                *error = LCError(kLCErrorMissingObjectId, @"Invaid className or objectId", nil);
            return NO;
        }
    }
    return YES;
}

+ (BOOL)deleteAll:(NSArray *)objects {
    return [self deleteAll:objects error:nil];
}

+ (BOOL)deleteAll:(NSArray *)objects error:(NSError **)error {
    __block NSError *blockError;
    __block BOOL hasCalledBlock = NO;
    [self internalDeleteAllInBackground:objects block:^(BOOL succeeded, NSError *theError) {
        blockError = theError;
        hasCalledBlock = YES;
    }];
    LC_WAIT_TIL_TRUE(hasCalledBlock, 0.1);
    if (blockError && error) {
        *error = blockError;
    }
    return blockError == nil;
}

+ (void)deleteAllInBackground:(NSArray *)objects
                        block:(LCBooleanResultBlock)block {
    [self internalDeleteAllInBackground:objects block:^(BOOL succeeded, NSError *error) {
        [LCUtils callBooleanResultBlock:block error:error];
    }];
}

+ (void)internalDeleteAllInBackground:(NSArray *)objects
                                block:(LCBooleanResultBlock)block {
    objects = [objects copy];
    if (objects.count == 0) {
        [LCUtils callBooleanResultBlock:block error:nil];
        return;
    }
    NSError *error;
    if (![self isValidObjects:objects error:&error]) {
        [LCUtils callBooleanResultBlock:block error:error];
        return;
    }
    NSMutableArray *deletes = [NSMutableArray array];
    for (LCObject *object in objects) {
        NSMutableDictionary *delete = [LCPaasClient batchMethod:@"DELETE" path:[object myObjectPath] body:nil parameters:nil];
        [deletes addObject:delete];
    }
    [[LCPaasClient sharedInstance] postBatchObject:deletes block:^(NSArray *results, NSError *error) {
        if (!error) {
            for (id result in results) {
                if ([result isKindOfClass:[NSDictionary class]]) {
                    // succeed
                    NSInteger index = [results indexOfObject:result];
                    LCObject *object = objects[index];
                    [object postDelete];
                }
            }
        }
        if (block) {
            block(error == nil, error);
        }
    }];
}

-(void)addAclIfExist:(NSMutableDictionary *)data
{
    if (self.ACL)
    {
        NSDictionary * dict = @{@"ACL":self.ACL.permissionsById};
        [data addEntriesFromDictionary:dict];
    }
}

-(NSMutableDictionary *)postData
{
    return [LCObjectUtils objectSnapshot:self];
}

-(void)addChildrenIfExist:(NSMutableDictionary *)dict {
    NSMutableArray *children = [NSMutableArray array];
    
    // visit all children
    [self iterateLocalDataWithBlock:^(NSString *key, id object) {
        if ([object isKindOfClass:[LCObject class]]) {
            if ([object _hasDataForCloud]) {
                NSDictionary * child = [LCObjectUtils childDictionaryFromObject:object withKey:key];
                [children addObject:child];
            }
        }
    }];

    if (children.count > 0) {
        [dict setObject:children forKey:@"__children"];
    }
}

-(void)addInternalId:(NSMutableDictionary *)dict {
    [dict setObject:[self hasValidObjectId] ? self.objectId : self._uuid forKey:internalIdTag];
}

-(void)addDefaultACL:(NSMutableDictionary *)dict {
    if (self.ACL == nil) {
        if ([LCPaasClient sharedInstance].updatedDefaultACL) {
            self.ACL = [LCPaasClient sharedInstance].updatedDefaultACL;
            [dict setObject:[LCPaasClient sharedInstance].updatedDefaultACL.permissionsById forKey:ACLTag];
        }
    }
}

// create batch request from body
-(NSMutableDictionary *)requestFromBody:(NSMutableDictionary *)body {
//    NSString *method = [self hasValidObjectId] ? @"PUT" : @"POST";
    NSString *method = @"PUT";
    BOOL new = ![self hasValidObjectId];
    if (body == nil) {
        body = [NSMutableDictionary dictionary];
    }
    [self addInternalId:body];
    NSMutableDictionary * item = [LCPaasClient batchMethod:method path:[self myObjectPath] body:body parameters:[self myParams]];
    if (new) {
        [item setObject:[NSNumber numberWithBool:new] forKey:@"new"];
    }
    return item;
}

-(void)refreshHasDataForCloud {
    NSMutableSet *visitedObjects = [[NSMutableSet alloc] init];
    [self refreshHasDataForCloud:visitedObjects];
}

-(void)refreshHasDataForCloud:(NSMutableSet *)visitedObjects {
    [visitedObjects addObject:self];
    __block BOOL change = NO;
    [self iterateLocalDataWithBlock:^(NSString *key, id object) {
        if ([object isKindOfClass:[LCObject class]]) {
            if (![visitedObjects containsObject:object]) {
                [object refreshHasDataForCloud:visitedObjects];
                if ([object _hasDataForCloud]) {
                    change = YES;
                }
            }
        }
    }];
    if (change || [self._requestManager containsRequest] || !self.hasValidObjectId) {
        self._hasDataForCloud = YES;
    } else {
        self._hasDataForCloud = NO;
    }
}
// Basic steps
// 1. generate json request from request manager, it generates request from all dirty(changed) fields. In this step, we ignore LCObject set request
// as they will be added later in step3.
// 2. add acl
// 3. add children list(changed) only
// 4. generate intenral id
// 5. add children request into begin of request list
-(NSMutableArray *)dataForCloud {
    //    BOOL hasChild = NO;
    // body array
    [self refreshHasDataForCloud];
    NSMutableSet *visitedObjects = [[NSMutableSet alloc] init];
    return [self dataForCloudWithVisitedObjects:visitedObjects];
}

-(NSMutableArray *)dataForCloudWithVisitedObjects:(NSMutableSet *)visitedObjects {
    [visitedObjects addObject:self];
    //    BOOL hasChild = NO;
    // body array
    NSMutableArray * array = [self._requestManager jsonForCloud];
    NSMutableDictionary * dict = nil;
    if (array.count > 0) {
        dict = [array objectAtIndex:0];
        [self addChildrenIfExist:dict];
    } else {
        dict = [NSMutableDictionary dictionary];
        [self addChildrenIfExist:dict];
        if (dict.count > 0) {
            [array addObject:dict];
        }
    }

    // create request from internal id, method, path and body
    NSMutableArray * json = [NSMutableArray arrayWithCapacity:array.count];
    for(NSMutableDictionary * body in [array copy]) {
        NSDictionary * item = [self requestFromBody:body];
        [json addObject:item];
    }
    
    // for each child call dataForCloud and insert them to the begin of array.
    [self iterateLocalDataWithBlock:^(NSString *key, id object) {
        if ([object isKindOfClass:[LCObject class]]) {
            if (((LCObject *)object)._hasDataForCloud && ![visitedObjects containsObject:object]) {
                NSMutableArray * list = [object dataForCloudWithVisitedObjects:visitedObjects];
                if (list) {
                    NSIndexSet * indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, list.count)];
                    [json insertObjects:list atIndexes:indexSet];
                }
            }
        }
    }];
    return json;
}

-(NSMutableArray *)jsonDataForCloudWithClear:(BOOL)clear {
    NSMutableArray * array = [self dataForCloud];
    if (clear) {
        [self._requestManager clear];
    }
    return array;
}

-(NSDictionary *)headerMap {
    return nil;
}

-(NSString *)myObjectPath
{
    return [LCObjectUtils objectPath:self.className objectId:self.objectId];
}

#pragma mark - Private Methods
- (BOOL)moveIfNeedWithKey:(NSString *)key from:(NSMutableDictionary *)from to:(NSMutableDictionary *)to {
    id object = [from objectForKey:key];
    
    if (object) {
        [to setObject:object forKey:key];
        [from removeObjectForKey:key];
        return YES;
    }
    
    return NO;
}

-(BOOL)hasValidObjectId {
    return (self.objectId.length > 0);
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    if (!other || ![other isKindOfClass:[self class]]) {
        return NO;
    }
    LCObject * otherObject = (LCObject *)other;
    return ([self.objectId isEqualToString:otherObject.objectId] &&
            [self.className isEqualToString:otherObject.className]);
}

+ (NSError *)saveFile:(LCFile *)file
{
    __block NSError *aError = nil;
    __block BOOL waiting = true;
    
    [file uploadWithCompletionHandler:^(BOOL succeeded, NSError * _Nullable error) {
        aError = error;
        waiting = false;
    }];
    
    while (waiting) {
        NSDate *date = [NSDate dateWithTimeIntervalSinceNow:1.0];
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:date];
    }
    
    return aError;
}

// MARK: Serialization & Deserialization

+ (LCObject *)objectWithDictionary:(NSDictionary *)dictionary {
    return [LCObjectUtils lcObjectFromDictionary:dictionary];
}

- (NSMutableDictionary *)dictionaryForObject {
    return [LCObjectUtils objectSnapshot:self];
}

- (void)objectFromDictionary:(NSDictionary *)dictionary {
    [LCObjectUtils copyDictionary:dictionary toObject:self];
}

#pragma mark -

-(void)removeLocalData {
    [self internalSyncLock:^{
        [self._localData removeAllObjects];
    }];
    [self._relationData removeAllObjects];
    [self._estimatedData removeAllObjects];
    [self._requestManager clear];
}

@end


@implementation LCObject (Subclass)

+ (instancetype)object {
    id obj = [[[self class] alloc] init];
    return obj;
}

+ (void)registerSubclass {
    Class objectClass = [self class];
    
    unsigned int numOfProperties, pi;
    objc_property_t *properties = class_copyPropertyList(objectClass, &numOfProperties);
    for (pi = 0; pi < numOfProperties; pi++) {
        objc_property_t property = properties[pi];
        const char* propertyName = property_getName(property);
        const char type = avTypeOfPropertyNamed(objectClass, propertyName)[1];
        //VLog(@"type = %c",type);
        NSString* propertyStr = [NSString stringWithCString:propertyName encoding:NSUTF8StringEncoding];
        Method originalMethod = class_getInstanceMethod(objectClass, NSSelectorFromString(propertyStr));
        if (originalMethod) {
            // 仅仅只替换 dynamic 声明的 property
            continue;
        }

        [[self class] synthesizeWithGetterName:propertyStr
                                          type:type
                                        isCopy:IsPropertyCopy(property)];
        
        //       fprintf(stdout, "%s\n%s\n", property_getName(property), property_getAttributes(property));
        //        VLog(@"%s is %@copy",property_getName(property), IsPropertyCopy(property) ? @"" : @"not ");
    }
    free(properties);
    
    NSString *parseClassName = [self parseClassName];
    
    // + (NSString *)parseClassName must be @"_User"
    
    if ([objectClass isSubclassOfClass:[LCUser class]] && ![parseClassName isEqualToString:[LCUser userTag]]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Cannot initialize a LCUser with a custom class name."];
    }
    
    [[LCPaasClient sharedInstance] addSubclassMapEntry:parseClassName classObject:objectClass];
}

+ (LCQuery *)query {
    return [LCQuery queryWithClassName:[[self class] parseClassName]];
}

#pragma mark - Util
// @selector(setDisplayName:) -> @"displayName"
NSString *KeyFromSetter(SEL selector)
{
    NSString *SELString = NSStringFromSelector(selector);
    NSString *key = [SELString substringWithRange:NSMakeRange(3, SELString.length - 4)];
    key = [NSString stringWithFormat:@"%@%@",
           [[key substringToIndex:1] lowercaseString],
           [key substringFromIndex:1]];
    return key;
}

/**
 R
 The property is read-only (readonly).
 C
 The property is a copy of the value last assigned (copy).
 &
 The property is a reference to the value last assigned (retain).
 N
 The property is non-atomic (nonatomic).
 G<name>
 The property defines a custom getter selector name. The name follows the G (for example, GcustomGetter,).
 S<name>
 The property defines a custom setter selector name. The name follows the S (for example, ScustomSetter:,).
 D
 The property is dynamic (@dynamic).
 W
 The property is a weak reference (__weak).
 P
 The property is eligible for garbage collection.
 t<encoding>
 Specifies the type using old-style encoding.
 */
// support all types not finished
NSDictionary *PropertyTypes(objc_property_t property)
{
    NSMutableDictionary *types = [NSMutableDictionary dictionaryWithCapacity:10];
    return types;
}

BOOL IsPropertyCopy(objc_property_t property)
{
    const char * attrs = property_getAttributes( property );
    NSString *attrsString = [NSString stringWithCString:attrs encoding:NSUTF8StringEncoding];
    
    for (NSString *string in [attrsString componentsSeparatedByString:@","]) {
        if ([string isEqualToString:@"C"]) {
            return YES;
        }
    }
    return NO;
}

// return               T@"NSString"     Ti     Tc
const char * avPropertyGetTypeString( objc_property_t property )
{
    const char * attrs = property_getAttributes( property );
    if ( attrs == NULL )
        return ( NULL );
    
    static char buffer[256];
    const char * e = strchr( attrs, ',' );
    if ( e == NULL )
        return ( NULL );
    
    int len = (int)(e - attrs);
    memcpy( buffer, attrs, len );
    buffer[len] = '\0';
    
    return ( buffer );
}

const char *avTypeOfPropertyNamed(Class objectClass,const char *name)
{
    objc_property_t property = class_getProperty(objectClass, name);
    if ( property == NULL )
        return ( NULL );
    
    return ( avPropertyGetTypeString(property) );
}

#pragma mark - Runtime
// @
static id getter(id self, SEL _cmd)
{
    return [self objectForKey:NSStringFromSelector(_cmd)];
}

static void setter(id self, SEL _cmd, id value)
{
    [self setObject:value forKey:KeyFromSetter(_cmd)];
}

static void setterWithCopy(id self, SEL _cmd, id value)
{
    [self setObject:[value copy] forKey:KeyFromSetter(_cmd)];
}

// Bool
static BOOL getter_b(id self, SEL _cmd)
{
    return [[self objectForKey:NSStringFromSelector(_cmd)] boolValue];
}

static void setter_b(id self, SEL _cmd, BOOL value)
{
    [self setObject:@(value) forKey:KeyFromSetter(_cmd)];
}

// l, i, c,....
static long getter_l(id self, SEL _cmd)
{
    return [[self objectForKey:NSStringFromSelector(_cmd)] longValue];
}

static void setter_l(id self, SEL _cmd, long value)
{
    [self setObject:@(value) forKey:KeyFromSetter(_cmd)];
}

static long long getter_ll(id self, SEL _cmd)
{
    return [[self objectForKey:NSStringFromSelector(_cmd)] longLongValue];
}

static void setter_ll(id self, SEL _cmd, long long value)
{
    [self setObject:@(value) forKey:KeyFromSetter(_cmd)];
}

static unsigned long long getter_ull(id self, SEL _cmd)
{
    return [[self objectForKey:NSStringFromSelector(_cmd)] unsignedLongLongValue];
}

static void setter_ull(id self, SEL _cmd, unsigned long long value)
{
    [self setObject:@(value) forKey:KeyFromSetter(_cmd)];
}

// d
static double getter_d(id self, SEL _cmd)
{
    return [[self objectForKey:NSStringFromSelector(_cmd)] doubleValue];
}

static void setter_d(id self, SEL _cmd, double value)
{
    [self setObject:[NSNumber numberWithDouble:value] forKey:KeyFromSetter(_cmd)];
}

// f
static float getter_f(id self, SEL _cmd)
{
    return [[self objectForKey:NSStringFromSelector(_cmd)] floatValue];
}

static void setter_f(id self, SEL _cmd, float value)
{
    [self setObject:[NSNumber numberWithFloat:value] forKey:KeyFromSetter(_cmd)];
}

/**
 @see https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100-SW1
 */
+(void)synthesizeWithGetterName:(NSString *)getterName type:(const char)type isCopy:(BOOL)isCopy{
    NSString *setterName = [NSString stringWithFormat:@"set%@%@:",
                            [[getterName substringToIndex:1] uppercaseString],
                            [getterName substringFromIndex:1]];
    
    // just handle 3 types in simple   id/double(double float)/long long(char int unsign char .....)
    // Objective-C does not support the long double
    switch (type) {
        case '@':
            // name
            class_addMethod([self class], NSSelectorFromString(getterName),
                            (IMP)getter, "@@:");
            // setName:(id)
            if (isCopy) {
                class_addMethod([self class], NSSelectorFromString(setterName),
                                (IMP)setterWithCopy, "v@:@");
            } else {
                class_addMethod([self class], NSSelectorFromString(setterName),
                                (IMP)setter, "v@:@");
            }
            break;
        case 'f':
            class_addMethod([self class], NSSelectorFromString(getterName),
                            (IMP)getter_f, "f@:");
            class_addMethod([self class], NSSelectorFromString(setterName),
                            (IMP)setter_f, "v@:f");
            break;
        case 'd':
            class_addMethod([self class], NSSelectorFromString(getterName),
                            (IMP)getter_d, "d@:");
            class_addMethod([self class], NSSelectorFromString(setterName),
                            (IMP)setter_d, "v@:d");
            break;
        case 'q':
            class_addMethod([self class], NSSelectorFromString(getterName),
                            (IMP)getter_ll, "q@:");
            class_addMethod([self class], NSSelectorFromString(setterName),
                            (IMP)setter_ll, "v@:q");
            break;
        case 'Q':
            class_addMethod([self class], NSSelectorFromString(getterName),
                            (IMP)getter_ull, "Q@:");
            class_addMethod([self class], NSSelectorFromString(setterName),
                            (IMP)setter_ull, "v@:Q");
            break;
        case 'B':
            class_addMethod([self class], NSSelectorFromString(getterName),
                            (IMP)getter_b, "B@:");
            class_addMethod([self class], NSSelectorFromString(setterName),
                            (IMP)setter_b, "v@:B");
            break;
        case 'c':
            // see BOOL definition in objc.h
            if (@encode(BOOL)[0] == 'c') {
                // 32 bit device or simulator
                class_addMethod([self class], NSSelectorFromString(getterName),
                                (IMP)getter_b, "B@:");
                class_addMethod([self class], NSSelectorFromString(setterName),
                                (IMP)setter_b, "v@:B");
                break;
            }
        default: // all the other handle with long long
            class_addMethod([self class], NSSelectorFromString(getterName),
                            (IMP)getter_l, "l@:");
            // setName:(long long)
            class_addMethod([self class], NSSelectorFromString(setterName),
                            (IMP)setter_l, "v@:l");
            break;
    }
}

- (void)setValue:(id)value forKey:(NSString *)key {
    @try {
        [super setValue:value forKey:key];
    } @catch (NSException *exception) {
        NSString *link = @"https://leancloud.cn/docs/ios_os_x_guide.html#LCObject";
        LCLoggerError(nil, @"Class %@ may contain a reserved property: %@, see %@ for more infomation.", NSStringFromClass([self class]), key, link);

        [exception raise];
    }
}

@end
