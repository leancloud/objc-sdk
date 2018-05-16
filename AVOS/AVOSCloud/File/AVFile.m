
#import <Foundation/Foundation.h>
#import "AVConstants.h"
#import "AVFile.h"
#import "AVFile_Internal.h"
#import "LCFileTaskManager.h"
#import "AVPaasClient.h"
#import "AVUtils.h"
#import "LCNetworking.h"
#import "AVErrorUtils.h"
#import "AVPersistenceUtils.h"
#import "AVObjectUtils.h"
#import "AVACL_Internal.h"
#import <CommonCrypto/CommonCrypto.h>

static NSString * AVFile_CustomPersistentCacheDirectory = nil;

static NSString * AVFile_PersistentCacheDirectory()
{
    return AVFile_CustomPersistentCacheDirectory ?: [AVPersistenceUtils RD_Library_Caches_LeanCloud_Files];
}

static NSString * AVFile_CompactUUID()
{
    return [AVUtils generateCompactUUID];
}

static NSString * AVFile_ObjectPath(NSString *objectId)
{
    return (objectId && objectId.length > 0) ? [@"classes/_file" stringByAppendingPathComponent:objectId] : nil;
}

@implementation AVFile {
    
    NSLock *_lock;
    
    NSMutableDictionary *_rawJSONData;
    
    NSData *_data;
    
    NSString *_localPath;
    
    NSString *_pathExtension;
    
    AVACL *_ACL;
    
    NSDictionary<NSString *, NSString *> *_uploadingHeaders;
    
    NSURLSessionUploadTask *_uploadTask;
    
    NSNumber *_uploadOption;
    
    NSURLSessionDownloadTask *_downloadTask;
}

+ (NSString *)className
{
    return @"File";
}

// MARK: - Create File

+ (instancetype)fileWithData:(NSData *)data
{
    return [[AVFile alloc] initWithData:data name:nil];
}

+ (instancetype)fileWithData:(NSData *)data name:(NSString *)name
{
    return [[AVFile alloc] initWithData:data name:name];
}

+ (instancetype)fileWithLocalPath:(NSString *)localPath
                            error:(NSError * __autoreleasing *)error
{
    return [[AVFile alloc] initWithLocalPath:localPath error:error];
}

+ (instancetype)fileWithRemoteURL:(NSURL *)remoteURL
{
    return [[AVFile alloc] initWithRemoteURL:remoteURL];
}

+ (instancetype)fileWithAVObject:(AVObject *)avObject
{
    return [[AVFile alloc] initWithRawJSONData:[avObject dictionaryForObject]];
}

// MARK: - Initialization

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _lock = [[NSLock alloc] init];
        
        _rawJSONData = [NSMutableDictionary dictionaryWithObject:AVFile.className forKey:kLCFile___type];
    }
    
    return self;
}

- (instancetype)initWithData:(NSData *)data
                        name:(NSString *)name
{
    self = [self init];
    
    if (self) {
        
        _data = data;
        
        _pathExtension = name.pathExtension;
        
        _rawJSONData[kLCFile_name] = (name && name.length > 0) ? name : AVFile_CompactUUID();
        
        _rawJSONData[kLCFile_mime_type] = ({
            
            NSString *mimeType = nil;
            if (name && name.length > 0) {
                mimeType = [AVUtils MIMEType:name];
            }
            if (!mimeType && data.length > 0) {
                mimeType = [AVUtils contentTypeForImageData:data];
            }
            mimeType ?: @"application/octet-stream";
        });
        
        _rawJSONData[kLCFile_metaData] = ({
            
            NSMutableDictionary *metaData = [NSMutableDictionary dictionary];
            metaData[kLCFile_size] = @(data.length);
            NSString *objectId = AVPaasClient.sharedInstance.currentUser.objectId;
            if (objectId && objectId.length > 0) {
                metaData[kLCFile_owner] = objectId;
            }
            metaData.copy;
        });
        
        _ACL = ({
            
            AVACL *acl = AVPaasClient.sharedInstance.updatedDefaultACL;
            if (acl) {
                _rawJSONData[ACLTag] = [AVObjectUtils dictionaryFromACL:acl];
            }
            acl;
        });
    }
    
    return self;
}

