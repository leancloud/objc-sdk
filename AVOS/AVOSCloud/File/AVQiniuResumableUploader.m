//
//  AVQiniuResumableUploader.m
//  AVOS
//
//  Created by Tang Tianyong on 8/26/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import "AVQiniuResumableUploader.h"
#import "AVFile_Internal.h"
#import "AVErrorUtils.h"
#import "AVFileHash.h"
#import "AVUtils.h"
#import "GTMStringEncoding.h"
#import "AVPaasClient.h"
#import "AVFileAccessor.h"
#import "LCNetworking.h"

static const uint64_t kChunkSize       = 256 * 1024;
static const uint64_t kBlockSize       = 4 * 1024 * 1024;
static const int      kMaxRetriedTimes = 3;

static dispatch_queue_t completionQueue = nil;

@interface AVQiniuResumableUploader ()

@property (nonatomic, strong) AVFile                 *file;
@property (nonatomic, strong) NSDictionary           *info;
@property (nonatomic,   copy) NSString               *key;
@property (nonatomic,   copy) NSString               *token;
@property (nonatomic,   copy) NSString               *host;
@property (nonatomic, strong) AVFileBreakpoint       *breakpoint;
@property (nonatomic,   copy) AVFileBreakpointBlock   breakpointDidUpdateBlock;
@property (nonatomic,   copy) AVProgressBlock         progressBlock;
@property (nonatomic,   copy) AVFileCancellationBlock cancellationBlock;
@property (nonatomic,   copy) AVBooleanResultBlock    completionBlock;

@property (nonatomic,   copy) NSString               *path;
@property (nonatomic, strong) NSDictionary           *headers;
@property (nonatomic, assign) uint64_t                size;
@property (nonatomic,   copy) NSString               *checksum;
@property (nonatomic, strong) NSMutableArray         *contexts;
@property (nonatomic, strong) AVFileAccessor         *fileAccessor;

@property (nonatomic, assign) NSInteger               lastPercentage;

@end

@implementation AVQiniuResumableUploader

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        completionQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_CONCURRENT);
    });
}

- (instancetype)initWithFile:(AVFile *)file
                        info:(NSDictionary *)info
                         key:(NSString *)key
                       token:(NSString *)token
                        host:(NSString *)host
                  breakpoint:(AVFileBreakpoint *)breakpoint
         breakpointDidUpdate:(AVFileBreakpointBlock)breakpointDidUpdateBlock
                    progress:(AVProgressBlock)progressBlock
                cancellation:(AVFileCancellationBlock)cancellationBlock
                  completion:(AVBooleanResultBlock)completionBlock
{
    self = [super init];

    if (self) {
        _file                     = file;
        _info                     = info;
        _key                      = [key copy];
        _token                    = [token copy];
        _host                     = [host copy];
        _breakpoint               = breakpoint;
        _breakpointDidUpdateBlock = [breakpointDidUpdateBlock copy];
        _progressBlock            = [progressBlock copy];
        _cancellationBlock        = [cancellationBlock copy];
        _completionBlock          = [completionBlock copy];
        _path                     = [file.path copy];

        _headers = @{
            @"Authorization" : [NSString stringWithFormat:@"UpToken %@", token],
            @"Content-Type"  : @"application/octet-stream"
        };
    }

    return self;
}

- (NSError *)doInitialize {
    if (!_path ||
        ![[NSFileManager defaultManager] fileExistsAtPath:_path])
        return [AVErrorUtils errorWithCode:NSNotFound errorText:@"File not found for resumable upload."];

    NSError *error = nil;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_path error:&error];

    if (error)
        return error;

    _size         = [fileAttributes fileSize];
    _checksum     = [[AVFileHash sha512HashOfFileAtPath:_path] copy];
    _contexts     = [[NSMutableArray alloc] initWithCapacity:(_size + kBlockSize - 1) / kBlockSize];
    _fileAccessor = [[AVFileAccessor alloc] initWithPath:_path];

    return nil;
}

- (uint64_t)recoveryBreakpoint {
    do {
        uint64_t size     = self.breakpoint.size;
        uint64_t offset   = self.breakpoint.offset;
        NSArray *contexts = self.breakpoint.contexts;

        if (!size || !offset || offset > size || size != self.size || !contexts)
            break;

        NSString *checksum = self.breakpoint.checksum;

        if (!checksum ||
            ![checksum isEqualToString:self.checksum])
            break;

        _contexts = [[NSMutableArray alloc] initWithArray:contexts copyItems:YES];

        return offset;
    } while(0);

    return 0;
}

