//
//  AVPaasClient.m
//  paas
//
//  Created by Zhu Zeng on 2/25/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "AVPaasClient.h"
#import "AVPaasClient_internal.h"
#import "LCNetworking.h"
#import "AVUtils.h"
#import "AVUser_Internal.h"
#import "AVObject_Internal.h"
#import "AVRole_Internal.h"
#import "AVACL_Internal.h"
#import "AVCacheManager.h"
#import "AVErrorUtils.h"
#import "AVPersistenceUtils.h"
#import "AVScheduler.h"
#import "AVObjectUtils.h"
#import "LCNetworkStatistics.h"
#import "LCRouter.h"
#import "SDMacros.h"
#import "AVOSCloud_Internal.h"
#import "LCSSLChallenger.h"
#import "AVConstants.h"

#define MAX_LAG_TIME 5.0

NSString * const kLeanCloudRESTAPIResponseError = @"com.leancloud.restapi.response.error";

NSString *const LCHeaderFieldNameId = @"X-LC-Id";
NSString *const LCHeaderFieldNameKey = @"X-LC-Key";
NSString *const LCHeaderFieldNameSign = @"X-LC-Sign";
NSString *const LCHeaderFieldNameSession = @"X-LC-Session";
NSString *const LCHeaderFieldNameProduction = @"X-LC-Prod";

#define LC_REST_REQUEST_LOG_FORMAT \
    @"\n\n" \
    @"------ BEGIN LeanCloud REST Request -------\n" \
    @"path: %@\n" \
    @"curl: %@\n" \
    @"------ END --------------------------------\n" \
    @"\n"

#define LC_REST_RESPONSE_LOG_FORMAT \
    @"\n\n" \
    @"------ BEGIN LeanCloud REST Response ------\n" \
    @"path: %@\n" \
    @"cost: %.3fms\n" \
    @"response: %@\n" \
    @"------ END --------------------------------\n" \
    @"\n"

@implementation NSMutableString (URLRequestFormatter)

