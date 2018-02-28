//
//  LCFileTaskManager.m
//  IconMan
//
//  Created by Zhu Zeng on 3/16/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "LCFileTaskManager.h"
#import "AVErrorUtils.h"
#import "AVUtils.h"
#import "AVFile_Internal.h"
#import "AVPaasClient.h"
#import "AVObjectUtils.h"
#import "LCNetworking.h"

static NSString * const kLCFileTokensProvider_qiniu = @"qiniu";
static NSString * const kLCFileTokensProvider_qcloud = @"qcloud";
static NSString * const kLCFileTokensProvider_s3 = @"s3";

@implementation LCFileTaskManager {
    
    LCURLSessionManager *_URLSessionManager;
    
    LCHTTPRequestSerializer *_requestSerializer;
    
    LCURLSessionManager *_thumbnailSessionManager;
}

+ (instancetype)sharedInstance
{
    static LCFileTaskManager *instance = nil;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        instance = [[LCFileTaskManager alloc] init];
    });
    
    return instance;
}

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        dispatch_group_t group = dispatch_group_create();
        
        _URLSessionManager = ({
            LCURLSessionManager *manager = [[LCURLSessionManager alloc] init];
            manager.responseSerializer = [LCHTTPResponseSerializer serializer];
            manager.completionGroup = group;
            manager.completionQueue = dispatch_queue_create("queue.serial.LCFileTaskManager", DISPATCH_QUEUE_CONCURRENT);
            manager;
        });
        
        _requestSerializer = [LCHTTPRequestSerializer serializer];
        
        _thumbnailSessionManager = ({
            LCURLSessionManager *manager = [[LCURLSessionManager alloc] init];
            manager.responseSerializer = [LCImageResponseSerializer serializer];
            manager.completionGroup = group;
            manager.completionQueue = dispatch_queue_create("queue.concurrent.LCFileTaskManager.thumbnail", DISPATCH_QUEUE_CONCURRENT);
            manager;
        });
    }
    
    return self;
}

// MARK: - Upload

- (NSURLSessionUploadTask *)uploadTaskWithData:(NSData *)data
                                    fileTokens:(LCFileTokens *)fileTokens
                                fileParameters:(NSDictionary *)fileParameters
                              uploadingHeaders:(NSDictionary<NSString *, NSString *> *)uploadingHeaders
                                      progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                             completionHandler:(void (^)(BOOL success, NSError *error))uploadCompletionHandler
{
    NSString *file_key = [NSString lc__decodingWithKey:kLCFile_key fromDic:fileParameters];
    NSString *file_mimeType = [NSString lc__decodingWithKey:kLCFile_mime_type fromDic:fileParameters];
    NSString *file_token = fileTokens.token;
    NSString *file_uploadUrl = fileTokens.uploadUrl;
    
    if ([fileTokens.provider isEqualToString:kLCFileTokensProvider_qiniu]) {
        
        NSError *requestError = nil;
        
        NSURLRequest *request = [self requestForQiniuWithData:data
                                                          key:file_key
                                                     mimeType:file_mimeType
                                                        token:file_token
                                                    uploadUrl:file_uploadUrl
                                                        error:&requestError];
        
        if (requestError) {
            
            uploadCompletionHandler(false, requestError);
            
            return nil;
        }
        
        NSURLSessionUploadTask *task = [self uploadToQiniuWithRequest:request
                                                             progress:uploadProgressBlock
                                              uploadCompletionHandler:uploadCompletionHandler];
        
        return task;
    }
    else if ([fileTokens.provider isEqualToString:kLCFileTokensProvider_qcloud]) {
        
        NSError *requestError = nil;
        
        NSURLRequest *request = [self requestForQCloudWithData:data
                                                           key:file_key
                                                      mimeType:file_mimeType
                                                         token:file_token
                                                     uploadUrl:file_uploadUrl
                                                         error:&requestError];
        
        if (requestError) {
            
            uploadCompletionHandler(false, requestError);
            
            return nil;
        }
        
        NSURLSessionUploadTask *task = [self uploadToQCloudWithRequest:request
                                                              progress:uploadProgressBlock
                                               uploadCompletionHandler:uploadCompletionHandler];
        
        return task;
    }
    else if ([fileTokens.provider isEqualToString:kLCFileTokensProvider_s3]) {
        
        NSError *requestError = nil;
        
        NSURLRequest *request = [self requestForS3WithData:data
                                                  mimeType:file_mimeType
                                                 uploadUrl:file_uploadUrl
                                          uploadingHeaders:uploadingHeaders
                                                     error:&requestError];
        
        if (requestError) {
            
            uploadCompletionHandler(false, requestError);
            
            return nil;
        }
        
        NSURLSessionUploadTask *task = [self uploadToS3WithRequest:request
                                                              data:data
                                                          progress:uploadProgressBlock
                                           uploadCompletionHandler:uploadCompletionHandler];
        
        return task;
    }
    else {
        
        NSError *aError = ({
            NSString *reason = [NSString stringWithFormat:@"Provider: (%@) can't be matched.", fileTokens.provider];
            NSDictionary *userInfo = @{ @"reason" : reason };
            [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                code:0
                            userInfo:userInfo];
        });
        
        uploadCompletionHandler(false, aError);
        
        return nil;
    }
}