- (NSURLRequest *)requestWithURL:(NSURL *)URL
                          method:(NSString *)method
                         headers:(NSDictionary *)headers
                      parameters:(NSDictionary *)parameters
                            body:(NSData *)body
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];

    [request setHTTPMethod:method];

    if (headers)
        [request setAllHTTPHeaderFields:headers];

    if (parameters)
        [request setValuesForKeysWithDictionary:parameters];

    [request setHTTPBody:body];

    return request;
}

- (void)makeFileWithCompletion:(void(^)(NSHTTPURLResponse *response, NSDictionary *object, NSError *error))completionBlock {
    NSMutableArray *paths = [NSMutableArray array];

    /* Add root path, aka the mkfile. */
    [paths addObject:[NSString stringWithFormat:@"/mkfile/%llu", self.size]];

    AVGTMStringEncoding *encoding = [AVGTMStringEncoding rfc4648Base64WebsafeStringEncoding];
    [paths addObject:[NSString stringWithFormat:@"mimeType/%@", [encoding encodeString:self.file.mimeType]]];

    if (self.key.length > 0) {
        [paths addObject:[NSString stringWithFormat:@"key/%@", [encoding encodeString:self.key]]];
    }

    NSString *path = [paths componentsJoinedByString:@"/"];
    NSData   *body = [[self.contexts componentsJoinedByString:@","] dataUsingEncoding:NSUTF8StringEncoding];

    [self requestPath:path method:@"POST" body:body progress:nil completion:completionBlock];
}

- (void)makeBlockForOffset:(uint64_t)offset
                 blockSize:(uint64_t)blockSize
                 chunkSize:(uint64_t)chunkSize
                  progress:(void(^)(NSProgress *uploadProgress))progressBlock
                  complete:(void(^)(NSHTTPURLResponse *response, NSDictionary *object, NSError *error))completeBlock
{
    NSString *path = [NSString stringWithFormat:@"/mkblk/%llu", blockSize];
    NSData   *data = [self.fileAccessor dataForOffset:offset size:chunkSize];
    [self requestPath:path method:@"POST" body:data progress:progressBlock completion:completeBlock];
}

- (void)putChunkForOffset:(uint64_t)offset
                chunkSize:(uint64_t)chunkSize
                  context:(NSString *)context
                 progress:(void(^)(NSProgress *uploadProgress))progressBlock
               completion:(void(^)(NSHTTPURLResponse *response, NSDictionary *object, NSError *error))completionBlock
{
    uint64_t chunkOffset = offset % kBlockSize;
    NSString *path = [NSString stringWithFormat:@"/bput/%@/%llu", context, chunkOffset];
    NSData   *data = [self.fileAccessor dataForOffset:offset size:chunkSize];
    [self requestPath:path method:@"POST" body:data progress:progressBlock completion:completionBlock];
}

- (NSString *)normalizePath:(NSString *)path {
    if ([path hasPrefix:@"/"])
        return path;

    return [@"/" stringByAppendingString:path];
}

- (void)requestPath:(NSString *)path
             method:(NSString *)method
               body:(NSData *)body
           progress:(void(^)(NSProgress *uploadProgress))progressBlock
         completion:(void(^)(NSHTTPURLResponse *response, NSDictionary *object, NSError *error))completionBlock
{
    NSURLComponents *components = [NSURLComponents componentsWithString:self.host];

    if (path)
        components.path = [self normalizePath:path];

    NSURL *URL = [NSURL URLWithString:components.string];

    NSURLRequest *request = [self requestWithURL:URL
                                          method:method
                                         headers:self.headers
                                      parameters:nil
                                            body:body];

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    LCURLSessionManager *manager = [[LCURLSessionManager alloc] initWithSessionConfiguration:configuration];
    manager.completionQueue = completionQueue;

    NSURLSessionDataTask *dataTask = [manager dataTaskWithRequest:request
                                                   uploadProgress:progressBlock
                                                 downloadProgress:nil
                                                completionHandler:
    ^(NSURLResponse *response, id _Nullable responseObject,  NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

        if (error) {
            completionBlock(httpResponse, nil, error);
        } else if (httpResponse.statusCode == 200 && responseObject) {
            completionBlock(httpResponse, responseObject, nil);
        } else {
            NSDictionary *userInfo = @{
                NSLocalizedFailureReasonErrorKey: @"Invalid status code or empty response object."
            };
            NSError *error = [NSError errorWithDomain:@"qiniu.com" code:httpResponse.statusCode userInfo:userInfo];
            completionBlock(httpResponse, nil, error);
        }
    }];

    [dataTask resume];
}

