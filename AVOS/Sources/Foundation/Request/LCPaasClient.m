//
//  LCPaasClient.m
//  paas
//
//  Created by Zhu Zeng on 2/25/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import "LCPaasClient.h"
#import "LCNetworking.h"
#import "LCUtils_Internal.h"
#import "LCUser_Internal.h"
#import "LCObject_Internal.h"
#import "LCRole_Internal.h"
#import "LCACL_Internal.h"
#import "LCCacheManager.h"
#import "LCErrorUtils.h"
#import "LCPersistenceUtils.h"
#import "LCScheduler.h"
#import "LCObjectUtils.h"
#import "LCRouter_Internal.h"
#import "LCApplication_Internal.h"
#import "LCLogger.h"
#import "LCHelpers.h"

NSString * const LCHeaderFieldNameId = @"X-LC-Id";
NSString * const LCHeaderFieldNameKey = @"X-LC-Key";
NSString * const LCHeaderFieldNameSign = @"X-LC-Sign";
NSString * const LCHeaderFieldNameSession = @"X-LC-Session";
NSString * const LCHeaderFieldNameProduction = @"X-LC-Prod";

#define LC_REST_REQUEST_LOG_FORMAT \
@"\n------ BEGIN LeanCloud REST Request -------\n" \
@"path: %@\n" \
@"curl: %@\n" \
@"------ END --------------------------------"

#define LC_REST_RESPONSE_LOG_FORMAT \
@"\n------ BEGIN LeanCloud REST Response ------\n" \
@"path: %@\n" \
@"cost: %.3fms\n" \
@"response: %@\n" \
@"------ END --------------------------------"

@implementation NSMutableString (LCURLRequestFormatter)

