//
//  LCPaasClient.h
//  paas
//
//  Created by Zhu Zeng on 2/25/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LCUtils.h"
#import "LCACL.h"
#import "UserAgent.h"
#import "LCQuery.h"

@class LCApplication;
@class LCURLSessionManager;

static NSString * const USER_AGENT = @"LeanCloud-Objc-SDK/" SDK_VERSION;

FOUNDATION_EXPORT NSString * const LCHeaderFieldNameId;
FOUNDATION_EXPORT NSString * const LCHeaderFieldNameKey;
FOUNDATION_EXPORT NSString * const LCHeaderFieldNameSign;
FOUNDATION_EXPORT NSString * const LCHeaderFieldNameSession;
FOUNDATION_EXPORT NSString * const LCHeaderFieldNameProduction;

@interface LCPaasClient : NSObject

@property (nonatomic) LCApplication *application;
@property (nonatomic, readonly, copy) NSString *apiVersion;
@property (nonatomic) LCUser *currentUser;
@property (nonatomic) LCACL *defaultACL;
@property (nonatomic) BOOL currentUserAccessForDefaultACL;
@property (nonatomic) NSTimeInterval timeoutInterval;
@property (nonatomic) NSMutableDictionary *subclassTable;
@property (nonatomic) BOOL productionMode;
@property (nonatomic) BOOL isLastModifyEnabled;
@property (nonatomic) NSLock *lock;
@property (nonatomic) NSMapTable *requestTable;
@property (nonatomic) LCURLSessionManager *sessionManager;
@property (nonatomic) dispatch_queue_t completionQueue;
@property (nonatomic) NSMutableSet *runningArchivedRequests;
@property (atomic) NSMutableDictionary *lastModify;

+ (LCPaasClient *)sharedInstance;

-(void)clearLastModifyCache;

- (LCACL *)updatedDefaultACL;

+(NSMutableDictionary *)batchMethod:(NSString *)method
                               path:(NSString *)path
                               body:(NSDictionary *)body
                         parameters:(NSDictionary *)parameters;

+(void)updateBatchMethod:(NSString *)method
                    path:(NSString *)path
                    dict:(NSMutableDictionary *)dict;

- (void)getObject:(NSString *)path
   withParameters:(NSDictionary *)parameters
            block:(LCIdResultBlock)block;
- (void)getObject:(NSString *)path
   withParameters:(NSDictionary *)parameters
            block:(LCIdResultBlock)block
             wait:(BOOL)wait;
- (void)getObject:(NSString *)path
   withParameters:(NSDictionary *)parameters
           policy:(LCCachePolicy)policy
      maxCacheAge:(NSTimeInterval)maxCacheAge
            block:(LCIdResultBlock)block;

- (void)putObject:(NSString *)path
   withParameters:(NSDictionary *)parameters
     sessionToken:(NSString *)sessionToken
            block:(LCIdResultBlock)block;

- (void)postBatchObject:(NSArray *)parameterArray
                  block:(LCArrayResultBlock)block;
- (void)postBatchObject:(NSArray *)parameterArray
              headerMap:(NSDictionary *)headerMap
                  block:(LCArrayResultBlock)block
                   wait:(BOOL)wait;

-(void)postBatchSaveObject:(NSArray *)parameterArray headerMap:(NSDictionary *)headerMap eventually:(BOOL)isEventually block:(LCIdResultBlock)block;

- (void)postObject:(NSString *)path withParameters:(id)parameters block:(LCIdResultBlock)block;
- (void)postObject:(NSString *)path withParameters:(id)parameters eventually:(BOOL)isEventually block:(LCIdResultBlock)block;

-(void)deleteObject:(NSString *)path
     withParameters:(NSDictionary *)parameters
              block:(LCIdResultBlock)block;

- (void)deleteObject:(NSString *)path
      withParameters:(NSDictionary *)parameters
          eventually:(BOOL)isEventually
               block:(LCIdResultBlock)block;

- (NSString *)absoluteStringFromPath:(NSString *)path parameters:(NSDictionary *)parameters;

-(BOOL)addSubclassMapEntry:(NSString *)parseClassName
               classObject:(Class)object;
-(Class)classFor:(NSString *)parseClassName;

// offline
// TODO: never called this yet!
- (void)handleAllArchivedRequests;

#pragma mark - Network Utils

/*!
 * Get signature header field value.
 */
- (NSString *)signatureHeaderFieldValue;

- (NSMutableURLRequest *)requestWithPath:(NSString *)path
                                  method:(NSString *)method
                                 headers:(NSDictionary *)headers
                              parameters:(id)parameters;

- (void)performRequest:(NSURLRequest *)request
               success:(void (^)(NSHTTPURLResponse *response, id responseObject))successBlock
               failure:(void (^)(NSHTTPURLResponse *response, id responseObject, NSError *error))failureBlock;

- (void)performRequest:(NSURLRequest *)request
             validator:(BOOL (^)(NSHTTPURLResponse *response, id responseObject))validator
               success:(void (^)(NSHTTPURLResponse *response, id responseObject))successBlock
               failure:(void (^)(NSHTTPURLResponse *response, id responseObject, NSError *error))failureBlock;

- (void)performRequest:(NSURLRequest *)request
               success:(void (^)(NSHTTPURLResponse *response, id responseObject))successBlock
               failure:(void (^)(NSHTTPURLResponse *response, id responseObject, NSError *error))failureBlock
                  wait:(BOOL)wait;

- (void)performRequest:(NSURLRequest *)request
             validator:(BOOL (^)(NSHTTPURLResponse *response, id responseObject))validator
               success:(void (^)(NSHTTPURLResponse *response, id responseObject))successBlock
               failure:(void (^)(NSHTTPURLResponse *response, id responseObject, NSError *error))failureBlock
                  wait:(BOOL)wait;

@end