- (NSURLSessionUploadTask *)uploadTaskWithLocalPath:(NSString *)localPath
                                         fileTokens:(LCFileTokens *)fileTokens
                                     fileParameters:(NSDictionary *)fileParameters
                                   uploadingHeaders:(NSDictionary<NSString *, NSString *> *)uploadingHeaders
                                           progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                  completionHandler:(void (^)(BOOL success, NSError *error))uploadCompletionHandler
{
    NSString *file_key = [NSString lc__decodingWithKey:kLCFile_key fromDic:fileParameters];
    NSString *file_mimeType = [NSString lc__decodingWithKey:kLCFile_mime_type fromDic:fileParameters];
    NSString *file_token = fileTokens.token;
    NSString *file_uploadUrl = fileTokens.uploadUrl;
    
    if ([fileTokens.provider isEqualToString:kLCFileTokensProvider_qiniu]) {
        
        NSError *requestError = nil;
        
        NSURLRequest *request = [self requestForQiniuWithFileURL:[NSURL fileURLWithPath:localPath]
                                                             key:file_key
                                                        mimeType:file_mimeType
                                                           token:file_token
                                                       uploadUrl:file_uploadUrl
                                                           error:&requestError];
        
        if (requestError) {
            
            uploadCompletionHandler(false, requestError);
            
            return nil;
        }
        
        NSURLSessionUploadTask *task = [self uploadToQiniuWithRequest:request
                                                             progress:uploadProgressBlock
                                              uploadCompletionHandler:uploadCompletionHandler];
        
        return task;
    }
    else if ([fileTokens.provider isEqualToString:kLCFileTokensProvider_qcloud]) {
        
        NSError *requestError = nil;
        
        NSURLRequest *request = [self requestForQCloudWithFileURL:[NSURL fileURLWithPath:localPath]
                                                              key:file_key
                                                         mimeType:file_mimeType
                                                            token:file_token
                                                        uploadUrl:file_uploadUrl
                                                            error:&requestError];
        
        if (requestError) {
            
            uploadCompletionHandler(false, requestError);
            
            return nil;
        }
        
        NSURLSessionUploadTask *task = [self uploadToQCloudWithRequest:request
                                                              progress:uploadProgressBlock
                                               uploadCompletionHandler:uploadCompletionHandler];
        
        return task;
    }
    else if ([fileTokens.provider isEqualToString:kLCFileTokensProvider_s3]) {
        
        NSURL *fileURL = [NSURL fileURLWithPath:localPath];
        
        NSError *requestError = nil;
        
        NSURLRequest *request = [self requestForS3WithFileURL:fileURL
                                                     mimeType:file_mimeType
                                                    uploadUrl:file_uploadUrl
                                             uploadingHeaders:uploadingHeaders
                                                        error:&requestError];
        
        if (requestError) {
            
            uploadCompletionHandler(false, requestError);
            
            return nil;
        }
        
        NSURLSessionUploadTask *task = [self uploadToS3WithRequest:request
                                                           fileURL:fileURL
                                                          progress:uploadProgressBlock
                                           uploadCompletionHandler:uploadCompletionHandler];
        
        return task;
    }
    else {
        
        NSError *aError = ({
            NSString *reason = [NSString stringWithFormat:@"Provider: (%@) can't be matched.", fileTokens.provider];
            NSDictionary *userInfo = @{ @"reason" : reason };
            [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                code:0
                            userInfo:userInfo];
        });
        
        uploadCompletionHandler(false, aError);
        
        return nil;
    }
}

// MARK: - Upload to QCloud

