//
// AVAmazonS3Client.m
//
// Copyright (c) 2012 Mattt Thompson (http://mattt.me/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <CommonCrypto/CommonHMAC.h>
#import "AVAmazonS3Client.h"
#import "AVXMLRequestOperation.h"
#import "AVFileHTTPRequestOperation.h"
#import "LCURLConnection.h"

NSString * const kAVAmazonS3BaseURLString = @"http://s3.amazonaws.com";
NSString * const kAVAmazonS3BucketBaseURLFormatString = @"http://%@.s3.amazonaws.com";

static NSData * AVHMACSHA1EncodedDataFromStringWithKey(NSString *string, NSString *key) {
    NSData *data = [string dataUsingEncoding:NSASCIIStringEncoding];
    CCHmacContext context;
    const char *keyCString = [key cStringUsingEncoding:NSASCIIStringEncoding];
    
    CCHmacInit(&context, kCCHmacAlgSHA1, keyCString, strlen(keyCString));
    CCHmacUpdate(&context, [data bytes], [data length]);
    
    unsigned char digestRaw[CC_SHA1_DIGEST_LENGTH];
    NSInteger digestLength = CC_SHA1_DIGEST_LENGTH;
    
    CCHmacFinal(&context, digestRaw);
    
    return [NSData dataWithBytes:digestRaw length:digestLength];
}

static NSString *AVRFC822FormatStringFromDate(NSDate *date) {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    [dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss z"];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    
    return [dateFormatter stringFromDate:date];
}

NSString * AVBase64EncodedStringFromData(NSData *data) {
    NSUInteger length = [data length];
    NSMutableData *mutableData = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    
    uint8_t *input = (uint8_t *)[data bytes];
    uint8_t *output = (uint8_t *)[mutableData mutableBytes];
    
    for (NSUInteger i = 0; i < length; i += 3) {
        NSUInteger value = 0;
        for (NSUInteger j = i; j < (i + 3); j++) {
            value <<= 8;
            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }
        
        static uint8_t const kAVBase64EncodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        
        NSUInteger idx = (i / 3) * 4;
        output[idx + 0] = kAVBase64EncodingTable[(value >> 18) & 0x3F];
        output[idx + 1] = kAVBase64EncodingTable[(value >> 12) & 0x3F];
        output[idx + 2] = (i + 1) < length ? kAVBase64EncodingTable[(value >> 6)  & 0x3F] : '=';
        output[idx + 3] = (i + 2) < length ? kAVBase64EncodingTable[(value >> 0)  & 0x3F] : '=';
    }
    
    return [[NSString alloc] initWithData:mutableData encoding:NSASCIIStringEncoding];
}

#pragma mark -

@interface AVAmazonS3Client ()

- (void)setObjectWithMethod:(NSString *)method
                       file:(NSString *)filePath
            destinationPath:(NSString *)destinationPath
                 parameters:(NSDictionary *)parameters
                   progress:(void (^)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite))progressBlock
                    success:(void (^)(id responseObject))success
                    failure:(void (^)(NSError *error))failure;
@end

@implementation AVAmazonS3Client
@synthesize baseURL = _s3_baseURL;
@synthesize bucket = _bucket;
@synthesize accessKey = _accessKey;
@synthesize secret = _secret;

- (id)initWithAccessKeyID:(NSString *)accessKey
                   secret:(NSString *)secret
{
    self = [self initWithBaseURL:[NSURL URLWithString:kAVAmazonS3BaseURLString]];
    if (!self) {
        return nil;
    }

    self.accessKey = accessKey;
    self.secret = secret;

    return self;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }

    [self registerHTTPOperationClass:[AVXMLRequestOperation class]];

    return self;
}

- (NSURL *)baseURL {
    if (_s3_baseURL && self.bucket) {
        return [NSURL URLWithString:[NSString stringWithFormat:kAVAmazonS3BucketBaseURLFormatString, self.bucket]];
    }

    return _s3_baseURL;
}

- (void)setBucket:(NSString *)bucket {
    [self willChangeValueForKey:@"baseURL"];
    [self willChangeValueForKey:@"bucket"];
    _bucket = bucket;
    [self didChangeValueForKey:@"bucket"];
    [self didChangeValueForKey:@"baseURL"];
}

