//
//  LCUtils_Internal.h
//  LeanCloudObjc
//
//  Created by pzheng on 2021/08/24.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

#import "LCUtils.h"

// ref: https://github.com/keitaito/KeyPathMacroTestApp
#define keyPath(base, path) ({ __unused typeof(base.path) _; @#path; })
#define ivarName(base, path) ({ __unused typeof(base->path) _; @#path; })

#define LC_WAIT_TIL_TRUE(signal, interval) \
do {                                       \
    while(!(signal)) {                     \
        @autoreleasepool {                 \
            if (![[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:(interval)]]) { \
                [NSThread sleepForTimeInterval:(interval)]; \
            }                              \
        }                                  \
    }                                      \
} while (0)

#define LC_WAIT_WITH_ROUTINE_TIL_TRUE(signal, interval, routine) \
do {                                       \
    while(!(signal)) {                     \
        @autoreleasepool {                 \
            routine;                       \
            if (![[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:(interval)]]) { \
                [NSThread sleepForTimeInterval:(interval)]; \
            }                              \
        }                                  \
    }                                      \
} while (0)

@interface LCUtils ()

+ (void)warnMainThreadIfNecessary;

+ (BOOL)containsProperty:(NSString *)name
                 inClass:(Class)objectClass
            containSuper:(BOOL)containSuper
           filterDynamic:(BOOL)filterDynamic;

+ (BOOL)isDynamicProperty:(NSString *)name
                  inClass:(Class)objectClass
                 withType:(Class)targetClass
             containSuper:(BOOL)containSuper;

+ (NSString *)generateUUID;
+ (NSString *)generateCompactUUID;
+ (NSString *)deviceUUID;

+ (void)asynchronizeTask:(void(^)(void))task;

+ (NSString *)MIMEType:(NSString *)filePathOrName;
+ (NSString *)MIMETypeFromPath:(NSString *)fullPath;
+ (NSString *)contentTypeForImageData:(NSData *)data;

@end