- (NSURLRequest *)requestForQCloudWithData:(NSData *)data
                                       key:(NSString *)key
                                  mimeType:(NSString *)mimeType
                                     token:(NSString *)token
                                 uploadUrl:(NSString *)uploadUrl
                                     error:(NSError * __autoreleasing *)error
{
    NSError *error1 = nil;
    
    NSMutableURLRequest *request = [_requestSerializer multipartFormRequestWithMethod:@"POST" URLString:uploadUrl parameters:nil constructingBodyWithBlock:^(id<LCMultipartFormData>  _Nonnull formData) {
        
        [formData appendPartWithFileData:data
                                    name:@"filecontent"
                                fileName:key
                                mimeType:mimeType];
        
        [formData appendPartWithFormData:[@"upload" dataUsingEncoding:NSUTF8StringEncoding]
                                    name:@"op"];
        
    } error:&error1];
    
    if (error1) {
        
        if (error) { *error = error1; }
        
        return nil;
    }
    
    [request setValue:[NSURL URLWithString:uploadUrl].host forHTTPHeaderField:@"Host"];
    [request setValue:token forHTTPHeaderField:@"Authorization"];
    
    return request;
}

- (NSURLRequest *)requestForQCloudWithFileURL:(NSURL *)fileURL
                                          key:(NSString *)key
                                     mimeType:(NSString *)mimeType
                                        token:(NSString *)token
                                    uploadUrl:(NSString *)uploadUrl
                                        error:(NSError * __autoreleasing *)error
{
    __block NSError *error1 = nil;
    
    NSError *error2 = nil;
    
    NSMutableURLRequest *request = [_requestSerializer multipartFormRequestWithMethod:@"POST" URLString:uploadUrl parameters:nil constructingBodyWithBlock:^(id<LCMultipartFormData>  _Nonnull formData) {
        
        [formData appendPartWithFileURL:fileURL
                                   name:@"filecontent"
                               fileName:key
                               mimeType:mimeType
                                  error:&error1];
        
        [formData appendPartWithFormData:[@"upload" dataUsingEncoding:NSUTF8StringEncoding]
                                    name:@"op"];
        
    } error:&error2];
    
    if (error1) {
        
        if (error) { *error = error1; }
        
        return nil;
    }
    
    if (error2) {
        
        if (error) { *error = error2; }
        
        return nil;
    }
    
    [request setValue:[NSURL URLWithString:uploadUrl].host forHTTPHeaderField:@"Host"];
    [request setValue:token forHTTPHeaderField:@"Authorization"];
    
    return request;
}

- (NSURLSessionUploadTask *)uploadToQCloudWithRequest:(NSURLRequest *)request
                                             progress:(void (^)(NSProgress *progress))uploadProgressBlock
                              uploadCompletionHandler:(void (^)(BOOL success, NSError *uploadError))uploadCompletionHandler
{
    NSURLSessionUploadTask *task = [_URLSessionManager uploadTaskWithStreamedRequest:request progress:uploadProgressBlock completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        
        if (error) {
            
            uploadCompletionHandler(false, error);
            
        } else {
            
            LCJSONResponseSerializer *responseSerializer = [LCJSONResponseSerializer serializer];
            responseSerializer.removesKeysWithNullValues = true;
            
            NSError *serializingError = nil;
            
            NSDictionary *dic = [responseSerializer responseObjectForResponse:response
                                                                         data:responseObject
                                                                        error:&serializingError];
            
            if (serializingError) {
                
                uploadCompletionHandler(false, serializingError);
                
                return;
            }
            
            if (![NSDictionary lc__checkingType:dic] ||
                [dic[@"code"] integerValue] != 0) {
                
                NSError *aError = ({
                    NSString *reason = [NSString stringWithFormat:@"%@", dic];
                    NSDictionary *userInfo = @{ @"reason" : reason };
                    [NSError errorWithDomain:@"LeanCloudErrorDomain"
                                        code:0
                                    userInfo:userInfo];
                });
                
                uploadCompletionHandler(false, aError);
                
                return;
            }
            
            uploadCompletionHandler(true, nil);
        }
    }];
    
    return task;
}

// MARK: - Upload to Qiniu

