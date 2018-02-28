//
//  LCFileTaskManager.h
//  IconMan
//
//  Created by Zhu Zeng on 3/16/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LCFileTokens;

@interface LCFileTaskManager : NSObject

+ (instancetype)sharedInstance;

- (NSURLSessionUploadTask *)uploadTaskWithData:(NSData *)data
                                    fileTokens:(LCFileTokens *)fileTokens
                                fileParameters:(NSDictionary *)fileParameters
                              uploadingHeaders:(NSDictionary<NSString *, NSString *> *)uploadingHeaders
                                      progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                             completionHandler:(void (^)(BOOL success, NSError *error))uploadCompletionHandler;

- (NSURLSessionUploadTask *)uploadTaskWithLocalPath:(NSString *)localPath
                                         fileTokens:(LCFileTokens *)fileTokens
                                     fileParameters:(NSDictionary *)fileParameters
                                   uploadingHeaders:(NSDictionary<NSString *, NSString *> *)uploadingHeaders
                                           progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                  completionHandler:(void (^)(BOOL success, NSError *error))uploadCompletionHandler;

- (NSURLSessionDownloadTask *)downloadTaskWithURLString:(NSString *)URLString
                                            destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                                               progress:(void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                      completionHandler:(void (^)(NSURL *filePath, NSError *error))downloadCompletionHandler;

- (void)getThumbnailWithURLString:(NSString *)URLString
                completionHandler:(void (^)(id thumbnail, NSError *error))thumbnailCompletionHandler;

@end