- (instancetype)initWithLocalPath:(NSString *)localPath
                            error:(NSError * __autoreleasing *)error
{
    NSDictionary *fileAttributes = [NSFileManager.defaultManager attributesOfItemAtPath:localPath error:error];
    
    if (!fileAttributes) {
        
        return nil;
    }
    
    self = [self init];
    
    if (self) {
        
        _localPath = localPath;
        
        _pathExtension = localPath.pathExtension;
        
        NSString *name = ({
            
            NSString *lastPathComponent = localPath.lastPathComponent;
            (lastPathComponent && lastPathComponent.length > 0) ? lastPathComponent : AVFile_CompactUUID();
        });
        
        _rawJSONData[kLCFile_name] = name;
        
        _rawJSONData[kLCFile_mime_type] = ({
            
            NSString *mimeType = nil;
            if (name && name.length > 0) {
                mimeType = [AVUtils MIMEType:name];
            }
            if (!mimeType && localPath.length > 0) {
                mimeType = [AVUtils MIMETypeFromPath:localPath];
            }
            mimeType ?: @"application/octet-stream";
        });
        
        _rawJSONData[kLCFile_metaData] = ({
            
            NSMutableDictionary *metaData = [NSMutableDictionary dictionary];
            metaData[kLCFile_size] = fileAttributes[NSFileSize];
            NSString *objectId = [AVPaasClient sharedInstance].currentUser.objectId;
            if (objectId && objectId.length > 0) {
                metaData[kLCFile_owner] = objectId;
            }
            metaData.copy;
        });
        
        _ACL = ({
            
            AVACL *acl = [AVPaasClient sharedInstance].updatedDefaultACL;
            if (acl) {
                _rawJSONData[ACLTag] = [AVObjectUtils dictionaryFromACL:acl];
            }
            acl;
        });
    }
    
    return self;
}

- (instancetype)initWithRemoteURL:(NSURL *)remoteURL
{
    self = [self init];
    
    if (self) {
        
        _pathExtension = remoteURL.pathExtension;
        
        NSString *absoluteString = remoteURL.absoluteString;
        
        _rawJSONData[kLCFile_url] = absoluteString;
        
        _rawJSONData[kLCFile_name] = ({
            
            NSString *lastPathComponent = remoteURL.lastPathComponent;
            (lastPathComponent && lastPathComponent.length > 0) ? lastPathComponent : AVFile_CompactUUID();
        });
        
        _rawJSONData[kLCFile_mime_type] = ({
            
            NSString *mimeType = nil;
            if (absoluteString && absoluteString.length > 0) {
                mimeType = [AVUtils MIMEType:absoluteString];
            }
            mimeType ?: @"application/octet-stream";
        });
        
        _rawJSONData[kLCFile_metaData] = @{ kLCFile___source : @"external" };
        
        _ACL = ({
            
            AVACL *acl = [AVPaasClient sharedInstance].updatedDefaultACL;
            if (acl) {
                _rawJSONData[ACLTag] = [AVObjectUtils dictionaryFromACL:acl];
            }
            acl;
        });
    }
    
    return self;
}

- (instancetype)initWithRawJSONData:(NSMutableDictionary *)rawJSONData
{
    self = [self init];
    
    if (self) {
        
        _rawJSONData = rawJSONData;
        
        _pathExtension = ({
            
            NSString *pathExtension = [[NSString lc__decodingDictionary:_rawJSONData key:kLCFile_name] pathExtension];
            if (!pathExtension) {
                pathExtension = [[NSString lc__decodingDictionary:_rawJSONData key:kLCFile_url] pathExtension];
            }
            pathExtension;
        });
        
        _ACL = AVPaasClient.sharedInstance.updatedDefaultACL;
    }
    
    return self;
}

// MARK: - NSCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    
    if (self) {
        
        NSDictionary *dic = [aDecoder decodeObjectForKey:@"dictionary"];
        
        if (dic) {
            
            _rawJSONData = dic.mutableCopy;
            
            _pathExtension = ({
                
                NSString *pathExtension = [[NSString lc__decodingDictionary:_rawJSONData key:kLCFile_name] pathExtension];
                if (!pathExtension) {
                    pathExtension = [[NSString lc__decodingDictionary:_rawJSONData key:kLCFile_url] pathExtension];
                }
                pathExtension;
            });
            
            _ACL = AVPaasClient.sharedInstance.updatedDefaultACL;
        }
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_rawJSONData forKey:@"dictionary"];
}

// MARK: - Lock

- (void)internalSyncLock:(void (^)(void))block
{
    [_lock lock];
    block();
    [_lock unlock];
}

// MARK: - Property

- (AVACL *)ACL
{
    __block AVACL *ACL = nil;
    
    [self internalSyncLock:^{
        
        ACL = _ACL;
    }];
    
    return ACL;
}

- (void)setACL:(AVACL *)ACL
{
    NSDictionary *ACLDic = [AVObjectUtils dictionaryFromACL:ACL];
    
    [self internalSyncLock:^{
        
        _ACL = ACL;
        
        if (ACL) {
            
            _rawJSONData[ACLTag] = ACLDic;
            
        } else {
            
            [_rawJSONData removeObjectForKey:ACLTag];
        }
    }];
}

- (NSDictionary<NSString *,NSString *> *)uploadingHeaders
{
    __block NSDictionary<NSString *,NSString *> *dic = nil;
    
    [self internalSyncLock:^{
        
        dic = _uploadingHeaders;
    }];

    return dic;
}