- (uint64_t)calculateChunkSize:(uint64_t)offset {
    uint64_t left = self.size - offset;
    return left < kChunkSize ? left : kChunkSize;
}

- (uint64_t)calculateBlockSize:(uint64_t)offset {
    uint64_t left = self.size - offset;
    return left < kBlockSize ? left : kBlockSize;
}

- (void)nextTask:(uint64_t)offset retriedTimes:(int)retriedTimes {
    if (self.cancellationBlock && self.cancellationBlock())
        return; /* If cancelled, do nothing. */

    if (offset == self.size) {
        /* All data did upload, let's make a file. */
        [self makeFileWithCompletion:^(NSHTTPURLResponse *response, NSDictionary *object, NSError *error) {
            if (!error) {
                [AVUtils callProgressBlock:self.progressBlock percent:100];
                [AVUtils callBooleanResultBlock:self.completionBlock error:nil];
            } else if (retriedTimes >= kMaxRetriedTimes) {
                [AVUtils callBooleanResultBlock:self.completionBlock error:error];
            } else {
                [self nextTask:offset retriedTimes:retriedTimes + 1];
            }
        }];
    } else {
        // Continue to put chunk.
        uint64_t chunkSize = [self calculateChunkSize:offset];

        id progressBlock = ^(NSProgress *uploadProgress) {
            double chunkPercentage = uploadProgress.fractionCompleted;
            double totalPercentage = (offset + chunkPercentage * chunkSize) / (double)self.size;

            NSInteger roundPercentage = (NSInteger)(totalPercentage * 100);

            if (self.progressBlock && roundPercentage > self.lastPercentage) {
                self.lastPercentage = roundPercentage;
                self.progressBlock(roundPercentage);
            }
        };

        id completionHandler = ^(NSHTTPURLResponse *response, NSDictionary *object, NSError *error) {
            if (!error) {
                NSString *context = object[@"ctx"];
                self.contexts[offset / kBlockSize] = context;

                uint64_t nextOffset = offset + chunkSize;

                if (self.breakpointDidUpdateBlock) {
                    AVFileBreakpoint *breakpoint = [[AVFileBreakpoint alloc] init];

                    breakpoint.info     = self.info;
                    breakpoint.size     = self.size;
                    breakpoint.offset   = nextOffset;
                    breakpoint.checksum = self.checksum;
                    breakpoint.contexts = self.contexts;

                    self.breakpointDidUpdateBlock(breakpoint);
                }

                [self nextTask:nextOffset retriedTimes:retriedTimes];
            } else if (response.statusCode == 701) {
                [self nextTask:(offset / kBlockSize) * kBlockSize retriedTimes:0];
            } else if (retriedTimes < kMaxRetriedTimes) {
                [self nextTask:offset retriedTimes:retriedTimes];
            } else {
                self.completionBlock(NO, error);
            }
        };

        if (offset % kBlockSize == 0) {
            // A block did fill up, make a block.
            uint64_t blockSize = [self calculateBlockSize:offset];

            [self makeBlockForOffset:offset
                           blockSize:blockSize
                           chunkSize:chunkSize
                            progress:progressBlock
                            complete:completionHandler];
        } else {
            NSString *context = self.contexts[offset / kBlockSize];

            [self putChunkForOffset:offset
                          chunkSize:chunkSize
                            context:context
                           progress:progressBlock
                         completion:completionHandler];
        }
    }
}

- (void)upload {
    NSError *error = [self doInitialize];

    if (error) {
        [AVUtils callBooleanResultBlock:_completionBlock error:error];
    } else {
        uint64_t offset = [self recoveryBreakpoint];
        [self nextTask:offset retriedTimes:0];
    }
}

@end
