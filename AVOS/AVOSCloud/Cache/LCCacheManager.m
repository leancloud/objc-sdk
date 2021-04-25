//
//  LCCacheManager.m
//  LeanCloud
//
//  Created by Summer on 13-3-19.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "LCCacheManager.h"
#import "LCErrorUtils.h"
#import "AVUtils.h"
#import "LCPersistenceUtils.h"


@interface LCCacheManager ()
@property (nonatomic, copy) NSString *diskCachePath;

// This is singleton, so the queue doesn't need release
#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong) dispatch_queue_t cacheQueue;
#else
@property (nonatomic, assign) dispatch_queue_t cacheQueue;
#endif

@end

@implementation LCCacheManager
+ (LCCacheManager *)sharedInstance {
    static dispatch_once_t once;
    static LCCacheManager *_sharedInstance;
    dispatch_once(&once, ^{
        _sharedInstance = [[LCCacheManager alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cacheQueue = dispatch_queue_create("avos.paas.cacheQueue", DISPATCH_QUEUE_SERIAL);
        _diskCachePath = [LCCacheManager path];
    }
    return self;
}

#pragma mark - Accessors
+ (NSString *)path {
    return [LCPersistenceUtils avCacheDirectory];
}

- (NSString *)pathForKey:(NSString *)key {
    return [self.diskCachePath stringByAppendingPathComponent:key];
}

- (BOOL)hasCacheForKey:(NSString *)key {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self pathForKey:[key LCMD5String]]];
}
- (BOOL)hasCacheForMD5Key:(NSString *)key {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self pathForKey:key]];
}

- (void)getWithKey:(NSString *)key maxCacheAge:(NSTimeInterval)maxCacheAge block:(AVIdResultBlock)block {
    dispatch_async(self.cacheQueue, ^{
        
        BOOL isTooOld = NO;
        id diskResult =nil;
        if (maxCacheAge<=0) {
            isTooOld=YES;
        } else {
             diskResult=[LCPersistenceUtils getJSONFromPath:[self pathForKey:[key LCMD5String]]];
            if (diskResult && maxCacheAge > 0) {
                NSDate *lastModified = [LCPersistenceUtils lastModified:[self pathForKey:[key LCMD5String]]];
                if ([[NSDate date] timeIntervalSinceDate:lastModified] > maxCacheAge) {
                    isTooOld = YES;
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (diskResult && !isTooOld) {
                if (block) block(diskResult, nil);
            } else {
                if (block) block(nil, LCError(kLCErrorCacheMiss, nil, nil));
            }
        });
    });
}

- (void)saveJSON:(id)JSON forKey:(NSString *)key {
    dispatch_async(self.cacheQueue, ^{
        [LCPersistenceUtils saveJSON:JSON toPath:[self pathForKey:[key LCMD5String]]];
    });
}

#pragma mark - Clear Cache
+ (BOOL)clearAllCache {
    BOOL __block success;
    dispatch_sync([LCCacheManager sharedInstance].cacheQueue, ^{
        NSString *path = [LCCacheManager path];
        success = [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        // ignore create diectory error
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    });
    
    return success;
}

+ (BOOL)clearCacheMoreThanOneDay {
    return [LCCacheManager clearCacheMoreThanDays:1];
}

+ (BOOL)clearCacheMoreThanDays:(NSInteger)numberOfDays {
    BOOL __block success = NO;
    
    // 为了避免冲突把读写cache的操作都放在cacheQueue里面, 这里是同步的block删除
    dispatch_sync([LCCacheManager sharedInstance].cacheQueue, ^{
        [LCPersistenceUtils deleteFilesInDirectory:[LCCacheManager path] moreThanDays:numberOfDays];
    });
    
    return success;
}

- (void)clearCacheForKey:(NSString *)key {
    dispatch_sync(self.cacheQueue, ^{
        [[NSFileManager defaultManager] removeItemAtPath:[self pathForKey:[key LCMD5String]] error:NULL];
    });
}

- (void)clearCacheForMD5Key:(NSString *)key {
    dispatch_sync(self.cacheQueue, ^{
        [[NSFileManager defaultManager] removeItemAtPath:[self pathForKey:key] error:NULL];
    });
}
@end
