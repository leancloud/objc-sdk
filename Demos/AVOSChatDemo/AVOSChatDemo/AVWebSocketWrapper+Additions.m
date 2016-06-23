//
//  AVWebSocketWrapper+Additions.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 10/23/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "AVWebSocketWrapper+Additions.h"
#include <objc/runtime.h>
#import "USRuntimeHelper.h"

static void reconnect(id self, SEL _cmd) {
    NSLog(@"%@", [NSThread callStackSymbols]);
    NSMutableArray *args = [NSMutableArray array];
    invokeInstanceMethod(self, @"_reconnect", args, NULL);
    return;
}
static void openWebSocketConnection(id self, SEL _cmd) {
    NSLog(@"%@", [NSThread callStackSymbols]);
    NSMutableArray *args = [NSMutableArray array];
    invokeInstanceMethod(self, @"_openWebSocketConnection", args, NULL);
    return;
}

@implementation AVWebSocketWrapper (Additions)
+ (void)load {
//    {
//        Class c = self;
//        SEL oldSel = NSSelectorFromString(@"reconnect");
//        SEL newSel = NSSelectorFromString(@"_reconnect");
//        NSString *types = [NSString stringWithFormat:@"%@", @"v@:"];
//        class_addMethod(c, newSel, (IMP) reconnect, [types UTF8String]);
//        swizzleInstanceMethod([self class], oldSel, newSel);
//    }
//    {
//        Class c = self;
//        SEL oldSel = NSSelectorFromString(@"openWebSocketConnection");
//        SEL newSel = NSSelectorFromString(@"_openWebSocketConnection");
//        NSString *types = [NSString stringWithFormat:@"%@", @"v@:"];
//        class_addMethod(c, newSel, (IMP) openWebSocketConnection, [types UTF8String]);
//        swizzleInstanceMethod([self class], oldSel, newSel);
//    }
}
@end