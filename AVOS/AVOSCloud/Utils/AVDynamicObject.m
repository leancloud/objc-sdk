//
//  AVDynamicObject.m
//  AVOS
//
//  Created by Tang Tianyong on 27/04/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVDynamicObject.h"
#import "AVDynamicObject_Internal.h"
#import <objc/runtime.h>

@interface AVDynamicObject ()

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
    if (class_getProperty(object_getClass(object), name.UTF8String)) {
        return TRUE;
    } else {
        return FALSE;
    }
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
void synthesizeDynamicProperty(Class aClass, NSString *getterName, const char *type, BOOL isCopy) {
    if (!getterName.length)
        return;

    NSString *setterName = [NSString stringWithFormat:@"set%@:", firstUppercaseString(getterName)];

    SEL getter = NSSelectorFromString(getterName);
    SEL setter = NSSelectorFromString(setterName);

    switch (type[0]) {
    case 'c':
        class_addMethod(aClass, getter, (IMP)getter_char, "c@:");
        class_addMethod(aClass, setter, (IMP)setter_char, "v@:c");
        break;
    case 'i':
        class_addMethod(aClass, getter, (IMP)getter_int, "i@:");
        class_addMethod(aClass, setter, (IMP)setter_int, "v@:i");
        break;
    case 's':
        class_addMethod(aClass, getter, (IMP)getter_short, "s@:");
        class_addMethod(aClass, setter, (IMP)setter_short, "v@:s");
        break;
    case 'l':
        class_addMethod(aClass, getter, (IMP)getter_long, "l@:");
        class_addMethod(aClass, setter, (IMP)setter_long, "v@:l");
        break;
    case 'q':
        class_addMethod(aClass, getter, (IMP)getter_long_long, "q@:");
        class_addMethod(aClass, setter, (IMP)setter_long_long, "v@:q");
        break;
    case 'C':
        class_addMethod(aClass, getter, (IMP)getter_unsigned_char, "C@:");
        class_addMethod(aClass, setter, (IMP)setter_unsigned_char, "v@:C");
        break;
    case 'I':
        class_addMethod(aClass, getter, (IMP)getter_unsigned_int, "I@:");
        class_addMethod(aClass, setter, (IMP)setter_unsigned_int, "v@:I");
        break;
    case 'S':
        class_addMethod(aClass, getter, (IMP)getter_unsigned_short, "S@:");
        class_addMethod(aClass, setter, (IMP)setter_unsigned_short, "v@:S");
        break;
    case 'L':
        class_addMethod(aClass, getter, (IMP)getter_unsigned_long, "L@:");
        class_addMethod(aClass, setter, (IMP)setter_unsigned_long, "v@:L");
        break;
    case 'Q':
        class_addMethod(aClass, getter, (IMP)getter_unsigned_long_long, "Q@:");
        class_addMethod(aClass, setter, (IMP)setter_unsigned_long_long, "v@:Q");
        break;
    case 'f':
        class_addMethod(aClass, getter, (IMP)getter_float, "f@:");
        class_addMethod(aClass, setter, (IMP)setter_float, "v@:f");
        break;
    case 'd':
        class_addMethod(aClass, getter, (IMP)getter_double, "d@:");
        class_addMethod(aClass, setter, (IMP)setter_double, "v@:d");
        break;
    case 'B':
        class_addMethod(aClass, getter, (IMP)getter_bool, "B@:");
        class_addMethod(aClass, setter, (IMP)setter_bool, "v@:B");
        break;
    case '*':
        class_addMethod(aClass, getter, (IMP)getter_char_pointer, "*@:");
        class_addMethod(aClass, setter, (IMP)setter_char_pointer, "v@:*");
        break;
    case '@':
        class_addMethod(aClass, getter, (IMP)getter_object, "@@:");

        if (isCopy)
            class_addMethod(aClass, setter, (IMP)setter_object_copy, "v@:@");
        else
            class_addMethod(aClass, setter, (IMP)setter_object, "v@:@");

        break;
    case '#':
        class_addMethod(aClass, getter, (IMP)getter_class, "#@:");
        class_addMethod(aClass, setter, (IMP)setter_class, "v@:#");
        break;
    case ':':
        class_addMethod(aClass, getter, (IMP)getter_selector, ":@:");
        class_addMethod(aClass, setter, (IMP)setter_selector, "v@::");
        break;
    }
}

NS_INLINE
void synthesizeDynamicProperties(Class aClass) {
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(aClass, &propertyCount);

    if (!propertyCount) {
        if (properties)
            free(properties);

        return;
    }

    for (unsigned int i = 0; i < propertyCount; ++i) {
        objc_property_t property = properties[i];
        char *dynamic = property_copyAttributeValue(property, "D");

        if (dynamic) {
            free(dynamic);

            const char* name = property_getName(property);

            if (!name)
                continue;

            char *type = property_copyAttributeValue(property, "T");
            char *copy = property_copyAttributeValue(property, "C");

            synthesizeDynamicProperty(aClass, @(name), type, copy != NULL);

            if (type)
                free(type);
            if (copy)
                free(copy);
        }
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
void prepareEachDynamicClass(Class aClass) {
    if (!aClass)
        return;

    NSMutableDictionary *classTable = preparedClassTable();
    NSString *key = [NSString stringWithFormat:@"%p", aClass];

    if (classTable[key])
        return;

    classTable[key] = @(1);
    synthesizeDynamicProperties(aClass);
}

NS_INLINE
void prepareDynamicClass(Class aClass) {
    Class eachClass = aClass;
    Class rootClass = [AVDynamicObject class];

    do {
        prepareEachDynamicClass(eachClass);
        if (eachClass == rootClass)
            break;
    } while((eachClass = class_getSuperclass(eachClass)));
}

@implementation AVDynamicObject

+ (void)initialize {
    id lockAround = [AVDynamicObject class];

    @synchronized (lockAround) {
        prepareDynamicClass(self);
    }
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];

    if (self) {
        [self setPropertyTable:[dictionary mutableCopy]];
    }

    return self;
}

static const char *PropertyTableAssociationKey = "property-table";

- (NSMutableDictionary *)propertyTable {
    @synchronized (self) {
        NSMutableDictionary *propertyTable = nil;
        propertyTable = objc_getAssociatedObject(self, PropertyTableAssociationKey);

        if (propertyTable)
            return propertyTable;

        propertyTable = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, PropertyTableAssociationKey, propertyTable, OBJC_ASSOCIATION_RETAIN);

        return propertyTable;
    }
}

- (void)setPropertyTable:(NSMutableDictionary *)propertyTable {
    @synchronized (self) {
        objc_setAssociatedObject(self, PropertyTableAssociationKey, propertyTable, OBJC_ASSOCIATION_RETAIN);
    }
}

- (NSDictionary *)properties {
    NSDictionary *properties = [NSDictionary dictionaryWithDictionary:[self propertyTable]];
    return properties;
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
    return [self propertyTable][key];
}

- (NSString *)debugDescription {
    return [[self propertyTable] debugDescription];
}

- (NSString *)description {
    return [[self propertyTable] description];
}

@end