- (void)appendCommandLineArgument:(NSString *)arg {
    [self appendFormat:@" %@", [arg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
}

@end

@implementation NSURLRequest (LCCurl)

- (NSString *)_lc_cURLCommand
{
    NSMutableString *command = [NSMutableString stringWithString:@"curl -v \\\n"];
    
    [command appendCommandLineArgument:[NSString stringWithFormat:@"-X %@ \\\n", [self HTTPMethod]]];
    
    NSString *acceptEncodingHeader = [[self allHTTPHeaderFields] valueForKey:@"Accept-Encoding"];
    if (acceptEncodingHeader && [acceptEncodingHeader rangeOfString:@"gzip"].location != NSNotFound) {
        [command appendCommandLineArgument:@"--compressed \\\n"];
    }
    
    if ([self URL]) {
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[self URL]];
        for (NSHTTPCookie *cookie in cookies) {
            [command appendCommandLineArgument:[NSString stringWithFormat:@"--cookie \"%@=%@\" \\\n", [cookie name], [cookie value]]];
        }
    }
    
    NSMutableDictionary<NSString *, NSString *> *headers = [[self allHTTPHeaderFields] mutableCopy];
    
    for (NSString * field in headers) {
        [command appendCommandLineArgument:[NSString stringWithFormat:@"-H %@ \\\n", [NSString stringWithFormat:@"'%@: %@'", field, [[self valueForHTTPHeaderField:field] stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"]]]];
    }
    
    if ([self URL].query.length > 0) {
        NSString *query = [self URL].query;
        NSArray *components = [query componentsSeparatedByString:@"&"];
        for (NSString *component in components) {
            [command appendCommandLineArgument:[NSString stringWithFormat:@"--data-urlencode \'%@\' \\\n", component.stringByRemovingPercentEncoding]];
        }
    }
    
    NSString *basicUrl;
    NSString *absoluteString = [[self URL] absoluteString];
    NSRange range = [absoluteString rangeOfString:@"?"];
    if (range.location != NSNotFound) {
        basicUrl = [absoluteString substringToIndex:range.location];
    } else {
        basicUrl = absoluteString;
    }
    
    NSData *data = [self HTTPBody];
    if ([data length] > 0) {
        NSString *HTTPBodyString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [command appendCommandLineArgument:[NSString stringWithFormat:@"-d '%@' \\\n", HTTPBodyString]];
    }
    
    [command appendCommandLineArgument:[NSString stringWithFormat:@"\"%@\"", basicUrl]];
    
    return [NSString stringWithString:command];
}

@end

@implementation LCPaasClient

+ (LCPaasClient *)sharedInstance {
    static LCPaasClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _productionMode = true;
        _timeoutInterval = 60.0;
        _requestTable = [NSMapTable strongToWeakObjectsMapTable];
        _runningArchivedRequests = [[NSMutableSet alloc] init];
        _completionQueue = dispatch_queue_create([NSString stringWithFormat:
                                                  @"LC.Objc.%@.%@",
                                                  NSStringFromClass([self class]),
                                                  keyPath(self, completionQueue)].UTF8String,
                                                 DISPATCH_QUEUE_CONCURRENT);
        _sessionManager = ({
            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
            LCURLSessionManager *manager = [[LCURLSessionManager alloc] initWithSessionConfiguration:configuration];
            manager.completionQueue = _completionQueue;
            LCJSONResponseSerializer *responseSerializer = (LCJSONResponseSerializer *)manager.responseSerializer;
            responseSerializer.removesKeysWithNullValues = true;
            manager;
        });
        _lock = [[NSLock alloc] init];
        [LCScheduler sharedInstance];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_sessionManager invalidateSessionCancelingTasks:YES];
}

-(void)setIsLastModifyEnabled:(BOOL)isLastModifyEnabled{
    if (_isLastModifyEnabled==isLastModifyEnabled) {
        return;
    }
    _isLastModifyEnabled=isLastModifyEnabled;
    if (_isLastModifyEnabled) {
        //FIXME: 永久化
        self.lastModify=[[NSMutableDictionary alloc] init];
        
    } else {
        self.lastModify=nil;
    }
}

-(void)clearLastModifyCache {
    if (self.lastModify.count) {
        for (NSString *key in self.lastModify) {
            [[LCCacheManager sharedInstance] clearCacheForMD5Key:key];
        }
        
        [self.lastModify removeAllObjects];
    }
}

- (NSString *)signatureHeaderFieldValue {
    NSString *key = [self.application keyThrowException];
    NSString *timestamp = [NSString stringWithFormat:@"%.0f", 1000 * [[NSDate date] timeIntervalSince1970]];
    NSString *sign = [[[NSString stringWithFormat:@"%@%@", timestamp, key] _lc_MD5String] lowercaseString];
    NSString *headerValue = [NSString stringWithFormat:@"%@,%@", sign, timestamp];
    return headerValue;
}

+(NSMutableDictionary *)batchMethod:(NSString *)method
                               path:(NSString *)path
                               body:(NSDictionary *)body
                         parameters:(NSDictionary *)parameters
{
    NSMutableDictionary * result = [[NSMutableDictionary alloc] init];
    NSString *batchPath = [[LCRouter sharedInstance] batchPathForPath:path];
    
    [result setObject:method forKey:@"method"];
    [result setObject:batchPath forKey:@"path"];
    if (body) {
        [result setObject:body forKey:@"body"];
    }
    if (parameters) {
        [result setObject:parameters forKey:@"params"];
    }
    
    return result;
}

+(void)updateBatchMethod:(NSString *)method
                    path:(NSString *)path
                    dict:(NSMutableDictionary *)dict
{
    NSString * myPath = [NSString stringWithFormat:@"/%@/%@", [LCPaasClient sharedInstance].apiVersion, path];
    
    [dict setObject:method forKey:@"method"];
    [dict setObject:myPath forKey:@"path"];
}

- (NSMutableURLRequest *)requestWithPath:(NSString *)path
                                  method:(NSString *)method
                                 headers:(NSDictionary *)headers
                              parameters:(id)parameters
{
    NSURL *URL = [NSURL URLWithString:path];
    
    if (!URL.scheme.length) {
        NSString *URLString = [[LCRouter sharedInstance] appURLForPath:path appID:[LCApplication getApplicationId]];
        URL = [NSURL URLWithString:URLString];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    NSString *appID = [self.application identifierThrowException];
    NSString *appKey = [self.application keyThrowException];
    
    [request setHTTPMethod:method];
    [request setTimeoutInterval:self.timeoutInterval];
    [request setValue:appID forHTTPHeaderField:LCHeaderFieldNameId];
    if ([appKey hasSuffix:@",master"]) {
        [request setValue:appKey forHTTPHeaderField:LCHeaderFieldNameKey];
    } else {
        [request setValue:[self signatureHeaderFieldValue] forHTTPHeaderField:LCHeaderFieldNameSign];
    }
    [request setValue:self.productionMode ? @"1": @"0" forHTTPHeaderField:LCHeaderFieldNameProduction];
    [request setValue:USER_AGENT forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    
    NSString *sessionToken = self.currentUser.sessionToken;
    if (sessionToken) {
        [request setValue:sessionToken forHTTPHeaderField:LCHeaderFieldNameSession];
    }
    
    NSError *error = nil;
    LCJSONRequestSerializer *serializer = [[LCJSONRequestSerializer alloc] init];
    request = [[serializer requestBySerializingRequest:request withParameters:parameters error:&error] mutableCopy];
    
    if (headers) {
        for (NSString *key in headers) {
            [request setValue:headers[key] forHTTPHeaderField:key];
        }
    }
    
    return request;
}

- (void)getObject:(NSString *)path withParameters:(NSDictionary *)parameters block:(LCIdResultBlock)block {
    [self getObject:path withParameters:parameters block:block wait:false];
}

- (void)getObject:(NSString *)path withParameters:(NSDictionary *)parameters block:(LCIdResultBlock)block wait:(BOOL)wait {
    [self getObjectFromNetworkWithPath:path withParameters:parameters policy:kLCCachePolicyIgnoreCache block:block wait:wait];
}

- (void)getObjectFromNetworkWithPath:(NSString *)path
                      withParameters:(NSDictionary *)parameters
                              policy:(LCCachePolicy)policy
                               block:(LCIdResultBlock)block
                                wait:(BOOL)wait
{
    NSURLRequest *request = [self requestWithPath:path method:@"GET" headers:nil parameters:parameters];
    
    if (parameters && request.URL.absoluteString.length > 4096) {
        /* If GET request too heavy, wrap it into a POST request and ignore cache policy. */
        NSDictionary *request = [LCPaasClient batchMethod:@"GET" path:path body:nil parameters:parameters];
        [self postBatchObject:@[request] headerMap:nil block:^(NSArray * _Nullable objects, NSError * _Nullable error) {
            if (error) {
                block(nil, error);
            } else {
                block(objects.firstObject, nil);
            }
        } wait:wait];
    } else {
        BOOL needCache = (policy != kLCCachePolicyIgnoreCache);
        [self performRequest:request saveResult:needCache block:block wait:wait];
    }
}

- (void)getObjectFromNetworkWithPath:(NSString *)path withParameters:(NSDictionary *)parameters policy:(LCCachePolicy)policy block:(LCIdResultBlock)block {
    [self getObjectFromNetworkWithPath:path withParameters:parameters policy:policy block:block wait:false];
}

- (void)getObject:(NSString *)path withParameters:(NSDictionary *)parameters policy:(LCCachePolicy)policy maxCacheAge:(NSTimeInterval)maxCacheAge block:(LCIdResultBlock)block {
    
    NSString *key = [self absoluteStringFromPath:path parameters:parameters];
    
    switch (policy) {
        case kLCCachePolicyIgnoreCache:
        {
            [self getObjectFromNetworkWithPath:path withParameters:parameters policy:policy block:block];
        }
            break;
        case kLCCachePolicyCacheOnly:
        {
            [[LCCacheManager sharedInstance] getWithKey:key maxCacheAge:maxCacheAge block:block];
        }
            break;
        case kLCCachePolicyNetworkOnly:
        {
            [self getObjectFromNetworkWithPath:path withParameters:parameters policy:policy block:^(id object, NSError *error) {
                block(object, error);
            }];
        }
            break;
        case kLCCachePolicyCacheElseNetwork:
        {
            [[LCCacheManager sharedInstance] getWithKey:key maxCacheAge:maxCacheAge block:^(id object, NSError *error) {
                if (error) {
                    [self getObjectFromNetworkWithPath:path withParameters:parameters policy:policy block:block];
                } else {
                    block(object, error);
                }
            }];
        }
            break;
        case kLCCachePolicyNetworkElseCache:
        {
            [self getObjectFromNetworkWithPath:path withParameters:parameters policy:policy block:^(id object, NSError *error) {
                if (error) {
                    [[LCCacheManager sharedInstance] getWithKey:key maxCacheAge:maxCacheAge block:block];
                } else {
                    block(object, error);
                }
            }];
        }
            break;
        case kLCCachePolicyCacheThenNetwork:
        {
            [[LCCacheManager sharedInstance] getWithKey:key maxCacheAge:maxCacheAge block:^(id object, NSError *error) {
                block(object, error);
                [self getObjectFromNetworkWithPath:path withParameters:parameters policy:policy block:block];
            }];
        }
            break;
        default:
        {
            abort();
        }
            break;
    }
}

- (NSString *)JSONStringFromDictionary:(NSDictionary *)dictionary {
    if (!dictionary)
        return nil;
    
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
    
    if (!error && data) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    } else {
        return nil;
    }
}

- (void)putObject:(NSString *)path
   withParameters:(NSDictionary *)parameters
     sessionToken:(NSString *)sessionToken
            block:(LCIdResultBlock)block
{
    NSMutableURLRequest *request = [self requestWithPath:path method:@"PUT" headers:nil parameters:parameters];
    
    if (sessionToken) {
        [request setValue:sessionToken forHTTPHeaderField:LCHeaderFieldNameSession];
    }
    
    [self performRequest:request block:block];
}

- (void)postBatchObject:(NSArray *)parameterArray block:(LCArrayResultBlock)block {
    [self postBatchObject:parameterArray headerMap:nil block:block wait:false];
}

- (void)postBatchObject:(NSArray *)requests headerMap:(NSDictionary *)headerMap block:(LCArrayResultBlock)block wait:(BOOL)wait
{
    NSString *path = [LCObjectUtils batchPath];
    NSDictionary *parameters = @{@"requests": requests ?: @[]};
    NSMutableURLRequest *request = [self requestWithPath:path method:@"POST" headers:headerMap parameters:parameters];
    
    [self performRequest:request saveResult:false block:^(NSArray *objects, NSError *error) {
        if (objects.count != requests.count) {
            if (error) {
                block(nil, error);
            } else {
                block(nil, LCErrorInternalServer(@"The batch count of server response is not equal to request count"));
            }
        } else {
            NSMutableArray *results = [NSMutableArray array];
            for (NSDictionary *object in objects) {
                id success = object[@"success"];
                if (success) {
                    [results addObject:success];
                    continue;
                }
                id error = object[@"error"];
                if (error) {
                    [results addObject:error];
                    continue;
                }
            }
            block(results, nil);
        }
    } wait:wait];
}

-(void)postBatchSaveObject:(NSArray *)requests headerMap:(NSDictionary *)headerMap eventually:(BOOL)isEventually block:(LCIdResultBlock)block {
    NSString *path = [LCObjectUtils batchSavePath];
    NSDictionary *parameters = @{@"requests": requests};
    NSMutableURLRequest *request = [self requestWithPath:path method:@"POST" headers:headerMap parameters:parameters];
    
    if (isEventually) {
        NSString *filePath = [self archiveRequest:request];
        [self handleArchivedRequestAtPath:filePath block:block];
    } else {
        [self performRequest:request block:block];
    }
}

- (void)postObject:(NSString *)path withParameters:(id)parameters block:(LCIdResultBlock)block {
    [self postObject:path withParameters:parameters eventually:NO block:block];
}

- (void)postObject:(NSString *)path withParameters:(id)parameters eventually:(BOOL)isEventually block:(LCIdResultBlock)block {
    NSMutableURLRequest *request = [self requestWithPath:path method:@"POST" headers:nil parameters:parameters];
    if (isEventually) {
        NSString *filePath = [self archiveRequest:request];
        [self handleArchivedRequestAtPath:filePath block:block];
    } else {
        [self performRequest:request block:block];
    }
}

-(void)deleteObject:(NSString *)path
     withParameters:(NSDictionary *)parameters
              block:(LCIdResultBlock)block
{
    [self deleteObject:path withParameters:parameters eventually:NO block:block];
}

- (void)deleteObject:(NSString *)path withParameters:(NSDictionary *)parameters eventually:(BOOL)isEventually block:(LCIdResultBlock)block {
    NSMutableURLRequest *request = [self requestWithPath:path method:@"DELETE" headers:nil parameters:parameters];
    
    if (isEventually) {
        NSString *filePath = [self archiveRequest:request];
        [self handleArchivedRequestAtPath:filePath block:block];
    } else {
        [self performRequest:request block:block];
    }
}

#pragma mark - The final method for network

- (void)performRequest:(NSURLRequest *)request block:(LCIdResultBlock)block {
    [self performRequest:request saveResult:false block:block wait:false];
}

- (void)performRequest:(NSURLRequest *)request saveResult:(BOOL)saveResult block:(LCIdResultBlock)block wait:(BOOL)wait {
    [self performRequest:request saveResult:saveResult block:block retryTimes:0 wait:wait];
}

- (void)performRequest:(NSURLRequest *)request
            saveResult:(BOOL)saveResult
                 block:(LCIdResultBlock)block
            retryTimes:(NSInteger)retryTimes
                  wait:(BOOL)wait
{
    NSURL *URL = request.URL;
    NSString *URLString = URL.absoluteString;
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    
    if (self.isLastModifyEnabled && [request.HTTPMethod isEqualToString:@"GET"]) {
        NSString *modifiedSince = self.lastModify[[URLString _lc_MD5String]];
        if (modifiedSince && [[LCCacheManager sharedInstance] hasCacheForKey:URLString]) {
            [mutableRequest setValue:modifiedSince forHTTPHeaderField:@"If-Modified-Since"];
        }
    }
    
    [self performRequest:mutableRequest
                 success:
     ^(NSHTTPURLResponse *response, id responseObject) {
        if (block) {
            block(responseObject, nil);
        }
        if (self.isLastModifyEnabled && [request.HTTPMethod isEqualToString:@"GET"]) {
            NSString *URLMD5 = [URLString _lc_MD5String];
            NSString *lastModified = [response.allHeaderFields objectForKey:@"Last-Modified"];
            if (lastModified && ![self.lastModify[URLMD5] isEqualToString:lastModified]) {
                [[LCCacheManager sharedInstance] saveJSON:responseObject forKey:URLString];
                [self.lastModify setObject:lastModified forKey:URLMD5];
            }
        } else if (saveResult) {
            [[LCCacheManager sharedInstance] saveJSON:responseObject forKey:URLString];
        }
    }
                 failure:
     ^(NSHTTPURLResponse *response, id responseObject, NSError *error) {
        NSInteger statusCode = response.statusCode;
        if (statusCode == 304) {
            // 304 is not error
            [[LCCacheManager sharedInstance] getWithKey:URLString maxCacheAge:3600 * 24 * 30 block:^(id object, NSError *error) {
                if (error) {
                    if (retryTimes < 3) {
                        [self.lastModify removeObjectForKey:[URLString _lc_MD5String]];
                        [[LCCacheManager sharedInstance] clearCacheForKey:URLString];
                        [mutableRequest setValue:@"" forHTTPHeaderField:@"If-Modified-Since"];
                        [self performRequest:mutableRequest saveResult:saveResult block:block retryTimes:retryTimes + 1 wait:wait];
                    } else {
                        if (block)
                            block(object, error);
                    }
                } else {
                    if (block)
                        block(object, error);
                }
            }];
        } else {
            if (block) {
                block(responseObject, error);
            }
        }
    } wait:wait];
}

- (void)performRequest:(NSURLRequest *)request
               success:(void (^)(NSHTTPURLResponse *response, id responseObject))successBlock
               failure:(void (^)(NSHTTPURLResponse *response, id responseObject, NSError *error))failureBlock
{
    [self performRequest:request
                 success:successBlock
                 failure:failureBlock
                    wait:NO];
}

- (void)performRequest:(NSURLRequest *)request
               success:(void (^)(NSHTTPURLResponse *response, id responseObject))successBlock
               failure:(void (^)(NSHTTPURLResponse *response, id responseObject, NSError *error))failureBlock
                  wait:(BOOL)wait
{
    NSString *path = request.URL.path;
    LCLoggerDebug(LCLoggerDomainNetwork, LC_REST_REQUEST_LOG_FORMAT, path, [request _lc_cURLCommand]);
    dispatch_semaphore_t semaphore;
    if (wait) {
        semaphore = dispatch_semaphore_create(0);
    }
    NSDate *operationEnqueueDate = [NSDate date];
    NSURLSessionDataTask *dataTask = [self.sessionManager dataTaskWithRequest:request
                                                            completionHandler:
                                      ^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
        if (error) {
            NSError *callbackError = nil;
            if ([NSDictionary _lc_isTypeOf:responseObject]) {
                NSMutableDictionary *userInfo = ((NSDictionary *)responseObject).mutableCopy;
                // decoding 'code'
                NSNumber *code = [NSNumber _lc_decoding:userInfo key:@"code"];
                if (code != nil) {
                    // decoding 'error'
                    NSString *reason = [NSString _lc_decoding:userInfo key:@"error"];
                    [userInfo removeObjectsForKeys:@[@"code", @"error"]];
                    /* for compatibility */
                    id data = error.userInfo[LCNetworkingOperationFailingURLResponseDataErrorKey];
                    if (data) {
                        userInfo[LCNetworkingOperationFailingURLResponseDataErrorKey] = data;
                    }
                    userInfo[kLeanCloudRESTAPIResponseError] = responseObject;
                    callbackError = LCError(code.integerValue, reason, userInfo);
                } else {
                    callbackError = error;
                }
            } else {
                callbackError = error;
            }
            NSTimeInterval costTime = -([operationEnqueueDate timeIntervalSinceNow] * 1000);
            LCLoggerDebug(LCLoggerDomainNetwork, LC_REST_RESPONSE_LOG_FORMAT, path, costTime, callbackError);
            if (failureBlock) {
                failureBlock(HTTPResponse, responseObject, callbackError);
            }
        } else {
            NSTimeInterval costTime = -([operationEnqueueDate timeIntervalSinceNow] * 1000);
            LCLoggerDebug(LCLoggerDomainNetwork, LC_REST_RESPONSE_LOG_FORMAT, path, costTime, responseObject);
            if (successBlock) {
                successBlock(HTTPResponse, responseObject);
            }
        }
        if (wait) {
            dispatch_semaphore_signal(semaphore);
        }
    }];
    [self.lock lock];
    [self.requestTable setObject:dataTask forKey:request.URL.absoluteString];
    [self.lock unlock];
    [dataTask resume];
    if (wait) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
}

- (BOOL)validateStatusCode:(NSInteger)statusCode {
    if (statusCode >= 100 && statusCode < 600) {
        return YES;
    }
    return NO;
}

- (BOOL)shouldStatisticsForPath:(NSString *)url statusCode:(NSInteger)statusCode {
    if (![self validateStatusCode:statusCode]) {
        return NO;
    }
    NSArray *exclusiveApis = @[
        @"appHosts",
        @"stats/collect",
        @"sendPolicy"
    ];
    
    for (NSString *api in exclusiveApis) {
        if ([url hasSuffix:api]) {
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Archive and handle request

- (NSString *)archiveRequest:(NSURLRequest *)request {
    NSString *fileName = [NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]];
    NSString *fullPath = [[LCPersistenceUtils eventuallyPath] stringByAppendingPathComponent:fileName];
    [NSKeyedArchiver archiveRootObject:request toFile:fullPath];
    return fullPath;
}

- (void)handleArchivedRequestAtPath:(NSString *)path {
    [self handleArchivedRequestAtPath:path block:nil];
}

- (BOOL)isErrorFromServer:(NSError *)error {
    NSDictionary *userInfo = error.userInfo;
    return userInfo && (userInfo[@"error"] || userInfo[@"code"]);
}

- (void)handleArchivedRequestAtPath:(NSString *)path block:(LCIdResultBlock)block {
    NSURLRequest *request = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:path]) {
        if (block) block(nil, nil);
        return;
    }
    
    @try {
        request = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    } @catch (NSException *exception) {
        [fileManager removeItemAtPath:path error:NULL];
        if (block) block(nil, nil);
        return;
    }
    
    if (![request isKindOfClass:[NSURLRequest class]]) {
        [fileManager removeItemAtPath:path error:NULL];
        if (block) block(nil, nil);
        return;
    }
    
    @synchronized (self.runningArchivedRequests) {
        if ([self.runningArchivedRequests containsObject:path])
            return;
        
        [self.runningArchivedRequests addObject:path];
    }
    
    [self performRequest:request block:^(id object, NSError *error) {
        if (!error) {
            [fileManager removeItemAtPath:path error:NULL];
        } else {
            NSInteger errorCode = error.code;
            BOOL isServerError = errorCode >= 500 && errorCode < 600;
            
            /* If error is a server error, we need retain the cached request. */
            if (!isServerError && [self isErrorFromServer:error]) {
                [fileManager removeItemAtPath:path error:NULL];
            }
        }
        
        @synchronized (self.runningArchivedRequests) {
            [self.runningArchivedRequests removeObject:path];
        }
        
        if (block) block(object, error);
    }];
}

- (void)handleAllArchivedRequests {
    NSFileManager *fileMgr = [[NSFileManager alloc] init];
    
    NSString *documentsDirectory = [LCPersistenceUtils eventuallyPath];
    NSArray *directoryContents = [fileMgr contentsOfDirectoryAtPath:documentsDirectory error:NULL];
    
    for (NSString *path in directoryContents) {
        NSString *fullPath = [documentsDirectory stringByAppendingPathComponent:path];
        [self handleArchivedRequestAtPath:fullPath];
    }
}

#pragma mark - Util method for client

- (NSString *)absoluteStringFromPath:(NSString *)path parameters:(NSDictionary *)parameters {
    return [[[self requestWithPath:path method:@"GET" headers:nil parameters:parameters] URL] absoluteString];
}

-(BOOL)addSubclassMapEntry:(NSString *)parseClassName
               classObject:(Class)object
{
    if (self.subclassTable == nil) {
        _subclassTable = [[NSMutableDictionary alloc] init];
    }
    
    if (parseClassName == nil) return NO;
    
    if ([self.subclassTable objectForKey:parseClassName]) {
        LCLoggerI(@"Warnning: Register duplicate with %@, %@ will be replaced by %@",
                  parseClassName, [self.subclassTable objectForKey:parseClassName], object);
    }
    
    [self.subclassTable setObject:object forKey:parseClassName];
    return YES;
}

-(Class)classFor:(NSString *)parseClassName
{
    return [self.subclassTable objectForKey:parseClassName];
}

- (LCACL *)updatedDefaultACL {
    if (self.defaultACL != nil) {
        LCACL *acl = [self.defaultACL copy];
        if (self.currentUserAccessForDefaultACL && self.currentUser) {
            [acl setReadAccess:YES forUser:self.currentUser];
            [acl setWriteAccess:YES forUser:self.currentUser];
        }
        return acl;
    }
    return nil;
}

@end
