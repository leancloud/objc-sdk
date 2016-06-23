//
//  AVSession+Additions.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 10/15/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "AVSession+Additions.h"
#include <objc/runtime.h>
#import "USRuntimeHelper.h"

static void sendCommand(id self, SEL _cmd, id command) {
    NSMutableArray *args = [NSMutableArray array];
    id v = command;
    if (!v) {
        v = [NSNull null];
    }
    [args addObject:v];
    void *buf;
    invokeInstanceMethod(command, @"JSONString", nil, &buf);
    id result = (__bridge id)buf;
    NSLog(@"json:%@", result);
    invokeInstanceMethod(self, @"_sendCommand:", args, NULL);
    return;
}

@implementation AVSession (Additions)
//+ (void)load {
//    {
//        Class c = self;
//        SEL oldSel = NSSelectorFromString(@"sendCommand:");
//        SEL newSel = NSSelectorFromString(@"_sendCommand:");
//        NSString *types = [NSString stringWithFormat:@"%@", @"v@:@"];
//        class_addMethod(c, newSel, (IMP) sendCommand, [types UTF8String]);
//        swizzleInstanceMethod([self class], oldSel, newSel);
//    }
//}
@end
