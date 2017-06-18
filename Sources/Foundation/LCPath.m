//
//  LCPath.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 18/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCPath.h"
#import "AVApplication+Internal.h"
#import "LCTargetConditionals.h"

#if LC_TARGET_OS_MAC
#import "LCBundle.h"
#endif

static
void LCCreateDirectory(NSString *path) {
    if (!path)
        return;

    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ([fileManager fileExistsAtPath:path])
        return;

    [fileManager createDirectoryAtPath:path
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:NULL];
}

NS_INLINE
NSString *LCHomePath(void) {
    return NSHomeDirectory();
}

static
NSString *LCLibraryPath(void) {
    static NSString *path;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray<NSURL *> *directories = [fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
        NSURL *directory = directories.firstObject;

        if (directory)
            path = [directory path];
        else
            path = [LCHomePath() stringByAppendingPathComponent:@"Library"];

        LCCreateDirectory(path);
    });

    return path;
}

static
NSString *LCApplicationSupportPath(void) {
    static NSString *path;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray<NSURL *> *directories = [fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
        NSURL *directory = directories.firstObject;

        if (directory)
            path = [directory path];
        else
            path = [LCLibraryPath() stringByAppendingPathComponent:@"Application Support"];

        LCCreateDirectory(path);
    });

    return path;
}

static
NSString *LCSDKRoot(void) {
    static NSString *path;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        NSString *applicationSupport = LCApplicationSupportPath();

#if LC_TARGET_OS_MAC
        LCBundle *bundle = [LCBundle current];
        /* On macOS, by convention, all of application support items should be
           put in a subdirectory whose name matches the bundle identifier of the app. */
        path = [[applicationSupport
                 stringByAppendingPathComponent:bundle.identifier]
                 stringByAppendingPathComponent:@"LeanCloud"];
#else
        path = [applicationSupport stringByAppendingPathComponent:@"LeanCloud"];
#endif

        LCCreateDirectory(path);
    });

    return path;
}

@interface LCPath ()

@property (nonatomic, copy) AVApplication *application;

@property (nonatomic, strong) NSFileManager *fileManager;

@end

@implementation LCPath

- (instancetype)init {
    self = [super init];

    if (self) {
        [self doInitialize];
    }

    return self;
}

- (instancetype)initWithApplication:(AVApplication *)application {
    self = [self init];

    if (self) {
        _application = [application copy];
    }

    return self;
}

- (void)doInitialize {
    _fileManager = [NSFileManager defaultManager];
}

- (NSString *)sandbox {
    NSString *relativePath = self.application.relativePath;

    if (!relativePath)
        return nil;

    NSString *SDKRoot = LCSDKRoot();

    NSString *path = [NSString stringWithFormat:@"%@/%@", SDKRoot, relativePath];

    LCCreateDirectory(path);

    return path;
}

- (NSString *)userDefaults {
    NSString *sandbox = self.sandbox;

    if (!sandbox)
        return nil;

    NSString *path = [NSString stringWithFormat:@"%@/UserDefaults", sandbox];

    LCCreateDirectory(path);

    return path;
}

@end
