//
//  AVPersistenceUtils.m
//  paas
//
//  Created by Summer on 13-3-25.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "AVPersistenceUtils.h"
#import <TargetConditionals.h>
#import "AVUtils.h"

#define LCRootDirName @"LeanCloud"
#define LCMessageCacheDirName @"MessageCache"

@implementation AVPersistenceUtils

// MARK: - Home Directory: ~/
+ (NSString *)homeDirectory
{
#if TARGET_OS_IPHONE
    return NSHomeDirectory();
#elif TARGET_OS_OSX
    /// ~/Library/Application Support/LeanCloud/appId
    NSAssert([AVOSCloud getApplicationId] != nil, @"Please call +[AVOSCloud setApplicationId:clientKey:] first.");
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *directoryPath = [paths firstObject];
    directoryPath = [directoryPath stringByAppendingPathComponent:LCRootDirName];
    directoryPath = [directoryPath stringByAppendingPathComponent:[AVOSCloud getApplicationId]];
    [self createDirectoryIfNeeded:directoryPath];
    return directoryPath;
#else
    return nil;
#endif
}

// MARK: - ~/Library
+ (NSString *)homeDirectoryLibrary
{
    return [[self homeDirectory] stringByAppendingPathComponent:@"Library"];
}

// MARK: - ~/Library/Caches
+ (NSString *)homeDirectoryLibraryCaches
{
    return [[self homeDirectoryLibrary] stringByAppendingPathComponent:@"Caches"];
}

// MARK: - ~/Library/Caches/com.leancloud.caches
+ (NSString *)homeDirectoryLibraryCachesLeanCloudCaches
{
    return [[self homeDirectoryLibraryCaches] stringByAppendingPathComponent:@"com.leancloud.caches"];
}

// MARK: - ~/Library/Caches/com.leancloud.caches/Files
+ (NSString *)homeDirectoryLibraryCachesLeanCloudCachesFiles
{
    return [[self homeDirectoryLibraryCachesLeanCloudCaches] stringByAppendingPathComponent:@"Files"];
}

// MARK: - ~/Library/Caches/com.leancloud.caches/Router
+ (NSString *)homeDirectoryLibraryCachesLeanCloudCachesRouter
{
    return [[self homeDirectoryLibraryCachesLeanCloudCaches] stringByAppendingPathComponent:@"Router"];
}

#pragma mark - ~/Documents

// ~/Library/Caches/LeanCloud/{applicationId}
+ (NSString *)cacheSandboxPath {
    NSString *applicationId = [AVOSCloud getApplicationId];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *sandboxPath = [paths firstObject];

    sandboxPath = [sandboxPath stringByAppendingPathComponent:LCRootDirName];
    sandboxPath = [sandboxPath stringByAppendingPathComponent:applicationId];

    [self createDirectoryIfNeeded:sandboxPath];

    return sandboxPath;
}

// ~/Library/Caches/LeanCloud/{applicationId}/KeyValue
+ (NSString *)keyValueDatabasePath {
    return [[self cacheSandboxPath] stringByAppendingPathComponent:@"KeyValue"];
}

// ~/Library/Caches/LeanCloud/{applicationId}/ClientSessionToken
+ (NSString *)clientSessionTokenCacheDatabasePath {
    return [[self cacheSandboxPath] stringByAppendingPathComponent:@"ClientSessionToken"];
}

// ~/Library/Caches/LeanCloud/{applicationId}/UserDefaults
+ (NSString *)userDefaultsPath {
    NSString *path = [self cacheSandboxPath];

    path = [path stringByAppendingPathComponent:@"UserDefaults"];

    return path;
}

// ~/Library/Caches/AVPaasCache, for AVCacheManager
+ (NSString *)avCacheDirectory {
    NSString *ret = [[AVPersistenceUtils homeDirectoryLibraryCaches] stringByAppendingPathComponent:@"AVPaasCache"];
    [self createDirectoryIfNeeded:ret];
    return ret;
}

// ~/Library/Caches/LeanCloud/MessageCache
+ (NSString *)messageCachePath {
    NSString *path = [self homeDirectoryLibraryCaches];
    
    path = [path stringByAppendingPathComponent:LCRootDirName];
    path = [path stringByAppendingPathComponent:LCMessageCacheDirName];
    
    [self createDirectoryIfNeeded:path];
    
    return path;
}