- (void)setUploadingHeaders:(NSDictionary<NSString *,NSString *> *)uploadingHeaders
{
    [self internalSyncLock:^{
        
        _uploadingHeaders = [uploadingHeaders copy];
    }];
}

- (NSString *)name
{
    __block NSString *name = nil;
    
    [self internalSyncLock:^{
        
        name = [NSString lc__decodingWithKey:kLCFile_name fromDic:_rawJSONData];
    }];
    
    return name;
}

- (NSString *)objectId
{
    __block NSString *objectId = nil;
    
    [self internalSyncLock:^{
        
        objectId = [AVFile decodingObjectIdFromDic:_rawJSONData];
    }];
    
    return objectId;
}

- (NSString *)url
{
    __block NSString *url = nil;

    [self internalSyncLock:^{
        
        url = [NSString lc__decodingWithKey:kLCFile_url fromDic:_rawJSONData];
    }];

    return url;
}

- (NSDictionary *)metaData
{
    __block NSDictionary *metaData = nil;

    [self internalSyncLock:^{
        
        metaData = [AVFile decodingMetaDataFromDic:_rawJSONData];
    }];
    
    return metaData;
}

- (void)setMetaData:(NSDictionary *)metaData
{
    [self internalSyncLock:^{
        
        _rawJSONData[kLCFile_metaData] = metaData;
    }];
}

- (NSString *)ownerId
{
    NSDictionary *metaData = [self metaData];
    
    return metaData ? metaData[kLCFile_owner] : nil;
}

- (void)setOwnerId:(NSString *)ownerId
{
    [self internalSyncLock:^{
        
        NSMutableDictionary *metaData = [[AVFile decodingMetaDataFromDic:_rawJSONData] mutableCopy];
        
        if (metaData) {
            
            if (ownerId) {
                
                metaData[kLCFile_owner] = ownerId;
                
            } else {
                
                [metaData removeObjectForKey:kLCFile_owner];
            }
            
            _rawJSONData[kLCFile_metaData] = [metaData copy];
        }
        else if (ownerId) {
            
            _rawJSONData[kLCFile_metaData] = @{ kLCFile_owner : ownerId };
        }
    }];
}

- (NSString *)checksum
{
    NSDictionary *metaData = [self metaData];
    
    return metaData ? metaData[kLCFile__checksum] : nil;
}

- (void)setChecksum:(NSString *)checksum
{
    [self internalSyncLock:^{
        
        NSMutableDictionary *metaData = [[AVFile decodingMetaDataFromDic:_rawJSONData] mutableCopy];
        
        if (metaData) {
            
            if (checksum) {
                
                metaData[kLCFile__checksum] = checksum;
                
            } else {
                
                [metaData removeObjectForKey:kLCFile__checksum];
            }
            
            _rawJSONData[kLCFile_metaData] = [metaData copy];
        }
        else if (checksum) {
            
            _rawJSONData[kLCFile_metaData] = @{ kLCFile__checksum : checksum };
        }
    }];
}

- (NSUInteger)size
{
    NSDictionary *metaData = [self metaData];
    
    if (metaData) {
        
        id size = metaData[kLCFile_size];
        
        return size ? [size unsignedIntegerValue] : 0;
    }
    
    return 0;
}

- (NSString *)pathExtension
{
    return self->_pathExtension;
}

- (NSString *)mimeType
{
    __block NSString *mimeType = nil;
    
    [self internalSyncLock:^{
        
        mimeType = [NSString lc__decodingWithKey:kLCFile_mime_type fromDic:_rawJSONData];
    }];
    
    return mimeType;
}

- (id)objectForKey:(id)key
{
    __block id value = nil;
    
    [self internalSyncLock:^{
        
        value = [_rawJSONData objectForKey:key];
    }];
    
    return value;
}

- (NSDictionary *)rawJSONDataCopy
{
    __block NSDictionary *dic = nil;
    
    [self internalSyncLock:^{
        
        dic = _rawJSONData.copy;
    }];
    
    return dic;
}

- (NSMutableDictionary *)rawJSONDataMutableCopy
{
    __block NSMutableDictionary *dic = nil;
    
    [self internalSyncLock:^{
        
        dic = _rawJSONData.mutableCopy;
    }];
    
    return dic;
}

// MARK: - Upload

- (void)uploadWithCompletionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler
{
    [self uploadWithOption:AVFileUploadOptionCachingData
                  progress:nil
         completionHandler:completionHandler];
}

- (void)uploadWithProgress:(void (^)(NSInteger))uploadProgressBlock
         completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler
{
    [self uploadWithOption:AVFileUploadOptionCachingData
                  progress:uploadProgressBlock
         completionHandler:completionHandler];
}

