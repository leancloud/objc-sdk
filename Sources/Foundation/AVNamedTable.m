//
//  AVNamedTable.m
//  AVOS
//
//  Created by Tang Tianyong on 27/04/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVNamedTable.h"
#import <objc/runtime.h>

@interface AVNamedTable ()

- (id)objectForSelector:(SEL)selector;

- (void)setObject:(id)object forSelector:(SEL)selector;

@end


static char getter_char(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] charValue];
}

static void setter_char(id self, SEL _cmd, char value) {
    [self setObject:@(value) forSelector:_cmd];
}

static int getter_int(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] intValue];
}

static void setter_int(id self, SEL _cmd, int value) {
    [self setObject:@(value) forSelector:_cmd];
}

static short getter_short(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] shortValue];
}

static void setter_short(id self, SEL _cmd, short value) {
    [self setObject:@(value) forSelector:_cmd];
}

static long getter_long(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] longValue];
}

static void setter_long(id self, SEL _cmd, long value) {
    [self setObject:@(value) forSelector:_cmd];
}

static long long getter_long_long(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] longLongValue];
}

static void setter_long_long(id self, SEL _cmd, long long value) {
    [self setObject:@(value) forSelector:_cmd];
}

static unsigned char getter_unsigned_char(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] unsignedCharValue];
}

static void setter_unsigned_char(id self, SEL _cmd, unsigned char value) {
    [self setObject:@(value) forSelector:_cmd];
}

static unsigned int getter_unsigned_int(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] unsignedIntValue];
}

static void setter_unsigned_int(id self, SEL _cmd, unsigned int value) {
    [self setObject:@(value) forSelector:_cmd];
}

static unsigned short getter_unsigned_short(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] unsignedShortValue];
}

static void setter_unsigned_short(id self, SEL _cmd, unsigned short value) {
    [self setObject:@(value) forSelector:_cmd];
}

static unsigned long getter_unsigned_long(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] unsignedLongValue];
}

static void setter_unsigned_long(id self, SEL _cmd, unsigned long value) {
    [self setObject:@(value) forSelector:_cmd];
}

static unsigned long long getter_unsigned_long_long(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] unsignedLongLongValue];
}

static void setter_unsigned_long_long(id self, SEL _cmd, unsigned long long value) {
    [self setObject:@(value) forSelector:_cmd];
}

static float getter_float(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] floatValue];
}

static void setter_float(id self, SEL _cmd, float value) {
    [self setObject:@(value) forSelector:_cmd];
}

static double getter_double(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] doubleValue];
}

static void setter_double(id self, SEL _cmd, double value) {
    [self setObject:@(value) forSelector:_cmd];
}

static BOOL getter_bool(id self, SEL _cmd) {
    return [[self objectForSelector:_cmd] boolValue];
}

static void setter_bool(id self, SEL _cmd, BOOL value) {
    [self setObject:@(value) forSelector:_cmd];
}

static char *getter_char_pointer(id self, SEL _cmd) {
    return (char *)[[self objectForSelector:_cmd] unsignedLongLongValue];
}

static void setter_char_pointer(id self, SEL _cmd, char *value) {
    [self setObject:@((unsigned long long)value) forSelector:_cmd];
}
static id getter_object(id self, SEL _cmd) {
    return [self objectForSelector:_cmd];
}

static void setter_object(id self, SEL _cmd, id value) {
    [self setObject:value forSelector:_cmd];
}

static void setter_object_copy(id self, SEL _cmd, id value) {
    [self setObject:[value copy] forSelector:_cmd];
}

static Class getter_class(id self, SEL _cmd) {
    return [self objectForSelector:_cmd];
}

static void setter_class(id self, SEL _cmd, Class value) {
    [self setObject:value forSelector:_cmd];
}

static SEL getter_selector(id self, SEL _cmd) {
    NSString *string = [self objectForSelector:_cmd];

    if (string)
        return NSSelectorFromString(string);
    else
        return NULL;
}

static void setter_selector(id self, SEL _cmd, SEL value) {
    if (value)
        [self setObject:NSStringFromSelector(value) forSelector:_cmd];
    else
        [self setObject:nil forSelector:_cmd];
}


NS_INLINE
BOOL hasProperty(id object, NSString *name) {
    return class_getProperty(object_getClass(object), name.UTF8String) != NULL;
}