// ~/Library/Caches/LeanCloud/MessageCache/databaseName
+ (NSString *)messageCacheDatabasePathWithName:(NSString *)name {
    if (name) {
        return [[self messageCachePath] stringByAppendingPathComponent:name];
    }
    
    return nil;
}

#pragma mark - ~/Libraray/Private Documents

// ~/Library
+ (NSString *)libraryDirectory {
    static NSString *path = nil;
    if (!path) {
        path = [[self homeDirectory] stringByAppendingPathComponent:@"Library"];
    }
    return path;
}

// ~/Library/Private Documents/AVPaas
+ (NSString *)privateDocumentsDirectory {
    NSString *ret = [[AVPersistenceUtils libraryDirectory] stringByAppendingPathComponent:@"Private Documents/AVPaas"];
    [self createDirectoryIfNeeded:ret];
    return ret;
}

#pragma mark -  Private Documents Concrete Path

+ (NSString *)currentUserArchivePath {
    NSString * path = [[AVPersistenceUtils privateDocumentsDirectory] stringByAppendingString:@"/currentUser"];
    return path;
}

+ (NSString *)currentUserClassArchivePath {
    NSString *path = [[AVPersistenceUtils privateDocumentsDirectory] stringByAppendingString:@"/currentUserClass"];
    return path;
}

+ (NSString *)currentInstallationArchivePath {
    NSString *path = [[AVPersistenceUtils privateDocumentsDirectory] stringByAppendingString:@"/currentInstallation"];
    return path;
}

+ (NSString *)eventuallyPath {
    NSString *ret = [[AVPersistenceUtils privateDocumentsDirectory] stringByAppendingPathComponent:@"OfflineRequests"];
    [self createDirectoryIfNeeded:ret];
    return ret;
}

#pragma mark - File Utils

+ (BOOL)saveJSON:(id)JSON toPath:(NSString *)path {
    if ([JSON isKindOfClass:[NSDictionary class]] || [JSON isKindOfClass:[NSArray class]]) {
        return [NSKeyedArchiver archiveRootObject:JSON toFile:path];
    }
    
    return NO;
}

+ (id)getJSONFromPath:(NSString *)path {
    id JSON = nil;
    @try {
        JSON=[NSKeyedUnarchiver unarchiveObjectWithFile:path];
        
        if ([JSON isMemberOfClass:[NSDictionary class]] || [JSON isMemberOfClass:[NSArray class]]) {
            return JSON;
        }
    }
    @catch (NSException *exception) {
        //deal with the previous file version
        if ([[exception name] isEqualToString:NSInvalidArgumentException]) {
            JSON = [NSMutableDictionary dictionaryWithContentsOfFile:path];
            
            if (!JSON) {
                JSON = [NSMutableArray arrayWithContentsOfFile:path];
            }
        }
    }
    
    return JSON;
}

+(BOOL)removeFile:(NSString *)path
{
    NSError * error = nil;
    BOOL ret = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    return ret;
}

+(BOOL)fileExist:(NSString *)path
{
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

+(BOOL)createFile:(NSString *)path
{
    BOOL ret = [[NSFileManager defaultManager] createFileAtPath:path contents:[NSData data] attributes:nil];
    return ret;
}

+ (void)createDirectoryIfNeeded:(NSString *)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }
}

+ (BOOL)deleteFilesInDirectory:(NSString *)dirPath moreThanDays:(NSInteger)numberOfDays {
    BOOL success = NO;
    
    NSDate *nowDate = [NSDate date];
    NSFileManager *fileMgr = [[NSFileManager alloc] init];
    NSError *error = nil;
    NSArray *directoryContents = [fileMgr contentsOfDirectoryAtPath:dirPath error:&error];
    if (error == nil) {
        for (NSString *path in directoryContents) {
            NSString *fullPath = [dirPath stringByAppendingPathComponent:path];
            NSDate *lastModified = [AVPersistenceUtils lastModified:fullPath];
            if ([nowDate timeIntervalSinceDate:lastModified] < numberOfDays * 24 * 3600)
                continue;
            
            BOOL removeSuccess = [fileMgr removeItemAtPath:fullPath error:&error];
            if (!removeSuccess) {
                AVLoggerE(@"remove error happened");
                success = NO;
            }
        }
    } else {
        AVLoggerE(@"remove error happened");
        success = NO;
    }
    
    return success;
}

// assume the file is exist
+ (NSDate *)lastModified:(NSString *)fullPath {
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:NULL];
    return [fileAttributes fileModificationDate];
}

@end
