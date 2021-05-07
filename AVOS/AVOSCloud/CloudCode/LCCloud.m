//
//  LCCloud.m
//  LeanCloud
//
//  Created by Zhu Zeng on 2/25/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import "LCCloud.h"
#import "LCPaasClient.h"
#import "LCErrorUtils.h"
#import "LCUtils.h"
#import "LCObject_Internal.h"
#import "LCFile_Internal.h"
#import "LCGeoPoint_Internal.h"
#import "LCObjectUtils.h"
#import "LCLogger.h"

@implementation LCCloud

+ (void)setProductionMode:(BOOL)isProduction {
    [[LCPaasClient sharedInstance] setProductionMode:isProduction];
}

/**
 curl -X POST \
 -H "X-LC-Id: 4xfOAyaD0HTNPtkmIYYcRXvY0GrB0VhAFctVRgym" \
 -H "X-LC-Key: jxrpUwpyP9MHX2hrm0xqoyeVAaUCX32a1px8FPFt" \
 -H "Content-Type: application/json" \
 -d '{"student":"Han Meimei"}' \
 https://api.leancloud.cn/1.1/functions/score
 */
+ (id)callFunction:(NSString *)function withParameters:(NSDictionary *)parameters
{
    return [[self class] callFunction:function withParameters:parameters error:NULL];
}

+ (id)callFunction:(NSString *)function withParameters:(NSDictionary *)parameters error:(NSError **)outError
{
    NSDictionary *serializedParameters = nil;

    if (parameters) {
        serializedParameters = [LCObjectUtils dictionaryFromDictionary:parameters];
    }

    NSString *path = [NSString stringWithFormat:@"functions/%@", function];
    NSURLRequest *request = [[LCPaasClient sharedInstance] requestWithPath:path method:@"POST" headers:nil parameters:serializedParameters];

    __block id error = nil;
    __block id result = nil;
    __block BOOL finished = NO;

    [[LCPaasClient sharedInstance]
     performRequest:request
     success:^(NSHTTPURLResponse *response, id responseObject) {
         result = [self processedFunctionResultFromObject:responseObject[@"result"]];
         finished = YES;
     }
     failure:^(NSHTTPURLResponse *response, id responseObject, NSError *inError) {

         if (inError) {
             
             error = inError;
         }

         finished = YES;
     }];

    LC_WAIT_TIL_TRUE(finished, 0.1);

    if (outError) {
        *outError = error;
    }

    return result;
}

+ (void)callFunctionInBackground:(NSString *)function withParameters:(NSDictionary *)parameters block:(LCIdResultBlock)block
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        id result = [[self class] callFunction:function withParameters:parameters error:&error];
        [LCUtils callIdResultBlock:block object:result error:error];
    });
}

+ (id)rpcFunction:(NSString *)function withParameters:(id)parameters {
    return [self rpcFunction:function withParameters:parameters error:NULL];
}

+ (id)rpcFunction:(NSString *)function withParameters:(id)parameters error:(NSError *__autoreleasing *)error {
    __block id object = nil;
    __block NSError *serverError = nil;

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    [self rpcFunctionInBackground:function withParameters:parameters block:^(id object_, NSError *error) {
        object = object_;
        serverError = error;

        dispatch_semaphore_signal(sema);
    }];

    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

    if (error)
        *error = serverError;

    return object;
}

+ (void)rpcFunctionInBackground:(NSString *)function withParameters:(id)parameters block:(LCIdResultBlock)block {
    NSDictionary *serializedParameters = nil;

    if (parameters) {
        serializedParameters = [LCObjectUtils dictionaryFromObject:parameters topObject:YES];
    }

    NSString *path = [NSString stringWithFormat:@"call/%@", function];
    NSURLRequest *request = [[LCPaasClient sharedInstance] requestWithPath:path method:@"POST" headers:nil parameters:serializedParameters];

    [[LCPaasClient sharedInstance]
     performRequest:request
     success:^(NSHTTPURLResponse *response, id responseObject) {
         id result = [self processedFunctionResultFromObject:responseObject[@"result"]];
         [LCUtils callIdResultBlock:block object:result error:nil];
     }
     failure:^(NSHTTPURLResponse *response, id responseObject, NSError *inError) {
         
         [LCUtils callIdResultBlock:block object:nil error:inError];
     }];
}

#pragma mark - Data from LeanEngine
/*
 response: Dictionary/Array or Simple Objects like String/Number(all from json)
 response like this:
 
 {"result":"Hello world!"}
 
 {
 "result": {
 "__type": "Object",
 "className": "Armor",
 "createdAt": "2013-04-02T06:15:27.211Z",
 "displayName": "Wooden Shield",
 "fireproof": false,
 "objectId": "2iGGg18C7H",
 "rupees": 50,
 "updatedAt": "2013-04-02T06:15:27.211Z"
 }
 }
 
 {
 "result": [
 {
 "__type": "Object",
 "cheatMode": false,
 "className": "Armor",
 "createdAt": "2013-04-20T07:45:54.962Z",
 "objectId": "8o2ncpWitt",
 "otherArmor": {
 "__type": "Pointer",
 "className": "Armor",
 "objectId": "dEvrhyRGcr"
 },
 "playerName": "Sean Plott",
 "score": 1337,
 "testBytes": {
 "__type": "Bytes",
 "base64": "VGhpcyBpcyBhbiBlbmNvZGVkIHN0cmluZw=="
 },
 "testDate": {
 "__type": "Date",
 "iso": "2011-08-21T18:02:52.249Z"
 },
 "testGeoPoint": {
 "__type": "GeoPoint",
 "latitude": 40,
 "longitude": -30
 },
 "testRelation": {
 "__type": "Relation",
 "className": "GameScore"
 },
 "updatedAt": "2013-04-20T07:45:54.962Z"
 }
 ]
 }
 */
+ (id)processedFunctionResultFromObject:(id)response {
    id newResultValue;
    if ([response isKindOfClass:[NSArray class]]) {
        newResultValue = [[self class] processedFunctionResultFromArray:response];
    } else if ([response isKindOfClass:[NSDictionary class]]) {
        newResultValue = [[self class] processedFunctionResultFromDic:response];
    } else {
        // String or somethings
        newResultValue = response;
    }
    return newResultValue;
}

+ (id)processedFunctionResultFromArray:(NSArray *)array {
    NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:array.count];
    for (id obj in [array copy]) {
        [newArray addObject:[[self class] processedFunctionResultFromObject:obj]];
    }
    return [newArray copy];
}

+ (id)processedFunctionResultFromDic:(NSDictionary *)dic {
    NSString * type = [dic valueForKey:@"__type"];
    if (type == nil || ![type isKindOfClass:[NSString class]]) {
        NSMutableDictionary *newDic = [NSMutableDictionary dictionaryWithCapacity:dic.count];
        
        for (NSString *key in [dic allKeys]) {
            id o = [dic objectForKey:key];
            [newDic setValue:[[self class] processedFunctionResultFromObject:o] forKey:key];
        }
        
        return [newDic copy];
    } else {
        // 有 __type，则像解析 LCQuery 的结果一样
        return [LCObjectUtils objectFromDictionary:dic];
    }
    return dic;
}

@end