NS_INLINE
NSString *getPropertyName(objc_property_t property) {
    return @(property_getName(property));
}

NS_INLINE
NSString *firstLowercaseString(NSString *string) {
    NSString *firstLetter = [[string substringToIndex:1] lowercaseString];
    string = [firstLetter stringByAppendingString:[string substringFromIndex:1]];

    return string;
}

NS_INLINE
NSString *firstUppercaseString(NSString *string) {
    NSString *firstLetter = [[string substringToIndex:1] uppercaseString];
    string = [firstLetter stringByAppendingString:[string substringFromIndex:1]];

    return string;
}

NS_INLINE
void synthesizeProperty(Class aClass, NSString *getterName, const char *type, BOOL isCopy) {
    if (!getterName.length)
        return;

    NSString *setterName = [NSString stringWithFormat:@"set%@:", firstUppercaseString(getterName)];

    SEL getter = NSSelectorFromString(getterName);
    SEL setter = NSSelectorFromString(setterName);

    switch (type[0]) {
    case 'c':
        class_replaceMethod(aClass, getter, (IMP)getter_char, "c@:");
        class_replaceMethod(aClass, setter, (IMP)setter_char, "v@:c");
        break;
    case 'i':
        class_replaceMethod(aClass, getter, (IMP)getter_int, "i@:");
        class_replaceMethod(aClass, setter, (IMP)setter_int, "v@:i");
        break;
    case 's':
        class_replaceMethod(aClass, getter, (IMP)getter_short, "s@:");
        class_replaceMethod(aClass, setter, (IMP)setter_short, "v@:s");
        break;
    case 'l':
        class_replaceMethod(aClass, getter, (IMP)getter_long, "l@:");
        class_replaceMethod(aClass, setter, (IMP)setter_long, "v@:l");
        break;
    case 'q':
        class_replaceMethod(aClass, getter, (IMP)getter_long_long, "q@:");
        class_replaceMethod(aClass, setter, (IMP)setter_long_long, "v@:q");
        break;
    case 'C':
        class_replaceMethod(aClass, getter, (IMP)getter_unsigned_char, "C@:");
        class_replaceMethod(aClass, setter, (IMP)setter_unsigned_char, "v@:C");
        break;
    case 'I':
        class_replaceMethod(aClass, getter, (IMP)getter_unsigned_int, "I@:");
        class_replaceMethod(aClass, setter, (IMP)setter_unsigned_int, "v@:I");
        break;
    case 'S':
        class_replaceMethod(aClass, getter, (IMP)getter_unsigned_short, "S@:");
        class_replaceMethod(aClass, setter, (IMP)setter_unsigned_short, "v@:S");
        break;
    case 'L':
        class_replaceMethod(aClass, getter, (IMP)getter_unsigned_long, "L@:");
        class_replaceMethod(aClass, setter, (IMP)setter_unsigned_long, "v@:L");
        break;
    case 'Q':
        class_replaceMethod(aClass, getter, (IMP)getter_unsigned_long_long, "Q@:");
        class_replaceMethod(aClass, setter, (IMP)setter_unsigned_long_long, "v@:Q");
        break;
    case 'f':
        class_replaceMethod(aClass, getter, (IMP)getter_float, "f@:");
        class_replaceMethod(aClass, setter, (IMP)setter_float, "v@:f");
        break;
    case 'd':
        class_replaceMethod(aClass, getter, (IMP)getter_double, "d@:");
        class_replaceMethod(aClass, setter, (IMP)setter_double, "v@:d");
        break;
    case 'B':
        class_replaceMethod(aClass, getter, (IMP)getter_bool, "B@:");
        class_replaceMethod(aClass, setter, (IMP)setter_bool, "v@:B");
        break;
    case '*':
        class_replaceMethod(aClass, getter, (IMP)getter_char_pointer, "*@:");
        class_replaceMethod(aClass, setter, (IMP)setter_char_pointer, "v@:*");
        break;
    case '@':
        class_replaceMethod(aClass, getter, (IMP)getter_object, "@@:");

        if (isCopy)
            class_replaceMethod(aClass, setter, (IMP)setter_object_copy, "v@:@");
        else
            class_replaceMethod(aClass, setter, (IMP)setter_object, "v@:@");

        break;
    case '#':
        class_replaceMethod(aClass, getter, (IMP)getter_class, "#@:");
        class_replaceMethod(aClass, setter, (IMP)setter_class, "v@:#");
        break;
    case ':':
        class_replaceMethod(aClass, getter, (IMP)getter_selector, ":@:");
        class_replaceMethod(aClass, setter, (IMP)setter_selector, "v@::");
        break;
    }
}