- (NSURLRequest *)requestForQiniuWithData:(NSData *)data
                                      key:(NSString *)key
                                 mimeType:(NSString *)mimeType
                                    token:(NSString *)token
                                uploadUrl:(NSString *)uploadUrl
                                    error:(NSError * __autoreleasing *)error
{
    NSError *error1 = nil;
    
    NSMutableURLRequest *request = [_requestSerializer multipartFormRequestWithMethod:@"POST" URLString:uploadUrl parameters:nil constructingBodyWithBlock:^(id<LCMultipartFormData>  _Nonnull formData) {
        
        [formData appendPartWithFileData:data
                                    name:@"file"
                                fileName:key
                                mimeType:mimeType];
        
        [formData appendPartWithFormData:[key dataUsingEncoding:NSUTF8StringEncoding]
                                    name:@"key"];
        
        [formData appendPartWithFormData:[token dataUsingEncoding:NSUTF8StringEncoding]
                                    name:@"token"];
        
    } error:&error1];
    
    if (error1) {
        
        if (error) { *error = error1; }
        
        return nil;
    }
    
    [request setValue:[NSURL URLWithString:uploadUrl].host forHTTPHeaderField:@"Host"];
    
    return request;
}

- (NSURLRequest *)requestForQiniuWithFileURL:(NSURL *)fileURL
                                         key:(NSString *)key
                                    mimeType:(NSString *)mimeType
                                       token:(NSString *)token
                                   uploadUrl:(NSString *)uploadUrl
                                       error:(NSError * __autoreleasing *)error
{
    __block NSError *error1 = nil;
    
    NSError *error2 = nil;
    
    NSMutableURLRequest *request = [_requestSerializer multipartFormRequestWithMethod:@"POST" URLString:uploadUrl parameters:nil constructingBodyWithBlock:^(id<LCMultipartFormData>  _Nonnull formData) {
        
        [formData appendPartWithFileURL:fileURL
                                   name:@"file"
                               fileName:key
                               mimeType:mimeType
                                  error:&error1];
        
        [formData appendPartWithFormData:[key dataUsingEncoding:NSUTF8StringEncoding]
                                    name:@"key"];
        
        [formData appendPartWithFormData:[token dataUsingEncoding:NSUTF8StringEncoding]
                                    name:@"token"];
        
    } error:&error2];
    
    if (error1) {
        
        if (error) { *error = error1; }
        
        return nil;
    }
    
    if (error2) {
        
        if (error) { *error = error2; }
        
        return nil;
    }
    
    [request setValue:[NSURL URLWithString:uploadUrl].host forHTTPHeaderField:@"Host"];
    
    return request;
}

- (NSURLSessionUploadTask *)uploadToQiniuWithRequest:(NSURLRequest *)request
                                            progress:(void (^)(NSProgress *progress))uploadProgressBlock
                             uploadCompletionHandler:(void (^)(BOOL success, NSError *uploadError))uploadCompletionHandler
{
    NSURLSessionUploadTask *task = [_URLSessionManager uploadTaskWithStreamedRequest:request progress:uploadProgressBlock completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        
        if (error) {
            
            uploadCompletionHandler(false, error);
            
            return;
        }
        
        uploadCompletionHandler(true, nil);
    }];
    
    return task;
}

// MARK: - Upload to S3

- (NSURLRequest *)requestForS3WithData:(NSData *)data
                              mimeType:(NSString *)mimeType
                             uploadUrl:(NSString *)uploadUrl
                      uploadingHeaders:(NSDictionary<NSString *, NSString *> *)uploadingHeaders
                                 error:(NSError * __autoreleasing *)error
{
    NSError *error1 = nil;
    
    NSMutableURLRequest *request = [_requestSerializer requestWithMethod:@"PUT"
                                                               URLString:uploadUrl
                                                              parameters:nil
                                                                   error:&error1];
    
    if (error1) {
        
        if (error) { *error = error1; }
        
        return nil;
    }
    
    [request setValue:[NSURL URLWithString:uploadUrl].host forHTTPHeaderField:@"Host"];
    
    [request setValue:[@(data.length) stringValue] forHTTPHeaderField:@"Content-Length"];
    [request setValue:mimeType forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:@"public, max-age=31536000" forHTTPHeaderField:@"Cache-Control"];
    
    if (uploadingHeaders) {
        
        for (NSString *key in uploadingHeaders.allKeys) {
            
            [request setValue:uploadingHeaders[key] forHTTPHeaderField:key];
        }
    }
    
    return request;
}