#pragma mark -

- (void)enqueueS3RequestOperationWithMethod:(NSString *)method
                                       path:(NSString *)path
                                 parameters:(NSDictionary *)parameters
                                    success:(void (^)(id responseObject))success
                                    failure:(void (^)(NSError *error))failure
{
    NSURLRequest *request = [self requestWithMethod:method path:path parameters:parameters];
    AVHTTPRequestOperation *requestOperation = [self HTTPRequestOperationWithRequest:request success:^(AVHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            success(responseObject);
        }
    } failure:^(AVHTTPRequestOperation *operation, NSError *error) {
        if (failure) {
            failure(error);
        }
    }];

    [self enqueueHTTPRequestOperation:requestOperation];
}

- (void)authorizeRequest:(NSMutableURLRequest *)request withPath:(NSString *)path contentType:(NSString *)contentType dateString:(NSString *)dateString {
    if (self.accessKey && self.secret) {
        NSString *canonicalizedResource = [request.URL path];
        NSString *stringToSign = [NSString stringWithFormat:@"%@\n\n%@\n%@\n%@\n%@",
                                  request.HTTPMethod,
                                  contentType,
                                  dateString,
                                  @"x-amz-acl:public-read",
                                  canonicalizedResource];
        NSData *hmac = AVHMACSHA1EncodedDataFromStringWithKey(stringToSign, self.secret);
        NSString *signature = AVBase64EncodedStringFromData(hmac);
        
        [request setValue:dateString forHTTPHeaderField:@"Date"];
        [request setValue:[NSString stringWithFormat:@"AWS %@:%@", self.accessKey, signature] forHTTPHeaderField:@"Authorization"];
    }
}

#pragma mark Service Operations

- (void)getServiceWithSuccess:(void (^)(id responseObject))success
                      failure:(void (^)(NSError *error))failure
{
    [self enqueueS3RequestOperationWithMethod:@"GET" path:@"/" parameters:nil success:success failure:failure];
}

#pragma mark Bucket Operations

- (void)getBucket:(NSString *)bucket
          success:(void (^)(id responseObject))success
          failure:(void (^)(NSError *error))failure
{
    [self enqueueS3RequestOperationWithMethod:@"GET" path:bucket parameters:nil success:success failure:failure];
}

- (void)putBucket:(NSString *)bucket
       parameters:(NSDictionary *)parameters
          success:(void (^)(id responseObject))success
          failure:(void (^)(NSError *error))failure
{
    [self enqueueS3RequestOperationWithMethod:@"PUT" path:bucket parameters:parameters success:success failure:failure];

}

- (void)deleteBucket:(NSString *)bucket
             success:(void (^)(id responseObject))success
             failure:(void (^)(NSError *error))failure
{
    [self enqueueS3RequestOperationWithMethod:@"DELETE" path:bucket parameters:nil success:success failure:failure];
}

#pragma mark Object Operations

- (void)headObjectWithPath:(NSString *)path
                   success:(void (^)(id responseObject))success
                   failure:(void (^)(NSError *error))failure
{
    [self enqueueS3RequestOperationWithMethod:@"HEAD" path:path parameters:nil success:success failure:failure];
}

- (void)getObjectWithPath:(NSString *)path
                 progress:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))progress
                  success:(void (^)(id responseObject, NSData *responseData))success
                  failure:(void (^)(NSError *error))failure
{
    NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters:nil];
    AVHTTPRequestOperation *requestOperation = [self HTTPRequestOperationWithRequest:request success:^(AVHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            success(responseObject, operation.responseData);
        }
    } failure:^(AVHTTPRequestOperation *operation, NSError *error) {
        if (failure) {
            failure(error);
        }
    }];

    [requestOperation setDownloadProgressBlock:^(AVURLConnectionOperation *operation, NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        progress(bytesRead, totalBytesRead, totalBytesExpectedToRead);
    }];

    [self enqueueHTTPRequestOperation:requestOperation];
}