NS_INLINE
void synthesizeProperties(Class aClass) {
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(aClass, &propertyCount);

    if (!propertyCount) {
        if (properties)
            free(properties);

        return;
    }

    for (unsigned int i = 0; i < propertyCount; ++i) {
        objc_property_t property = properties[i];
        const char *name = property_getName(property);

        if (!name)
            continue;

        char *type = property_copyAttributeValue(property, "T");
        char *copy = property_copyAttributeValue(property, "C");

        synthesizeProperty(aClass, @(name), type, copy != NULL);

        if (type)
            free(type);
        if (copy)
            free(copy);
    }

    if (properties)
        free(properties);
}

NS_INLINE
NSMutableDictionary *preparedClassTable() {
    static NSMutableDictionary *dictionary = nil;

    if (!dictionary)
        dictionary = [NSMutableDictionary dictionary];

    return dictionary;
}

NS_INLINE
void prepareEachClass(Class aClass) {
    if (!aClass)
        return;

    NSMutableDictionary *classTable = preparedClassTable();
    NSString *key = [NSString stringWithFormat:@"%p", aClass];

    if (classTable[key])
        return;

    classTable[key] = @(1);
    synthesizeProperties(aClass);
}

NS_INLINE
void prepareClass(Class aClass) {
    Class eachClass = aClass;
    Class rootClass = [AVNamedTable class];

    do {
        prepareEachClass(eachClass);
        if (eachClass == rootClass)
            break;
    } while((eachClass = class_getSuperclass(eachClass)));
}

NS_INLINE
void iterateProperties(AVNamedTable *object, void(^block)(objc_property_t property)) {
    Class rootClass = [AVNamedTable class];

    if (![object isKindOfClass:rootClass])
        return;

    Class eachClass = object_getClass(object);
    NSMutableSet *visitedPropertyNames = [NSMutableSet set];

    do {
        unsigned int propertyCount = 0;
        objc_property_t *properties = class_copyPropertyList(eachClass, &propertyCount);

        if (!properties)
            continue;

        for (unsigned int i = 0; i < propertyCount; ++i) {
            objc_property_t property = properties[i];
            char *ivarName = property_copyAttributeValue(property, "V");

            if (!ivarName)
                continue;

            free(ivarName);

            NSString *propertyName = getPropertyName(property);

            if (!propertyName)
                continue;
            if ([visitedPropertyNames containsObject:propertyName])
                continue;

            [visitedPropertyNames addObject:propertyName];

            block(property);
        }

        free(properties);

        eachClass = class_getSuperclass(eachClass);
    } while (eachClass != rootClass);
}

static const char *propertyTableKey = "property-table";


@implementation AVNamedTable

+ (void)initialize {
    id lockAround = [AVNamedTable class];

    @synchronized (lockAround) {
        prepareClass(self);
    }
}

