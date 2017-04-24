//
//  AVPersistenceUtils.m
//  paas
//
//  Created by Summer on 13-3-25.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "AVPersistenceUtils.h"
#import "AVUtils.h"

#define LCRootDirName @"LeanCloud"
#define LCMessageCacheDirName @"MessageCache"

@implementation AVPersistenceUtils

#pragma mark - Sandbox Path

// Library/Application Support/LeanCloud/Objective-C SDK/{{applicationId}}
+ (NSString *)sandboxPath {
    static NSString *path = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        NSString *applicationId = [AVOSCloud getApplicationId];
        NSAssert(applicationId != nil, @"Please call +[AVOSCloud setApplicationId:clientKey:] first.");

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *tempPath = [paths firstObject];

        tempPath = [tempPath stringByAppendingPathComponent:@"LeanCloud"];
        tempPath = [tempPath stringByAppendingPathComponent:@"Objective-C SDK"];
        tempPath = [tempPath stringByAppendingPathComponent:applicationId];

        [self createDirectoryIfNeeded:tempPath];

        path = tempPath;
    });

    return path;
}

#pragma mark - Caches Path

// Library/Application Support/LeanCloud/Objective-C SDK/{{applicationId}}/Caches
+ (NSString *)cachesPath {
    static NSString *path = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        path = [[self sandboxPath] stringByAppendingPathComponent:@"Caches"];
    });

    return path;
}

// Library/Application Support/LeanCloud/Objective-C SDK/{{applicationId}}/Caches/KeyValue
+ (NSString *)keyValueDatabasePath {
    return [[self cachesPath] stringByAppendingPathComponent:@"KeyValue"];
}

// Library/Application Support/LeanCloud/Objective-C SDK/{{applicationId}}/Caches/CommandCache
+ (NSString *)commandCacheDatabasePath {
    return [[self cachesPath] stringByAppendingPathComponent:@"CommandCache"];
}

// Library/Application Support/LeanCloud/Objective-C SDK/{{applicationId}}/Caches/ClientSessionToken
+ (NSString *)clientSessionTokenCacheDatabasePath {
    return [[self cachesPath] stringByAppendingPathComponent:@"ClientSessionToken"];
}

// Library/Application Support/LeanCloud/Objective-C SDK/{{applicationId}}/Caches/AVPaasCache
+ (NSString *)avCacheDirectory {
    NSString *path = [[self cachesPath] stringByAppendingPathComponent:@"AVPaasCache"];
    [self createDirectoryIfNeeded:path];
    return path;
}

// Library/Application Support/LeanCloud/Objective-C SDK/{{applicationId}}/Caches/AVPaasFiles
+ (NSString *)avFileDirectory {
    NSString *path = [[self cachesPath] stringByAppendingPathComponent:@"AVPaasFiles"];
    [self createDirectoryIfNeeded:path];
    return path;
}

// Library/Application Support/LeanCloud/Objective-C SDK/{{applicationId}}/Caches/MessageCache
+ (NSString *)messageCachePath {
    NSString *path = [self cachesPath];
    path = [path stringByAppendingPathComponent:LCMessageCacheDirName];
    [self createDirectoryIfNeeded:path];
    return path;
}

// Library/Application Support/LeanCloud/Objective-C SDK/{{applicationId}}/Caches/MessageCache/{{name}}
+ (NSString *)messageCacheDatabasePathWithName:(NSString *)name {
    if (name) {
        return [[self messageCachePath] stringByAppendingPathComponent:name];
    }
    return nil;
}

#pragma mark - ~/Libraray/Private Documents

// Library/Application Support/LeanCloud/Objective-C SDK/{{applicationId}}/Private Documents/AVPaas
+ (NSString *)privateDocumentsDirectory {
    NSString *ret = [[self sandboxPath] stringByAppendingPathComponent:@"Private Documents/AVPaas"];
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