- (void)uploadWithOption:(AVFileUploadOption)uploadOption
                progress:(void (^)(NSInteger))uploadProgressBlock
       completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler
{
    if (self.objectId) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (uploadProgressBlock) {
                uploadProgressBlock(100);
            }
            completionHandler(true, nil);
        });
        
        return;
    }
    
    BOOL isUploading = ({
        
        __block BOOL isUploading = false;
        [self internalSyncLock:^{
            if (_uploadOption) {
                isUploading = true;
            } else {
                _uploadOption = @(uploadOption);
            }
        }];
        isUploading;
    });
    
    if (isUploading) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(false, ({
                NSString *reason = @"File is in uploading, Can't do repeated upload operation.";
                LCErrorInternal(reason);
            }));
        });
        
        return;
    }
    
    // _data & _localPath only set in initialization, so no need lock.
    if (self->_data || self->_localPath) {
        
        NSData *data = _data;
        NSString *localPath = _localPath;
        
        void (^progress)(NSInteger) = uploadProgressBlock ? ^(NSInteger number) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                uploadProgressBlock(number);
            });
            
        } : nil;
        
        [self uploadLocalDataWithData:data localPath:localPath progress:progress completionHandler:^(BOOL succeeded, NSError *error) {
            
            AVFileUploadOption uploadOption = ({
                
                __block AVFileUploadOption uploadOption = 0;
                [self internalSyncLock:^{
                    uploadOption = [_uploadOption unsignedIntegerValue];
                    _uploadOption = nil;
                }];
                uploadOption;
            });
            
            if (succeeded && !(uploadOption & AVFileUploadOptionIgnoringCachingData)) {
                
                NSString *persistenceCachePath = ({
                    
                    NSError *error = nil;
                    NSString *path = [self persistentCachePathThrowError:&error];
                    if (error) {
                        AVLoggerError(AVLoggerDomainStorage, @"%@", error);
                    }
                    path;
                });
                
                if (persistenceCachePath) {
                    
                    BOOL isPathCleared = ({
                        
                        NSError *error = nil;
                        if ([NSFileManager.defaultManager fileExistsAtPath:persistenceCachePath]) {
                            [NSFileManager.defaultManager removeItemAtPath:persistenceCachePath error:&error];
                            if (error) {
                                AVLoggerError(AVLoggerDomainStorage, @"%@", error);
                            }
                        }
                        error ? false : true;
                    });
                    
                    
                    if (isPathCleared) {
                        
                        NSError *cachingError = ({
                            
                            NSError *error = nil;
                            if (data) {
                                [data writeToFile:persistenceCachePath atomically:true];
                            }
                            else if (localPath) {
                                [[NSFileManager defaultManager] copyItemAtPath:localPath
                                                                        toPath:persistenceCachePath
                                                                         error:&error];
                            }
                            error;
                        });
                        
                        if (cachingError) {
                            
                            AVLoggerError(AVLoggerDomainStorage, @"%@", cachingError);
                        }
                    }
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(succeeded, error);
            });
        }];
        
        return;
    }
    
    if (self.url) {
        
        [self uploadRemoteURLWithCompletionHandler:^(BOOL succeeded, NSError *error) {
            
            [self internalSyncLock:^{
                _uploadOption = nil;
            }];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (uploadProgressBlock && succeeded) {
                    uploadProgressBlock(100);
                }
                completionHandler(succeeded, error);
            });
        }];
        
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self internalSyncLock:^{
            _uploadOption = nil;
        }];
        
        completionHandler(false, ({
            NSString *reason = @"No data or URL to Upload.";
            LCErrorInternal(reason);
        }));
    });
}

