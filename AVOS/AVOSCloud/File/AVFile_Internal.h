//
//  AVFile_Internal.h
//  LeanCloud
//
//  Created by Zhu Zeng on 3/20/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "AVFile.h"
#import "AVNetworking.h"

@interface AVFile  ()

@property (readwrite) NSString *name;

/**
 File path.

 Unlike `localPath`, it can be nil if file not constructed by path.
 */
@property (nonatomic, copy) NSString *path;

/**
 Local file path.

 If file is constructed by path, it is equal to `path`.
 However, if no path, it will return a temporary path for data cache.
 */
@property (nonatomic, readwrite) NSString *localPath;
@property (nonatomic, readwrite, copy) NSString *bucket;
@property (readwrite) NSString *url;
@property (readwrite, strong) NSData * data;
@property (readwrite, strong) AVHTTPRequestOperation * downloadOperation;
@property (nonatomic) BOOL isDirty;
@property (atomic, assign) BOOL onceCallGetFileSize;

@property(nonatomic, strong) NSString *cachePath;

+(AVFile *)fileFromDictionary:(NSDictionary *)dict;
+(NSDictionary *)dictionaryFromFile:(AVFile *)file;

+(NSString *)className;
-(NSString *)mimeType;
-(NSDictionary *)updateMetaData;
- (void)addACLToDict:(NSMutableDictionary *)dict;

+ (void)saveData:(NSData *)data withRemotePath:(NSString *)remotePath;
+ (void)cacheFile:(AVFile *)file;
@end