- (NSURLRequest *)requestForS3WithFileURL:(NSURL *)fileURL
                                 mimeType:(NSString *)mimeType
                                uploadUrl:(NSString *)uploadUrl
                         uploadingHeaders:(NSDictionary<NSString *, NSString *> *)uploadingHeaders
                                    error:(NSError * __autoreleasing *)error
{
    NSError *error1 = nil;
    
    NSMutableURLRequest *request = [_requestSerializer requestWithMethod:@"PUT"
                                                               URLString:uploadUrl
                                                              parameters:nil
                                                                   error:&error1];
    
    if (error1) {
        
        if (error) { *error = error1; }
        
        return nil;
    }
    
    NSDictionary *fileAttributes = [NSFileManager.defaultManager attributesOfItemAtPath:fileURL.path
                                                                                  error:&error1];
    
    if (error1) {
        
        if (error) { *error = error1; }
        
        return nil;
    }
    
    [request setValue:[NSURL URLWithString:uploadUrl].host forHTTPHeaderField:@"Host"];
    
    [request setValue:[fileAttributes[NSFileSize] stringValue] forHTTPHeaderField:@"Content-Length"];
    [request setValue:mimeType forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:@"public, max-age=31536000" forHTTPHeaderField:@"Cache-Control"];
    
    if (uploadingHeaders) {
        
        for (NSString *key in uploadingHeaders.allKeys) {
            
            [request setValue:uploadingHeaders[key] forHTTPHeaderField:key];
        }
    }
    
    return request;
}

- (NSURLSessionUploadTask *)uploadToS3WithRequest:(NSURLRequest *)request
                                             data:(NSData *)data
                                         progress:(void (^)(NSProgress *progress))uploadProgressBlock
                          uploadCompletionHandler:(void (^)(BOOL success, NSError *uploadError))uploadCompletionHandler
{
    NSURLSessionUploadTask *task = [_URLSessionManager uploadTaskWithRequest:request fromData:data progress:uploadProgressBlock completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        
        if (error) {
            
            uploadCompletionHandler(false, error);
            
            return;
        }
        
        uploadCompletionHandler(true, nil);
    }];
    
    return task;
}

- (NSURLSessionUploadTask *)uploadToS3WithRequest:(NSURLRequest *)request
                                          fileURL:(NSURL *)fileURL
                                         progress:(void (^)(NSProgress *progress))uploadProgressBlock
                          uploadCompletionHandler:(void (^)(BOOL success, NSError *uploadError))uploadCompletionHandler
{
    NSURLSessionUploadTask *task = [_URLSessionManager uploadTaskWithRequest:request fromFile:fileURL progress:uploadProgressBlock completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        
        if (error) {
            
            uploadCompletionHandler(false, error);
            
            return;
        }
        
        uploadCompletionHandler(true, nil);
    }];
    
    return task;
}

// MARK: - Download

- (NSURLSessionDownloadTask *)downloadTaskWithURLString:(NSString *)URLString
                                            destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                                               progress:(void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                      completionHandler:(void (^)(NSURL *filePath, NSError *error))downloadCompletionHandler
{
    NSError *error = nil;
    
    NSMutableURLRequest *request = [_requestSerializer requestWithMethod:@"GET"
                                                               URLString:URLString
                                                              parameters:nil
                                                                   error:&error];
    
    if (error) {
        
        downloadCompletionHandler(nil, error);
        
        return nil;
    }
    
    NSURLSessionDownloadTask *task = [_URLSessionManager downloadTaskWithRequest:request progress:downloadProgressBlock destination:destination completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        
        if (error) {
            
            downloadCompletionHandler(nil, error);
            
            return;
        }
        
        downloadCompletionHandler(filePath, nil);
    }];
    
    return task;
}

// MARK: - Thumbnail

- (void)getThumbnailWithURLString:(NSString *)URLString
                completionHandler:(void (^)(id thumbnail, NSError *error))thumbnailCompletionHandler
{
    NSError *error = nil;
    
    NSURLRequest *request = [_requestSerializer requestWithMethod:@"GET"
                                                        URLString:URLString
                                                       parameters:nil
                                                            error:&error];
    
    if (error) {
        
        thumbnailCompletionHandler(nil, error);
        
        return;
    }
    
    NSURLSessionDataTask *task = [_thumbnailSessionManager dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        
        if (error) {
            
            thumbnailCompletionHandler(nil, error);
            
            return;
        }
        
        thumbnailCompletionHandler(responseObject, nil);
    }];
    
    [task resume];
}

@end