- (void)uploadLocalDataWithData:(NSData *)data
                      localPath:(NSString *)localPath
                       progress:(void (^)(NSInteger number))uploadProgressBlock
              completionHandler:(void (^)(BOOL succeeded, NSError *error))completionHandler
{
    NSMutableDictionary *mutableParameters = ({
        
        __block NSMutableDictionary *mutableDic = nil;
        [self internalSyncLock:^{
            mutableDic = _rawJSONData.mutableCopy;
        }];
        mutableDic[kLCFile_key] = ({
            NSString *key = AVFile_CompactUUID();
            if (_pathExtension) {
                key = [key stringByAppendingPathExtension:_pathExtension];
            }
            key;
        });
        mutableDic;
    });
    
    NSDictionary *parameters = mutableParameters.copy;
    
    [self getFileTokensWithParameters:parameters callback:^(LCFileTokens *fileTokens, NSError *error) {
        
        if (error) {
            completionHandler(false, error);
            return;
        }
        
        NSURLSessionUploadTask *task = ({
            
            NSDictionary<NSString *, NSString *> *uploadingHeaders = self.uploadingHeaders;
            
            void (^progress)(NSProgress *) = uploadProgressBlock ? ^(NSProgress *progress) {
                
                CGFloat completedUnitCount = (CGFloat)progress.completedUnitCount;
                CGFloat totalUnitCount = (CGFloat)progress.totalUnitCount;
                NSInteger number = (NSInteger)((completedUnitCount * 100.0) / totalUnitCount);
                uploadProgressBlock(number);
                
            } : nil;
            
            void(^completionHandler_block)(BOOL success, NSError *error) = ^(BOOL success, NSError *error) {
                
                [self internalSyncLock:^{
                    _uploadTask = nil;
                }];
                
                void(^fileCallback_block)(BOOL succeeded) = ^(BOOL succeeded) {
                    
                    if (fileTokens && fileTokens.token) {
                        [AVPaasClient.sharedInstance postObject:@"fileCallback"
                                                 withParameters:@{ @"token" : fileTokens.token, @"result" : @(succeeded) }
                                                          block:nil];
                    }
                };
                
                if (error) {
                    fileCallback_block(false);
                    completionHandler(false, error);
                    return;
                }
                
                fileCallback_block(true);
                [mutableParameters addEntriesFromDictionary:fileTokens.rawDic];
                [self internalSyncLock:^{
                    _rawJSONData = mutableParameters;
                }];
                
                completionHandler(true, nil);
            };
            
            NSURLSessionUploadTask *task = nil;
            if (data) {
                task = [LCFileTaskManager.sharedInstance uploadTaskWithData:data
                                                                 fileTokens:fileTokens
                                                             fileParameters:parameters
                                                           uploadingHeaders:uploadingHeaders
                                                                   progress:progress
                                                          completionHandler:completionHandler_block];
            } else {
                task = [LCFileTaskManager.sharedInstance uploadTaskWithLocalPath:localPath
                                                                      fileTokens:fileTokens
                                                                  fileParameters:parameters
                                                                uploadingHeaders:uploadingHeaders
                                                                        progress:progress
                                                               completionHandler:completionHandler_block];
            }
            task;
        });
        
        
        if (task) {
            
            [self internalSyncLock:^{
                _uploadTask = task;
            }];
            [task resume];
        }
    }];
}

- (void)uploadRemoteURLWithCompletionHandler:(void (^)(BOOL succeeded, NSError *error))completionHandler
{
    NSMutableDictionary *mutableParameters = ({
        
        __block NSMutableDictionary *mutableDic = nil;
        [self internalSyncLock:^{
            mutableDic = [_rawJSONData mutableCopy];
        }];
        mutableDic;
    });
    
    [AVPaasClient.sharedInstance postObject:@"files" withParameters:mutableParameters.copy block:^(id object, NSError *error) {
        
        if (error) {
            completionHandler(false, error);
            return;
        }
        
        if (![NSDictionary lc__checkingType:object]) {
            
            completionHandler(false, ({
                NSString *reason = @"response invalid.";
                LCErrorInternal(reason);
            }));
            
            return;
        }
        
        [mutableParameters addEntriesFromDictionary:(NSDictionary *)object];
        [self internalSyncLock:^{
            _rawJSONData = mutableParameters;
        }];
        
        completionHandler(true, nil);
    }];
}

- (void)getFileTokensWithParameters:(NSDictionary *)parameters
                           callback:(void (^)(LCFileTokens *fileTokens, NSError *error))callback
{
    [AVPaasClient.sharedInstance postObject:@"fileTokens" withParameters:parameters block:^(id _Nullable object, NSError * _Nullable error) {
        
        if (error) {
            callback(nil, error);
            return;
        }
        
        NSDictionary *dic = (NSDictionary *)object;
        
        if (![NSDictionary lc__checkingType:dic]) {
            callback(nil, ({
                NSString *reason = @"fileTokens response invalid.";
                LCErrorInternal(reason);
            }));
            return;
        }
        
        LCFileTokens *fileTokens = [[LCFileTokens alloc] initWithDic:dic];
        
        callback(fileTokens, nil);
    }];
}

// MARK: - Download

- (void)downloadWithCompletionHandler:(void (^)(NSURL * _Nullable, NSError * _Nullable))completionHandler
{
    [self downloadWithOption:AVFileDownloadOptionCachedData
                    progress:nil
           completionHandler:completionHandler];
}

- (void)downloadWithProgress:(void (^)(NSInteger))downloadProgressBlock
           completionHandler:(void (^)(NSURL * _Nullable, NSError * _Nullable))completionHandler
{
    [self downloadWithOption:AVFileDownloadOptionCachedData
                    progress:downloadProgressBlock
           completionHandler:completionHandler];
}

