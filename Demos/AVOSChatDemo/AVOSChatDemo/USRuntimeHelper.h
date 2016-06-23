//
//  USRuntimeHelper.h
//  USRuntimeHelper
//
//  Created by Qihe Bian on 9/25/14.
//  Copyright (c) 2014 ufosky.com. All rights reserved.
//

#import <Foundation/Foundation.h>

void invokeInstanceMethod(id obj, NSString *selectorName, NSArray *arguments, void *returnValue);
void invokeClassMethod(Class cls, NSString *selectorName, NSArray *arguments, void *returnValue);
void invokeClassMethodByName(NSString *className, NSString *selectorName, NSArray *arguments, void *returnValue);
void swizzleInstanceMethod(Class c, SEL orig, SEL new);
void swizzleClassMethod(Class c, SEL orig, SEL new);