- (instancetype)initWithPropertyTable:(NSMutableDictionary *)propertyTable {
    self = [super init];

    if (self) {
        [self setPropertyTable:propertyTable];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    NSDictionary *propertyTable = [aDecoder decodeObjectForKey:@(propertyTableKey)];
    NSMutableDictionary *mutablePropertyTable = [[NSMutableDictionary alloc] initWithDictionary:propertyTable];

    return [self initWithPropertyTable:mutablePropertyTable];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    NSDictionary *propertyTable = [self propertyTableCopy];

    [aCoder encodeObject:propertyTable forKey:@(propertyTableKey)];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    Class clazz = [self class];
    NSMutableDictionary *propertyTable = [self propertyTableMutableCopy];

    return [[clazz alloc] initWithPropertyTable:propertyTable];
}

- (NSMutableDictionary *)propertyTable {
    @synchronized (self) {
        NSMutableDictionary *propertyTable = nil;
        propertyTable = objc_getAssociatedObject(self, propertyTableKey);

        if (propertyTable)
            return propertyTable;

        propertyTable = [NSMutableDictionary dictionary];

        /* Merge instance variables into property table. */
        NSDictionary *ivarTable = [self getIvarTable];
        [propertyTable addEntriesFromDictionary:ivarTable];

        objc_setAssociatedObject(self, propertyTableKey, propertyTable, OBJC_ASSOCIATION_RETAIN);

        return propertyTable;
    }
}

- (void)setPropertyTable:(NSMutableDictionary *)propertyTable {
    @synchronized (self) {
        objc_setAssociatedObject(self, propertyTableKey, propertyTable, OBJC_ASSOCIATION_RETAIN);
    }
}

- (NSDictionary *)propertyTableCopy {
    return [[self propertyTable] copy];
}

- (NSMutableDictionary *)propertyTableMutableCopy {
    return [[NSMutableDictionary alloc] initWithDictionary:[self propertyTable]];
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)key {
    [self setObject:object forKey:key];
}

- (id)objectForKeyedSubscript:(NSString *)key {
    return [self objectForKey:key];
}

- (void)setObject:(id)object forSelector:(SEL)selector {
    NSString *name = NSStringFromSelector(selector);
    name = [name substringWithRange:NSMakeRange(3, name.length - 4)];

    if (hasProperty(self, name)) {
        [self setObject:object forKey:name];
    } else {
        name = firstLowercaseString(name);
        [self setObject:object forKey:name];
    }
}

- (id)objectForSelector:(SEL)selector {
    NSString *name = NSStringFromSelector(selector);

    if (hasProperty(self, name)) {
        return [self objectForKey:name];
    } else {
        name = firstLowercaseString(name);
        return [self objectForKey:name];
    }
}

- (void)setObject:(id)object forKey:(NSString *)key {
    [self propertyTable][key] = object;
}

- (id)objectForKey:(NSString *)key {
    return [self propertyTable][key] ?: [self getIvarForKey:key];
}

- (id)getIvarForKey:(NSString *)key {
    Class clazz = object_getClass(self);
    objc_property_t property = class_getProperty(clazz, key.UTF8String);

    if (!property)
        return nil;

    return [self getIvarForProperty:property];
}

- (id)getIvarForProperty:(objc_property_t)property {
    Class clazz = object_getClass(self);
    char *ivarName = property_copyAttributeValue(property, "V");

    if (!ivarName)
        return nil;

    Ivar ivar = class_getInstanceVariable(clazz, ivarName);

    free(ivarName);

    if (!ivar)
        return nil;

    char *type = property_copyAttributeValue(property, "T");

    if (!type)
        return nil;

    id result = nil;

    switch (type[0]) {
    case 'c':
    case 'i':
    case 's':
    case 'l':
    case 'q': {
        int64_t number = ((int64_t(*)(id, Ivar))object_getIvar)(self, ivar);
        result = @(number);
    }
        break;
    case 'C':
    case 'I':
    case 'S':
    case 'L':
    case 'Q':
    case '*': {
        uint64_t number = ((uint64_t(*)(id, Ivar))object_getIvar)(self, ivar);
        result = @(number);
    }
        break;
    case 'f':
    case 'd': {
        double number = ((double(*)(id, Ivar))object_getIvar)(self, ivar);
        result = @(number);
    }
        break;
    case 'B': {
        BOOL booleanValue = ((BOOL(*)(id, Ivar))object_getIvar)(self, ivar);
        result = @(booleanValue);
    }
        break;
    case '@':
    case '#':
        result = object_getIvar(self, ivar);
        break;
    case ':': {
        SEL selector = ((SEL(*)(id, Ivar))object_getIvar)(self, ivar);
        result = NSStringFromSelector(selector);
    }
        break;
    default:
        break;
    }

    free(type);

    return result;
}

/**
 Get an table, which the key is property name,
 and the value is the instance variable of that property.
 */
- (NSDictionary *)getIvarTable {
    NSMutableDictionary *ivarTable = [NSMutableDictionary dictionary];

    iterateProperties(self, ^(objc_property_t property) {
        id ivar = [self getIvarForProperty:property];
        if (ivar) {
            NSString *propertyName = getPropertyName(property);
            ivarTable[propertyName] = ivar;
        }
    });

    return ivarTable;
}

- (NSString *)debugDescription {
    return [[self propertyTable] debugDescription];
}

- (NSString *)description {
    return [[self propertyTable] description];
}

@end