- (void)downloadWithOption:(AVFileDownloadOption)downloadOption
                  progress:(void (^)(NSInteger))downloadProgressBlock
         completionHandler:(void (^)(NSURL * _Nullable, NSError * _Nullable))completionHandler
{
    NSURLSessionDownloadTask *downloadTask = ({
        
        __block NSURLSessionDownloadTask *task = nil;
        [self internalSyncLock:^{
            task = _downloadTask;
        }];
        task;
    });
    
    if (downloadTask) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil, ({
                NSString *reason = @"File is in downloading, Can't do repeated download operation.";
                LCErrorInternal(reason);
            }));
        });
        
        return;
    }
    
    NSString *URLString = self.url;
    
    if (!URLString || URLString.length == 0) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil, ({
                NSString *reason = @"url is invalid.";
                LCErrorInternal(reason);
            }));
        });
        
        return;
    }
    
    NSError *pathError = nil;
    
    NSString *permanentLocationPath = [self persistentCachePathThrowError:&pathError];
    
    if (pathError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil, pathError);
        });
        return;
    }
    
    if (!(downloadOption & AVFileDownloadOptionIgnoringCachedData)) {
        
        if ([NSFileManager.defaultManager fileExistsAtPath:permanentLocationPath]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (downloadProgressBlock) {
                    downloadProgressBlock(100);
                }
                completionHandler([NSURL fileURLWithPath:permanentLocationPath], nil);
            });
            
            return;
        }
    }
    
    NSURLSessionDownloadTask *task = ({
        
        void(^progress)(NSProgress *) = (downloadProgressBlock ? ^(NSProgress *progress) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                CGFloat completedUnitCount = (CGFloat)progress.completedUnitCount;
                CGFloat totalUnitCount = (CGFloat)progress.totalUnitCount;
                NSInteger number = (NSInteger)((completedUnitCount * 100.0) / totalUnitCount);
                downloadProgressBlock(number);
            });
            
        } : nil);
        
        [LCFileTaskManager.sharedInstance downloadTaskWithURLString:URLString destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
            
            BOOL isPathCleared = ({
                
                BOOL isPathCleared = true;
                if ([NSFileManager.defaultManager fileExistsAtPath:permanentLocationPath]) {
                    NSError *error = nil;
                    [NSFileManager.defaultManager removeItemAtPath:permanentLocationPath
                                                             error:&error];
                    if (error) {
                        AVLoggerError(AVLoggerDomainStorage, @"%@", error);
                        isPathCleared = false;
                    }
                }
                isPathCleared;
            });
            
            return (isPathCleared ? [NSURL fileURLWithPath:permanentLocationPath] : targetPath);
            
        } progress:progress completionHandler:^(NSURL *filePath, NSError *error) {
            
            [self internalSyncLock:^{
                _downloadTask = nil;
            }];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(filePath, error);
            });
        }];
    });
    
    if (task) {
        [self internalSyncLock:^{
            _downloadTask = task;
        }];
        [task resume];
    }
}

// MARK: - Cancel

- (void)cancelUploading
{
    [self internalSyncLock:^{
        if (_uploadTask) {
            [_uploadTask cancel];
            _uploadTask = nil;
        }
        _uploadOption = nil;
    }];
}

- (void)cancelDownloading
{
    [self internalSyncLock:^{
        if (_downloadTask) {
            [_downloadTask cancel];
            _downloadTask = nil;
        }
    }];
}

// MARK: - Persistence Cache

+ (void)setCustomPersistentCacheDirectory:(NSString *)directory
{
    AVFile_CustomPersistentCacheDirectory = directory;
}

- (void)clearPersistentCache
{
    NSString *cachePath = self.persistentCachePath;
    if (!cachePath) {
        return;
    }
    if ([NSFileManager.defaultManager fileExistsAtPath:cachePath]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:cachePath
                                                   error:&error];
        if (error) {
            AVLoggerError(AVLoggerDomainStorage, @"Error: %@", error);
        }
    }
}

+ (void)clearAllPersistentCache
{
    NSString *directoryPath = AVFile_PersistentCacheDirectory();
    if (!directoryPath) {
        return;
    }
    if ([NSFileManager.defaultManager fileExistsAtPath:directoryPath]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:directoryPath
                                                   error:&error];
        if (error) {
            AVLoggerError(AVLoggerDomainStorage, @"Error: %@", error);
        }
    }
}

- (NSString *)persistentCachePath
{
    NSError *error = nil;
    NSString *persistentCachePath = [self persistentCachePathThrowError:&error];
    if (error) {
        AVLoggerError(AVLoggerDomainStorage, @"%@", error);
    }
    return persistentCachePath;
}

