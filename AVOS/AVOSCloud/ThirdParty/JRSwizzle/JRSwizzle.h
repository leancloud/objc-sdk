// JRSwizzle.h semver:1.1.0
//   Copyright (c) 2007-2016 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   https://github.com/rentzsch/jrswizzle

#import <Foundation/Foundation.h>

@interface NSObject (JRSwizzle)

+ (BOOL)lc_swizzleMethod:(SEL)origSel_ withMethod:(SEL)altSel_ error:(NSError**)error_;
+ (BOOL)lc_swizzleClassMethod:(SEL)origSel_ withClassMethod:(SEL)altSel_ error:(NSError**)error_;


/**
 ```
 __block NSInvocation *invocation = nil;
 invocation = [self lc_swizzleMethod:@selector(initWithCoder:) withBlock:^(id obj, NSCoder *coder) {
 NSLog(@"before %@, coder %@", obj, coder);

 [invocation setArgument:&coder atIndex:2];
 [invocation invokeWithTarget:obj];

 id ret = nil;
 [invocation getReturnValue:&ret];

 NSLog(@"after %@, coder %@", obj, coder);

 return ret;
 } error:nil];
 ```
 */
+ (NSInvocation*)lc_swizzleMethod:(SEL)origSel withBlock:(id)block error:(NSError**)error;

/**
 ```
 __block NSInvocation *classInvocation = nil;
 classInvocation = [self lc_swizzleClassMethod:@selector(test) withBlock:^() {
 NSLog(@"before");

 [classInvocation invoke];

 NSLog(@"after");
 } error:nil];
 ```
 */
+ (NSInvocation*)lc_swizzleClassMethod:(SEL)origSel withBlock:(id)block error:(NSError**)error;

@end