- (void)getObjectWithPath:(NSString *)path
             outputStream:(NSOutputStream *)outputStream
                 progress:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))progress
                  success:(void (^)(id responseObject))success
                  failure:(void (^)(NSError *error))failure
{
    NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters:nil];
    AVHTTPRequestOperation *requestOperation = [self HTTPRequestOperationWithRequest:request success:^(AVHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            success(responseObject);
        }
    } failure:^(AVHTTPRequestOperation *operation, NSError *error) {
        if (failure) {
            failure(error);
        }
    }];

    [requestOperation setDownloadProgressBlock:^(AVURLConnectionOperation *operation, NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        progress(bytesRead, totalBytesRead, totalBytesExpectedToRead);
    }];
    [requestOperation setOutputStream:outputStream];

    [self enqueueHTTPRequestOperation:requestOperation];
}

- (void)postObjectWithFile:(NSString *)path
           destinationPath:(NSString *)destinationPath
                parameters:(NSDictionary *)parameters
                  progress:(void (^)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
                   success:(void (^)(id responseObject))success
                   failure:(void (^)(NSError *error))failure
{
    [self setObjectWithMethod:@"POST" file:path destinationPath:destinationPath parameters:parameters progress:progress success:success failure:failure];
}

- (void)putObjectWithFile:(NSString *)path
          destinationPath:(NSString *)destinationPath
               parameters:(NSDictionary *)parameters
                 progress:(void (^)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
                  success:(void (^)(id responseObject))success
                  failure:(void (^)(NSError *error))failure
{
    [self setObjectWithMethod:@"PUT" file:path destinationPath:destinationPath parameters:parameters progress:progress success:success failure:failure];
}

- (void)deleteObjectWithPath:(NSString *)path
                     success:(void (^)(id responseObject))success
                     failure:(void (^)(NSError *error))failure
{
    [self enqueueS3RequestOperationWithMethod:@"DELETE" path:path parameters:nil success:success failure:failure];
}

- (void)setObjectWithMethod:(NSString *)method
                       file:(NSString *)filePath
            destinationPath:(NSString *)destinationPath
                 parameters:(NSDictionary *)parameters
                   progress:(void (^)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
                    success:(void (^)(id responseObject))success
                    failure:(void (^)(NSError *error))failure
{
    NSError *error = nil;
    NSData  *data  = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];

    if (data) {
        NSMutableURLRequest *request = [self multipartFormRequestWithMethod:method path:destinationPath parameters:parameters constructingBodyWithBlock:nil];

        NSString *contentType = @"application/octet-stream";
        NSString *dateString  = AVRFC822FormatStringFromDate([NSDate date]);

        [self authorizeRequest:request withPath:destinationPath contentType:contentType dateString:dateString];

        [request setValue:@"public-read" forHTTPHeaderField:@"x-amz-acl"];
        [request setValue:contentType forHTTPHeaderField:@"Content-Type"];

        [request setHTTPBody:data];

        AVHTTPRequestOperation *requestOperation = [self HTTPRequestOperationWithRequest:request success:^(AVHTTPRequestOperation *operation, id responseObject) {
            if (success) {
                success(responseObject);
            }
        } failure:^(AVHTTPRequestOperation *operation, NSError *error) {
            if (failure) {
                failure(error);
            }
        }];

        [requestOperation setUploadProgressBlock:^(AVURLConnectionOperation *operation, NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            progress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
        }];
        
        // for cancel with local path
        if ([requestOperation isKindOfClass:[AVFileHTTPRequestOperation class]]) {
            [(AVFileHTTPRequestOperation *)requestOperation setLocalPath:filePath];
        }

        [self enqueueHTTPRequestOperation:requestOperation];
    } else if (error) {
        AVLoggerError(AVLoggerDomainDefault, @"Can not create file data: %@.", error.localizedDescription);
    } else {
        AVLoggerError(AVLoggerDomainDefault, @"Can not create file data.");
    }
}

#pragma mark - AVHTTPClient

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                      path:(NSString *)path
                                parameters:(NSDictionary *)parameters
{
    NSMutableURLRequest *request = [super requestWithMethod:method path:path parameters:parameters];
    return request;
}

@end

