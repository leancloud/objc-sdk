//
//  AVObject+Additions.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 10/10/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "AVObject+Additions.h"
#import <objc/runtime.h>
#import "USRuntimeHelper.h"

static id objectForKey(id self, SEL _cmd, NSString *key) {
//    NSLog(@"key:%@", key);
    if ([key isEqualToString:@"description"]) {
        Ivar ivar = class_getInstanceVariable([self class], "_localData");
        NSMutableDictionary *localData = object_getIvar(self, ivar);
        return [localData objectForKey:key];
    }

    NSMutableArray *args = [NSMutableArray array];
    id v = key;
    if (!v) {
        v = [NSNull null];
    }
    [args addObject:v];
    void *buf;
    invokeInstanceMethod(self, @"_objectForKey:", args, &buf);
    id result = (__bridge id)buf;
    return result;
}

static void setObjectForKey(id self, SEL _cmd, id object, NSString *key) {
//    NSLog(@"key:%@", key);
    if ([key isEqualToString:@"description"]) {
        Ivar ivar = class_getInstanceVariable([self class], "_localData");
        NSMutableDictionary *localData = object_getIvar(self, ivar);
        [localData setObject:object forKey:key];
        return;
    }

    NSMutableArray *args = [NSMutableArray array];
    {
        id v = object;
        if (!v) {
            v = [NSNull null];
        }
        [args addObject:v];
    }
    {
        id v = key;
        if (!v) {
            v = [NSNull null];
        }
        [args addObject:v];
    }
    invokeInstanceMethod(self, @"_setObject:forKey:", args, NULL);
}
static BOOL saveWithBlock_waitUntilDone_eventually_verifyBeforeSave_error(id self, SEL _cmd, AVBooleanResultBlock block, BOOL wait, BOOL isEventually, BOOL verify, NSError **error) {
    NSLog(@"self:%@ block:%@ wait:%d isEventually:%d verify:%d error:%p\n", self, block, wait, isEventually, verify, error);
    NSLog(@"%@", [NSThread callStackSymbols]);
    NSMutableArray *args = [NSMutableArray array];
    {
        id v = block;
        if (!v) {
            v = [NSNull null];
        }
        [args addObject:v];
    }
    {
        NSNumber *v = [NSNumber numberWithBool:wait];
        [args addObject:v];
    }
    {
        NSNumber *v = [NSNumber numberWithBool:isEventually];
        [args addObject:v];
    }
    {
        NSNumber *v = [NSNumber numberWithBool:verify];
        [args addObject:v];
    }
    {
        id v = nil;
        void *pointer = (void *)error;
        if (!pointer) {
            v = [NSNull null];
        } else {
            v = [NSValue valueWithPointer:error];
        }
        [args addObject:v];
    }
    BOOL result;
    invokeInstanceMethod(self, @"_saveWithBlock:waitUntilDone:eventually:verifyBeforeSave:error:", args, &result);
    return result;
}
//- (BOOL)saveWithBlock:(AVBooleanResultBlock)block
//waitUntilDone:(BOOL)wait
//eventually:(BOOL)isEventually
//verifyBeforeSave:(BOOL)verify
//error:(NSError **)theError
@implementation AVObject (Additions)
//+ (void)load {
//    {
//        Class c = self;
//        SEL oldSel = NSSelectorFromString(@"saveWithBlock:waitUntilDone:eventually:verifyBeforeSave:error:");
//        SEL newSel = NSSelectorFromString(@"_saveWithBlock:waitUntilDone:eventually:verifyBeforeSave:error:");
//        NSString *types = [NSString stringWithFormat:@"%s@:%s%s%s%s^@", @encode(BOOL), @encode(AVBooleanResultBlock), @encode(BOOL), @encode(BOOL), @encode(BOOL)];
//        class_addMethod(c, newSel, (IMP) saveWithBlock_waitUntilDone_eventually_verifyBeforeSave_error, [types UTF8String]);
//        swizzleInstanceMethod([self class], oldSel, newSel);
//    }
////    {
////        Class c = self;
////        SEL oldSel = NSSelectorFromString(@"objectForKey:");
////        SEL newSel = NSSelectorFromString(@"_objectForKey:");
////        NSString *types = [NSString stringWithFormat:@"%@", @"@@:@"];
////        class_addMethod(c, newSel, (IMP) objectForKey, [types UTF8String]);
////        swizzleInstanceMethod([self class], oldSel, newSel);
////    }
////    {
////        Class c = self;
////        SEL oldSel = NSSelectorFromString(@"setObject:forKey:");
////        SEL newSel = NSSelectorFromString(@"_setObject:forKey:");
////        NSString *types = [NSString stringWithFormat:@"%@", @"v@:@@"];
////        class_addMethod(c, newSel, (IMP) setObjectForKey, [types UTF8String]);
////        swizzleInstanceMethod([self class], oldSel, newSel);
////    }
//}
@end
