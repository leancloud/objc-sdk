//
//  AVDynamicObject.m
//  AVOS
//
//  Created by Tang Tianyong on 27/04/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVDynamicObject.h"
#import <objc/runtime.h>

static NSString *getterNameFromSetter(SEL selector);
static NSString *setterNameFromGetterName(NSString *getterName);

static id getter(id self, SEL _cmd) {
    return [self objectForKey:NSStringFromSelector(_cmd)];
}

static void setter(id self, SEL _cmd, id value) {
    [self setObject:value forKey:getterNameFromSetter(_cmd)];
}

static void setterWithCopy(id self, SEL _cmd, id value) {
    [self setObject:[value copy] forKey:getterNameFromSetter(_cmd)];
}

static BOOL getter_b(id self, SEL _cmd) {
    return [[self objectForKey:NSStringFromSelector(_cmd)] boolValue];
}

static void setter_b(id self, SEL _cmd, BOOL value) {
    [self setObject:@(value) forKey:getterNameFromSetter(_cmd)];
}

static long getter_l(id self, SEL _cmd) {
    return [[self objectForKey:NSStringFromSelector(_cmd)] longValue];
}

static void setter_l(id self, SEL _cmd, long value) {
    [self setObject:@(value) forKey:getterNameFromSetter(_cmd)];
}

static long long getter_ll(id self, SEL _cmd) {
    return [[self objectForKey:NSStringFromSelector(_cmd)] longLongValue];
}

static void setter_ll(id self, SEL _cmd, long long value) {
    [self setObject:@(value) forKey:getterNameFromSetter(_cmd)];
}

static unsigned long long getter_ull(id self, SEL _cmd) {
    return [[self objectForKey:NSStringFromSelector(_cmd)] unsignedLongLongValue];
}

static void setter_ull(id self, SEL _cmd, unsigned long long value) {
    [self setObject:@(value) forKey:getterNameFromSetter(_cmd)];
}

static double getter_d(id self, SEL _cmd) {
    return [[self objectForKey:NSStringFromSelector(_cmd)] doubleValue];
}

static void setter_d(id self, SEL _cmd, double value) {
    [self setObject:[NSNumber numberWithDouble:value] forKey:getterNameFromSetter(_cmd)];
}

static float getter_f(id self, SEL _cmd) {
    return [[self objectForKey:NSStringFromSelector(_cmd)] floatValue];
}

static void setter_f(id self, SEL _cmd, float value) {
    [self setObject:[NSNumber numberWithFloat:value] forKey:getterNameFromSetter(_cmd)];
}

static
NSString *getterNameFromSetter(SEL selector) {
    NSString *string = NSStringFromSelector(selector);
    NSString *key = [string substringWithRange:NSMakeRange(3, string.length - 4)];

    NSString *firstLetter = [[key substringToIndex:1] lowercaseString];
    key = [firstLetter stringByAppendingString:[key substringFromIndex:1]];

    return key;
}

static
NSString *setterNameFromGetterName(NSString *getterName) {
    NSString *setterName = [NSString stringWithFormat:@"set%@%@:",
                            [[getterName substringToIndex:1] uppercaseString],
                            [getterName substringFromIndex:1]];
    return setterName;
}

NS_INLINE
void synthesizeDynamicProperty(Class aClass, NSString *getterName, const char *type, BOOL isCopy) {
    NSString *setterName = [NSString stringWithFormat:@"set%@%@:",
                            [[getterName substringToIndex:1] uppercaseString],
                            [getterName substringFromIndex:1]];

    switch (type[0]) {
    case '@':
        class_addMethod(aClass, NSSelectorFromString(getterName), (IMP)getter, "@@:");
        if (isCopy) {
            class_addMethod(aClass, NSSelectorFromString(setterName), (IMP)setterWithCopy, "v@:@");
        } else {
            class_addMethod(aClass, NSSelectorFromString(setterName), (IMP)setter, "v@:@");
        }
        break;
    case 'f':
        class_addMethod(aClass, NSSelectorFromString(getterName), (IMP)getter_f, "f@:");
        class_addMethod(aClass, NSSelectorFromString(setterName), (IMP)setter_f, "v@:f");
        break;
    case 'd':
        class_addMethod(aClass, NSSelectorFromString(getterName), (IMP)getter_d, "d@:");
        class_addMethod(aClass, NSSelectorFromString(setterName), (IMP)setter_d, "v@:d");
        break;
    case 'q':
        class_addMethod(aClass, NSSelectorFromString(getterName), (IMP)getter_ll, "q@:");
        class_addMethod(aClass, NSSelectorFromString(setterName), (IMP)setter_ll, "v@:q");
        break;
    case 'Q':
        class_addMethod(aClass, NSSelectorFromString(getterName), (IMP)getter_ull, "Q@:");
        class_addMethod(aClass, NSSelectorFromString(setterName), (IMP)setter_ull, "v@:Q");
        break;
    case 'B':
        class_addMethod(aClass, NSSelectorFromString(getterName), (IMP)getter_b, "B@:");
        class_addMethod(aClass, NSSelectorFromString(setterName), (IMP)setter_b, "v@:B");
        break;
    case 'c':
        if (@encode(BOOL)[0] == 'c') {
            class_addMethod(aClass, NSSelectorFromString(getterName), (IMP)getter_b, "B@:");
            class_addMethod(aClass, NSSelectorFromString(setterName), (IMP)setter_b, "v@:B");
            break;
        }
    default:
        class_addMethod(aClass, NSSelectorFromString(getterName), (IMP)getter_l, "l@:");
        class_addMethod(aClass, NSSelectorFromString(setterName), (IMP)setter_l, "v@:l");
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
NSMutableDictionary *synthesizedClassTable() {
    static NSMutableDictionary *dictionary = nil;

    if (!dictionary)
        dictionary = [NSMutableDictionary dictionary];

    return dictionary;
}

NS_INLINE
void prepareDynamicPropertiesForEachClass(Class aClass) {
    NSMutableDictionary *classTable = synthesizedClassTable();
    NSString *address = [NSString stringWithFormat:@"%p", aClass];

    if (!classTable[address]) {
        classTable[address] = @(1);
        synthesizeDynamicProperties(aClass);
    }
}

NS_INLINE
void prepareDynamicProperties(Class aClass) {
    Class eachClass = aClass;
    Class rootClass = [AVDynamicObject class];

    do {
        prepareDynamicPropertiesForEachClass(eachClass);
        if (eachClass == rootClass)
            break;
    } while((eachClass = class_getSuperclass(eachClass)));
}

@implementation AVDynamicObject

+ (void)initialize {
    id lockObject = [AVDynamicObject class];

    @synchronized (lockObject) {
        prepareDynamicProperties(self);
    }
}

- (NSMutableDictionary *)propertyTable {
    @synchronized (self) {
        const char *key = "property-table";
        NSMutableDictionary *propertyTable = nil;
        propertyTable = objc_getAssociatedObject(self, key);

        if (propertyTable)
            return propertyTable;

        propertyTable = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, key, propertyTable, OBJC_ASSOCIATION_RETAIN);

        return propertyTable;
    }
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)key {
    [self setObject:object forKey:key];
}

- (id)objectForKeyedSubscript:(NSString *)key {
    return [self objectForKey:key];
}

- (void)setObject:(id)object forKey:(NSString *)key {
    [self propertyTable][key] = object;
}

- (id)objectForKey:(NSString *)key {
    return [self propertyTable][key];
}

@end