- (NSString *)persistentCachePathThrowError:(NSError * __autoreleasing *)error
{
    NSString *objectId = self.objectId;
    
    if (!objectId) {
        if (error) {
            *error = ({
                NSString *reason = @"objectId invalid.";
                LCErrorInternal(reason);
            });
        }
        return nil;
    }
    
    NSString *directory = AVFile_PersistentCacheDirectory();
    
    NSError *createFailError = nil;
    [NSFileManager.defaultManager createDirectoryAtPath:directory
                            withIntermediateDirectories:true
                                             attributes:nil
                                                  error:&createFailError];
    if (createFailError) {
        if (error) {
            *error = createFailError;
        }
        return nil;
    }
    
    NSString *persistentCachePath = ({
        
        NSString *persistentCachePath = [directory stringByAppendingPathComponent:objectId];
        if (_pathExtension) {
            persistentCachePath = [persistentCachePath stringByAppendingPathExtension:_pathExtension];
        }
        persistentCachePath;
    });
    
    return persistentCachePath;
}

// MARK: - Delete

- (void)deleteWithCompletionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler
{
    NSString *objectPath = AVFile_ObjectPath([self objectId]);
    
    if (!objectPath) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`objectId` is invalid.";
                LCErrorInternal(reason);
            });
            
            completionHandler(false, aError);
        });
        
        return;
    }
    
    [[AVPaasClient sharedInstance] deleteObject:objectPath withParameters:nil block:^(id _Nullable object, NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            BOOL succeeded = error ? false : true;
            
            completionHandler(succeeded, error);
        });
    }];
}

+ (void)deleteWithFiles:(NSArray<AVFile *> *)files
      completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler
{
    if (!files || files.count == 0) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            completionHandler(true, nil);
        });
        
        return;
    }
    
    NSMutableArray *requests = [NSMutableArray array];
    
    for (AVFile *file in files) {
        
        NSString *objectId = [file objectId];
        
        if (!objectId || objectId.length == 0) {
            
            continue;
        }
        
        NSString *objectPath = [@"files" stringByAppendingPathComponent:objectId];
        
        NSMutableDictionary *request = [AVPaasClient batchMethod:@"DELETE"
                                                            path:objectPath
                                                            body:nil
                                                      parameters:nil];
        
        [requests addObject:request];
    }
    
    [[AVPaasClient sharedInstance] postBatchObject:requests block:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            BOOL succeeded = error ? false : true;
            
            completionHandler(succeeded, error);
        });
    }];
}

// MARK: - Get

+ (void)getFileWithObjectId:(NSString *)objectId
          completionHandler:(void (^)(AVFile *file, NSError *error))completionHandler
{
    NSString *objectPath = AVFile_ObjectPath(objectId);
    
    if (!objectPath) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *aError = ({
                NSString *reason = @"`objectId` is invalid.";
                LCErrorInternal(reason);
            });
            
            completionHandler(nil, aError);
        });
        
        return;
    }
    
    [[AVPaasClient sharedInstance] getObject:objectPath withParameters:nil block:^(id object, NSError* error) {
        
        if (error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                completionHandler(nil, error);
            });
            
            return;
        }
        
        if (![NSDictionary lc__checkingType:object]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                NSError *aError = ({
                    NSString *reason = @"Get an invalid Object.";
                    LCErrorInternal(reason);
                });
                
                completionHandler(nil, aError);
            });
            
            return;
        }
        
        NSDictionary *dic = (NSDictionary *)object;
        
        AVFile *file = [[AVFile alloc] initWithRawJSONData:dic.mutableCopy];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            completionHandler(file, nil);
        });
    }];
}

// MARK: - Thumbnail

- (NSString *)getThumbnailURLWithScaleToFit:(BOOL)scaleToFit
                                      width:(int)width
                                     height:(int)height
                                    quality:(int)quality
                                     format:(NSString *)format
{
    if (!self.url)
        return nil;

    if (width < 0) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid thumbnail width."];
    }

    if (height < 0) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid thumbnail height."];
    }

    if (quality < 1 || quality > 100) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid quality, valid range is 1 - 100."];
    }

    int mode = scaleToFit ? 2 : 1;

    NSString *url = [NSString stringWithFormat:@"%@?imageView/%d/w/%d/h/%d/q/%d", self.url, mode, width, height, quality];

    format = [format stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([format length]) {
        url = [NSString stringWithFormat:@"%@/format/%@", url, format];
    }

    return url;
}

- (NSString *)getThumbnailURLWithScaleToFit:(BOOL)scaleToFit
                                      width:(int)width
                                     height:(int)height
{
    return [self getThumbnailURLWithScaleToFit:scaleToFit width:width height:height quality:100 format:nil];
}

- (void)getThumbnail:(BOOL)scaleToFit
              width:(int)width
             height:(int)height
          withBlock:(AVImageResultBlock)block
{
    NSString *url = [self getThumbnailURLWithScaleToFit:scaleToFit width:width height:height];
    
    [[LCFileTaskManager sharedInstance] getThumbnailWithURLString:url completionHandler:^(id thumbnail, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            block(thumbnail, error);
        });
    }];
}