- (void)appendCommandLineArgument:(NSString *)arg {
    [self appendFormat:@" %@", [arg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
}

@end

@implementation NSURLRequest (curl)

- (NSString *)cURLCommand{
    NSMutableString *command = [NSMutableString stringWithString:@"curl -i -k"];
    
    [command appendCommandLineArgument:[NSString stringWithFormat:@"-X %@", [self HTTPMethod]]];

    if ([[[self HTTPMethod] uppercaseString] isEqualToString:@"GET"])
        [command appendCommandLineArgument:@"-G"];

    NSData *data = [self HTTPBody];
    if ([data length] > 0) {
        NSString *HTTPBodyString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [command appendCommandLineArgument:[NSString stringWithFormat:@"-d '%@'", HTTPBodyString]];
    }
    
    NSString *acceptEncodingHeader = [[self allHTTPHeaderFields] valueForKey:@"Accept-Encoding"];
    if (acceptEncodingHeader && [acceptEncodingHeader rangeOfString:@"gzip"].location != NSNotFound) {
        [command appendCommandLineArgument:@"--compressed"];
    }
    
    if ([self URL]) {
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[self URL]];
        for (NSHTTPCookie *cookie in cookies) {
            [command appendCommandLineArgument:[NSString stringWithFormat:@"--cookie \"%@=%@\"", [cookie name], [cookie value]]];
        }
    }

    NSMutableDictionary<NSString *, NSString *> *headers = [[self allHTTPHeaderFields] mutableCopy];

    /* Remove signature for security. */
    [headers removeObjectForKey:@"X-LC-Sign"];
    
    for (NSString * field in headers) {
        [command appendCommandLineArgument:[NSString stringWithFormat:@"-H %@", [NSString stringWithFormat:@"'%@: %@'", field, [[self valueForHTTPHeaderField:field] stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"]]]];
    }

    if ([self URL].query.length > 0) {
        NSString *query = [self URL].query;
        NSArray *components = [query componentsSeparatedByString:@"&"];
        for (NSString *component in components) {
            [command appendCommandLineArgument:[NSString stringWithFormat:@"--data-urlencode \'%@\'", component.stringByRemovingPercentEncoding]];
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
    
    [command appendCommandLineArgument:[NSString stringWithFormat:@"\"%@\"", basicUrl]];
    
    return [NSString stringWithString:command];
}
@end

@interface AVPaasClient()

@property (nonatomic, strong) LCURLSessionManager *sessionManager;

// The client is singleton, so the queue doesn't need release
#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong) dispatch_queue_t completionQueue;
#else
@property (nonatomic, assign) dispatch_queue_t completionQueue;
#endif

@property (nonatomic, strong) NSMutableSet *runningArchivedRequests;

@property (atomic, strong) NSMutableDictionary *lastModify;

@end

@implementation AVPaasClient

+(AVPaasClient *)sharedInstance
{
    static dispatch_once_t once;
    static AVPaasClient * sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.productionMode = YES;
        sharedInstance.timeoutInterval = kAVDefaultNetworkTimeoutInterval;
        
        sharedInstance.applicationIdField = LCHeaderFieldNameId;
        sharedInstance.applicationKeyField = LCHeaderFieldNameKey;
        sharedInstance.sessionTokenField = LCHeaderFieldNameSession;
        
        sharedInstance.runningArchivedRequests=[[NSMutableSet alloc] init];
        
        [AVScheduler sharedInstance];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        _requestTable = [NSMapTable strongToWeakObjectsMapTable];
        _completionQueue = dispatch_queue_create("avos.paas.completionQueue", DISPATCH_QUEUE_CONCURRENT);
        _sessionManager = ({
            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
            LCURLSessionManager *manager = [[LCURLSessionManager alloc] initWithSessionConfiguration:configuration];
            manager.completionQueue = _completionQueue;

            if ([AVOSCloud isSSLPinningEnabled]) {
                
                [manager setSessionDidReceiveAuthenticationChallengeBlock:
                 ^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session,
                                                       NSURLAuthenticationChallenge * _Nonnull challenge,
                                                       NSURLCredential *__autoreleasing  _Nullable * _Nullable credential)
                 {
                     [[LCSSLChallenger sharedInstance] acceptChallenge:challenge];
                     return NSURLSessionAuthChallengeUseCredential;
                 }];
            }

            /* Remove all null value of result. */
            LCJSONResponseSerializer *responseSerializer = (LCJSONResponseSerializer *)manager.responseSerializer;
            responseSerializer.removesKeysWithNullValues = YES;

            manager;
        });
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
            [[AVCacheManager sharedInstance] clearCacheForMD5Key:key];
        }
        
        [self.lastModify removeAllObjects];
    }
}

- (NSString *)signatureHeaderFieldValue {
    NSString *timestamp=[NSString stringWithFormat:@"%.0f",1000*[[NSDate date] timeIntervalSince1970]];
    NSString *sign=[[[NSString stringWithFormat:@"%@%@",timestamp,self.clientKey] AVMD5String] lowercaseString];
    NSString *headerValue=[NSString stringWithFormat:@"%@,%@",sign,timestamp];

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
    NSString * myPath = [NSString stringWithFormat:@"/%@/%@", [AVPaasClient sharedInstance].apiVersion, path];

    [dict setObject:method forKey:@"method"];
    [dict setObject:myPath forKey:@"path"];
}

- (NSMutableURLRequest *)requestWithPath:(NSString *)path
                                  method:(NSString *)method
                                 headers:(NSDictionary *)headers
                              parameters:(NSDictionary *)parameters
{
    NSURL *URL = [NSURL URLWithString:path];

    if (!URL.scheme.length) {
        NSString *URLString = [[LCRouter sharedInstance] URLStringForPath:path];
        URL = [NSURL URLWithString:URLString];
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];

    [request setHTTPMethod:method];
    [request setTimeoutInterval:self.timeoutInterval];
    [request setValue:self.applicationId forHTTPHeaderField:LCHeaderFieldNameId];
    [request setValue:[self signatureHeaderFieldValue] forHTTPHeaderField:LCHeaderFieldNameSign];
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

- (void)getObject:(NSString *)path
   withParameters:(NSDictionary *)parameters
            block:(AVIdResultBlock)block {
    [self getObjectFromNetworkWithPath:path withParameters:parameters policy:kAVCachePolicyIgnoreCache block:block];
}

-(void)getObjectFromNetworkWithPath:(NSString *)path
                     withParameters:(NSDictionary *)parameters
                             policy:(AVCachePolicy)policy
                              block:(AVIdResultBlock)block
{
    NSURLRequest *request = [self requestWithPath:path method:@"GET" headers:nil parameters:parameters];

    /* If GET request too heavy,
       wrap it into a POST request and ignore cache policy. */
    if (parameters && request.URL.absoluteString.length > 4096) {
        NSDictionary *request = [AVPaasClient batchMethod:@"GET" path:path body:nil parameters:parameters];
        [self postBatchObject:@[request] block:^(NSArray * _Nullable objects, NSError * _Nullable error) {
            if (!error) {
                [AVUtils callIdResultBlock:block object:objects.firstObject error:nil];
            } else {
                [AVUtils callIdResultBlock:block object:nil error:error];
            }
        }];
    } else {
        BOOL needCache = (policy != kAVCachePolicyIgnoreCache);
        [self performRequest:request saveResult:needCache block:block];
    }
}

- (void)getObject:(NSString *)path withParameters:(NSDictionary *)parameters policy:(AVCachePolicy)policy maxCacheAge:(NSTimeInterval)maxCacheAge block:(AVIdResultBlock)block {
    
    NSString *key = [self absoluteStringFromPath:path parameters:parameters];
    
    switch (policy) {
        case kAVCachePolicyIgnoreCache:
        {
            [self getObjectFromNetworkWithPath:path withParameters:parameters policy:policy block:block];
        }
            break;
        case kAVCachePolicyCacheOnly:
        {
            [[AVCacheManager sharedInstance] getWithKey:key maxCacheAge:maxCacheAge block:block];
        }
            break;
        case kAVCachePolicyNetworkOnly:
        {            
            [self getObjectFromNetworkWithPath:path withParameters:parameters policy:policy block:^(id object, NSError *error) {
                block(object, error);
            }];
        }
            break;
        case kAVCachePolicyCacheElseNetwork:
        {
            [[AVCacheManager sharedInstance] getWithKey:key maxCacheAge:maxCacheAge block:^(id object, NSError *error) {
                if (error) {
                    [self getObjectFromNetworkWithPath:path withParameters:parameters policy:policy block:block];
                } else {
                    block(object, error);
                }
            }];
        }
            break;
        case kAVCachePolicyNetworkElseCache:
        {
            [self getObjectFromNetworkWithPath:path withParameters:parameters policy:policy block:^(id object, NSError *error) {
                if (error) {
                    [[AVCacheManager sharedInstance] getWithKey:key maxCacheAge:maxCacheAge block:block];
                } else {
                    block(object, error);
                }
            }];
        }
            break;
        case kAVCachePolicyCacheThenNetwork:
        {
            [[AVCacheManager sharedInstance] getWithKey:key maxCacheAge:maxCacheAge block:^(id object, NSError *error) {
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

-(void)putObject:(NSString *)path
  withParameters:(NSDictionary *)parameters
    sessionToken:(NSString *)sessionToken
           block:(AVIdResultBlock)block
{
    NSMutableURLRequest *request = [self requestWithPath:path method:@"PUT" headers:nil parameters:parameters];

    if (sessionToken) {
        [request setValue:sessionToken forHTTPHeaderField:LCHeaderFieldNameSession];
    }

    [self performRequest:request saveResult:NO block:block];
}

-(void)postBatchObject:(NSArray *)parameterArray block:(AVArrayResultBlock)block {
    [self postBatchObject:parameterArray headerMap:nil eventually:NO block:block];
}

-(void)postBatchObject:(NSArray *)requests headerMap:(NSDictionary *)headerMap eventually:(BOOL)isEventually block:(AVArrayResultBlock)block {
    NSString *path = [AVObjectUtils batchPath];
    NSDictionary *parameters = @{@"requests": requests ?: @[]};
    NSMutableURLRequest *request = [self requestWithPath:path method:@"POST" headers:headerMap parameters:parameters];

    AVIdResultBlock handleResultBlock = ^(NSArray *objects, NSError *error) {
        // 区分某个删除失败还是网络请求失败，两种情况 error 都不为空
        if (objects.count != requests.count) {
            // 网络请求失败，子操作数量不一致
            if (error) {
                block(nil, error);
            } else {
                block(nil, [AVErrorUtils errorWithCode:0 errorText:@"The batch count of server response is not equal to request count"]);
            }
        } else {
            // 网络请求成功
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
    };

    if (isEventually) {
        NSString *filePath = [self archiveRequest:request];
        [self handleArchivedRequestAtPath:filePath block:handleResultBlock];
    } else {
        [self performRequest:request saveResult:NO block:handleResultBlock];
    }
}

-(void)postBatchSaveObject:(NSArray *)requests headerMap:(NSDictionary *)headerMap eventually:(BOOL)isEventually block:(AVIdResultBlock)block {
    NSString *path = [AVObjectUtils batchSavePath];
    NSDictionary *parameters = @{@"requests": requests};
    NSMutableURLRequest *request = [self requestWithPath:path method:@"POST" headers:headerMap parameters:parameters];

    if (isEventually) {
        NSString *filePath = [self archiveRequest:request];
        [self handleArchivedRequestAtPath:filePath block:block];
    } else {
        [self performRequest:request saveResult:NO block:block];
    }
}

-(void)postObject:(NSString *)path
   withParameters:(NSDictionary *)parameters
            block:(AVIdResultBlock)block
{
    [self postObject:path withParameters:parameters eventually:NO block:block];
}

-(void)postObject:(NSString *)path withParameters:(NSDictionary *)parameters eventually:(BOOL)isEventually block:(AVIdResultBlock)block {
    NSMutableURLRequest *request = [self requestWithPath:path method:@"POST" headers:nil parameters:parameters];

    if (isEventually) {
        NSString *filePath = [self archiveRequest:request];
        [self handleArchivedRequestAtPath:filePath block:block];
    } else {
        [self performRequest:request saveResult:NO block:block];
    }
}

-(void)deleteObject:(NSString *)path
     withParameters:(NSDictionary *)parameters
              block:(AVIdResultBlock)block
{
    [self deleteObject:path withParameters:parameters eventually:NO block:block];
}

- (void)deleteObject:(NSString *)path withParameters:(NSDictionary *)parameters eventually:(BOOL)isEventually block:(AVIdResultBlock)block {
    NSMutableURLRequest *request = [self requestWithPath:path method:@"DELETE" headers:nil parameters:parameters];

    if (isEventually) {
        NSString *filePath = [self archiveRequest:request];
        [self handleArchivedRequestAtPath:filePath block:block];
    } else {
        [self performRequest:request saveResult:NO block:block];
    }
}

#pragma mark - The final method for network

- (void)performRequest:(NSURLRequest *)request saveResult:(BOOL)saveResult block:(AVIdResultBlock)block {
    [self performRequest:request saveResult:saveResult block:block retryTimes:0];
}

- (void)performRequest:(NSURLRequest *)request saveResult:(BOOL)saveResult block:(AVIdResultBlock)block retryTimes:(NSInteger)retryTimes {
    NSURL *URL = request.URL;
    NSString *URLString = URL.absoluteString;
    NSMutableURLRequest *mutableRequest = [request mutableCopy];

    if (self.isLastModifyEnabled && [request.HTTPMethod isEqualToString:@"GET"]) {
        NSString *modifiedSince = self.lastModify[[URLString AVMD5String]];
        if (modifiedSince && [[AVCacheManager sharedInstance] hasCacheForKey:URLString]) {
            [mutableRequest setValue:modifiedSince forHTTPHeaderField:@"If-Modified-Since"];
        }
    }

    @weakify(self);

    [self performRequest:mutableRequest
                 success:^(NSHTTPURLResponse *response, id responseObject)
    {
        @strongify(self);

        if (block) {
            
            block(responseObject, nil);
        }

        if (self.isLastModifyEnabled && [request.HTTPMethod isEqualToString:@"GET"]) {
            NSString *URLMD5 = [URLString AVMD5String];
            NSString *lastModified = [response.allHeaderFields objectForKey:@"Last-Modified"];

            if (lastModified && ![self.lastModify[URLMD5] isEqualToString:lastModified]) {
                [[AVCacheManager sharedInstance] saveJSON:responseObject forKey:URLString];
                [self.lastModify setObject:lastModified forKey:URLMD5];
            }
        } else if (saveResult) {
            [[AVCacheManager sharedInstance] saveJSON:responseObject forKey:URLString];
        }
    }
              failure:^(NSHTTPURLResponse *response, id responseObject, NSError *error)
    {
        @strongify(self);

        NSInteger statusCode = response.statusCode;

        if (statusCode == 304) {
            // 304 is not error
            [[AVCacheManager sharedInstance] getWithKey:URLString maxCacheAge:3600 * 24 * 30 block:^(id object, NSError *error) {
                @strongify(self);

                if (error) {
                    if (retryTimes < 3) {
                        [self.lastModify removeObjectForKey:[URLString AVMD5String]];
                        [[AVCacheManager sharedInstance] clearCacheForKey:URLString];
                        [mutableRequest setValue:@"" forHTTPHeaderField:@"If-Modified-Since"];
                        [self performRequest:mutableRequest saveResult:saveResult block:block retryTimes:retryTimes + 1];
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
    }];
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
    dispatch_semaphore_t semaphore;
    NSString *path = request.URL.path;
    AVLoggerDebug(AVLoggerDomainNetwork, LC_REST_REQUEST_LOG_FORMAT, path, [request cURLCommand]);

    NSDate *operationEnqueueDate = [NSDate date];

    if (wait)
        semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask *dataTask = [self.sessionManager dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        /* As Apple say:
         > Whenever you make an HTTP request,
         > the NSURLResponse object you get back is actually an instance of the NSHTTPURLResponse class.
         */
        NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;

        if (error) {
            NSError *newError = ({
                NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
                [userInfo addEntriesFromDictionary:error.userInfo];
                userInfo[kLeanCloudRESTAPIResponseError] = responseObject;
                [NSError errorWithDomain:error.domain
                                    code:error.code
                                userInfo:userInfo.copy];
            });
            if (failureBlock) {
                failureBlock(HTTPResponse, responseObject, newError);
            }

            NSInteger statusCode = HTTPResponse.statusCode;
            NSTimeInterval costTime = -([operationEnqueueDate timeIntervalSinceNow] * 1000);

            AVLoggerDebug(AVLoggerDomainNetwork, LC_REST_RESPONSE_LOG_FORMAT, path, costTime, newError);

            // Doing network statistics
            if ([self shouldStatisticsForPath:path statusCode:statusCode]) {
                LCNetworkStatistics *statistician = [LCNetworkStatistics sharedInstance];

                if (newError.code == NSURLErrorTimedOut) {
                    [statistician addIncrementalAttribute:1 forKey:@"timeout"];
                } else {
                    [statistician addIncrementalAttribute:1 forKey:[NSString stringWithFormat:@"%ld", (long)statusCode]];
                }

                [statistician addIncrementalAttribute:1 forKey:@"total"];
            }
        } else {
            if (successBlock) {
                successBlock(HTTPResponse, responseObject);
            }

            NSInteger statusCode = HTTPResponse.statusCode;
            NSTimeInterval costTime = -([operationEnqueueDate timeIntervalSinceNow] * 1000);

            AVLoggerDebug(AVLoggerDomainNetwork, LC_REST_RESPONSE_LOG_FORMAT, path, costTime, responseObject);

            // Doing network statistics
            if ([self shouldStatisticsForPath:path statusCode:statusCode]) {
                LCNetworkStatistics *statistician = [LCNetworkStatistics sharedInstance];

                if ((NSInteger)(statusCode / 100) == 2) {
                    [statistician addAverageAttribute:costTime forKey:@"avg"];
                }

                [statistician addIncrementalAttribute:1 forKey:[NSString stringWithFormat:@"%ld", (long)statusCode]];
                [statistician addIncrementalAttribute:1 forKey:@"total"];
            }
        }

        if (wait)
            dispatch_semaphore_signal(semaphore);
    }];

    [self.requestTable setObject:dataTask forKey:request.URL.absoluteString];

    [dataTask resume];

    if (wait)
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
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
    NSString *fullPath = [[AVPersistenceUtils eventuallyPath] stringByAppendingPathComponent:fileName];
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

- (void)handleArchivedRequestAtPath:(NSString *)path block:(AVIdResultBlock)block {
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

    @weakify(self);
    [self performRequest:request saveResult:NO block:^(id object, NSError *error) {
        @strongify(self);

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
    
    NSString *documentsDirectory = [AVPersistenceUtils eventuallyPath];
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
        AVLoggerI(@"Warnning: Register duplicate with %@, %@ will be replaced by %@",
               parseClassName, [self.subclassTable objectForKey:parseClassName], object);
    }
    
    [self.subclassTable setObject:object forKey:parseClassName];
    return YES;
}

-(Class)classFor:(NSString *)parseClassName
{
    return [self.subclassTable objectForKey:parseClassName];
}

- (AVACL *)updatedDefaultACL {
    if (self.defaultACL != nil) {
        AVACL *acl = [self.defaultACL copy];
        if (self.currentUserAccessForDefaultACL && self.currentUser) {
            [acl setReadAccess:YES forUser:self.currentUser];
            [acl setWriteAccess:YES forUser:self.currentUser];
        }
        return acl;
    }
    return nil;
}

@end