// MARK: - Query

+ (AVQuery *)query
{
    return [AVFileQuery query];
}

// MARK: - Code for Compatibility

+ (NSString *)decodingObjectIdFromDic:(NSDictionary *)dic
{
    /* @note For compatibility, should decoding multiple keys ... ... */
    
    NSString *value = [NSString lc__decodingWithKey:kLCFile_objectId fromDic:dic];
    
    if (value) { return value; }
    
    value = [NSString lc__decodingWithKey:kLCFile_objId fromDic:dic];
    
    if (value) { return value; }
    
    value = [NSString lc__decodingWithKey:kLCFile_id fromDic:dic];
    
    return value;
}

+ (NSDictionary *)decodingMetaDataFromDic:(NSDictionary *)dic
{
    /* @note For compatibility, should decoding multiple keys ... ... */
    
    NSDictionary *value = [NSDictionary lc__decodingWithKey:kLCFile_metaData fromDic:dic];
    
    if (value) { return value; }
    
    value = [NSDictionary lc__decodingWithKey:kLCFile_metadata fromDic:dic];
    
    return value;
}

// MARK: - Deprecated

- (void)saveInBackgroundWithBlock:(void (^)(BOOL, NSError * _Nullable))block
{
    [self uploadWithCompletionHandler:block];
}

- (void)saveInBackgroundWithBlock:(void (^)(BOOL, NSError * _Nullable))block
                    progressBlock:(void (^)(NSInteger))progressBlock
{
    [self uploadWithProgress:progressBlock completionHandler:block];
}

- (void)getDataInBackgroundWithBlock:(void (^)(NSData * _Nullable, NSError * _Nullable))block
{
    [self downloadWithCompletionHandler:^(NSURL * _Nullable filePath, NSError * _Nullable error) {
        
        if (error) {
            
            block(nil, error);
            
            return;
        }
        
        NSError *err = nil;
        
        NSData *data = [NSData dataWithContentsOfURL:filePath options:NSDataReadingMappedIfSafe error:&err];
        
        if (err) {
            
            block(nil, err);
            
            return;
        }
        
        block(data, nil);
    }];
}

- (void)getDataInBackgroundWithBlock:(void (^)(NSData * _Nullable, NSError * _Nullable))block
                       progressBlock:(void (^)(NSInteger))progressBlock
{
    [self downloadWithProgress:progressBlock completionHandler:^(NSURL * _Nullable filePath, NSError * _Nullable error) {
        
        if (error) {
            
            block(nil, error);
            
            return;
        }
        
        NSError *err = nil;
        
        NSData *data = [NSData dataWithContentsOfURL:filePath options:NSDataReadingMappedIfSafe error:&err];
        
        if (err) {
            
            block(nil, err);
            
            return;
        }
        
        block(data, nil);
    }];
}

@end

@implementation LCFileTokens

@synthesize provider = _provider;
@synthesize objectId = _objectId;
@synthesize token = _token;
@synthesize bucket = _bucket;
@synthesize url = _url;
@synthesize uploadUrl = _uploadUrl;

- (instancetype)initWithDic:(NSDictionary *)dic
{
    self = [super init];
    
    if (self) {
        
        _rawDic = dic;
    }
    
    return self;
}

- (NSString *)provider
{
    if (_provider) {
        
        return _provider;
        
    } else {
        
        _provider = [NSString lc__decodingWithKey:@"provider" fromDic:_rawDic];
        
        return _provider;
    }
}

- (NSString *)objectId
{
    if (_objectId) {
        
        return _objectId;
        
    } else {
        
        _objectId = [NSString lc__decodingWithKey:@"objectId" fromDic:_rawDic];
        
        return _objectId;
    }
}

- (NSString *)token
{
    if (_token) {
        
        return _token;
        
    } else {
        
        _token = [NSString lc__decodingWithKey:@"token" fromDic:_rawDic];
        
        return _token;
    }
}

- (NSString *)bucket
{
    /* unused, maybe can delete. */
    
    if (_bucket) {
        
        return _bucket;
        
    } else {
        
        _bucket = [NSString lc__decodingWithKey:@"bucket" fromDic:_rawDic];
        
        return _bucket;
    }
}

- (NSString *)url
{
    if (_url) {
        
        return _url;
        
    } else {
        
        _url = [NSString lc__decodingWithKey:@"url" fromDic:_rawDic];
        
        return _url;
    }
}

- (NSString *)uploadUrl
{
    if (_uploadUrl) {
        
        return _uploadUrl;
        
    } else {
        
        _uploadUrl = [NSString lc__decodingWithKey:@"upload_url" fromDic:_rawDic];
        
        return _uploadUrl;
    }
}

@end
