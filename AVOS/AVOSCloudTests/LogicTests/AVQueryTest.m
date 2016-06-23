//
//  AVQueryTest.m
//  paas
//
//  Created by Travis on 13-11-11.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "AVTestBase.h"
#import "AVPaasClient.h"
#import "AVQuery_Internal.h"
#import "AVCacheManager.h"
@interface AVQueryTest : AVTestBase

@end

@implementation AVQueryTest

-(void)testFindAll{
    NSString * className = NSStringFromClass([self class]);
    
    NSError *err=nil;
    AVObject *obj=[AVObject objectWithClassName:className];
    [obj setObject:@"test" forKey:@"data"];
    XCTAssertTrue([obj save:&err], @"save fail:%@",[err description]);
    [self addDeleteObject:obj];
    AVQuery *q=[AVQuery queryWithClassName:className];
    
    XCTAssertTrue([q findObjects:&err], @"get fail:%@",[err description]);
}

-(void)testLastModify{
    
    NSError *err=nil;
    
    NSString * className = NSStringFromClass([self class]);
    
    AVObject *obj=[AVObject objectWithClassName:className];
    [obj setObject:@"test" forKey:@"data"];
    XCTAssertTrue([obj save:&err], @"save fail:%@",[err description]);
    [self addDeleteObject:obj];
    [AVOSCloud setLastModifyEnabled:YES];
    
    AVQuery * query = [AVQuery queryWithClassName:className];
    
    [query getFirstObjectInBackgroundWithBlock:^(AVObject *result, NSError *error) {
        
        XCTAssertNil(error,@"query not work: %@",[error description]);
        
        [query getFirstObjectInBackgroundWithBlock:^(AVObject *result, NSError *error) {
            XCTAssertNotNil(result, @"304 not work: %@",error);
            NOTIFY
        }];
        
    }];
    WAIT;
}



-(void)testLastModifyCache {
    NSError *err=nil;
    
    NSString * className = NSStringFromClass([self class]);
    
    AVObject *obj=[AVObject objectWithClassName:className];
    [obj setObject:@"test" forKey:@"data"];
    XCTAssertTrue([obj save:&err], @"save fail:%@",[err description]);
    [self addDeleteObject:obj];
    
    [AVOSCloud setLastModifyEnabled:YES];
    
    AVQuery * query = [AVQuery queryWithClassName:className];
    
    [query getFirstObjectInBackgroundWithBlock:^(AVObject *result, NSError *error) {
        
        XCTAssertNil(error,@"query not work: %@",[error description]);
        
        sleep(1);
        
        NSString *path = [query queryPath];
        [query assembleParameters];
        [query.parameters setObject:@(1) forKey:@"limit"];

        NSString *url = [[AVPaasClient sharedInstance] absoluteStringFromPath:path parameters:query.parameters];
        
        XCTAssertTrue([[AVCacheManager sharedInstance] hasCacheForKey:url], @"Cache not exist");
        
        [AVOSCloud clearLastModifyCache];
        
        sleep(1);
        
        XCTAssertFalse([[AVCacheManager sharedInstance] hasCacheForKey:url], @"Cache not clear");
        
        NOTIFY
    }];
    WAIT;
}

/**
 *  发送请求时有缓存 请求过程中 缓存被清除
 */
-(void)testLastModifyCache2{
    NSError *err=nil;
    
    NSString * className = NSStringFromClass([self class]);
    
    AVObject *obj=[AVObject objectWithClassName:className];
    [obj setObject:@"test" forKey:@"data"];
    XCTAssertTrue([obj save:&err], @"save fail:%@",[err description]);
    [self addDeleteObject:obj];
    
    [AVOSCloud setLastModifyEnabled:YES];
    
    AVQuery * query = [AVQuery queryWithClassName:className];
    
    [query getFirstObjectInBackgroundWithBlock:^(AVObject *result, NSError *error) {
        
        XCTAssertNil(error,@"query not work: %@",[error description]);
        XCTAssertNotNil(result, @"can't get result");
        
        sleep(1);
        
        NSString *path = [query queryPath];
        [query assembleParameters];
        [query.parameters setObject:@(1) forKey:@"limit"];
        
        NSString *url = [[AVPaasClient sharedInstance] absoluteStringFromPath:path parameters:query.parameters];

        XCTAssertTrue([[AVCacheManager sharedInstance] hasCacheForKey:url], @"Cache not exist");
        
        [query getFirstObjectInBackgroundWithBlock:^(AVObject *result, NSError *error) {
            XCTAssertNil(error,@"query not work: %@",[error description]);
            XCTAssertNotNil(result, @"can't get result");
            
            NOTIFY
        }];
         
        [[AVPaasClient sharedInstance] clearLastModifyCache];
        
    }];
    
    
    WAIT;
}


-(void)testQueryPolicyCacheThenNetwork {
    
    NSString * className = NSStringFromClass([self class]);
    NSString * keyName = @"objectId";
    NSError * error = nil;
    int max = 4;
    NSString * objectId = nil;
    for(int i = 0; i < max; ++i) {
        AVObject * object = [AVObject objectWithClassName:className];
        [object setObject:@(i) forKey:@"value"];
        XCTAssertTrue([object save:&error], @"error %@", error);
        [self addDeleteObject:object];
        objectId = object.objectId;
    }
    
    AVQuery * query = [AVQuery queryWithClassName:className];
    [query whereKey:keyName equalTo:objectId];
    query.cachePolicy = kAVCachePolicyCacheThenNetwork;
    query.maxCacheAge=60*60;
    
    if ([query hasCachedResult]) {
        NSLog(@"有缓存");
    } else {
        NSLog(@"没有缓存");
    }
    __block int count = 0;
    __block AVObject * object = nil;
    
    [query getFirstObjectInBackgroundWithBlock:^(AVObject *result, NSError *error) {
        if (count == 0) {
            XCTAssertNotNil(error, @"cache error");
        } else {
            XCTAssertNotNil(result, @"query failed");
            XCTAssertEqualObjects(result.objectId, objectId, @"object id test failed");
            object = result;
            NOTIFY;
        }
        ++count;
    }];
    WAIT;
    
    // contain local cache now, change the value now.
    [object setObject:@(max / 2 * 10) forKey:@"value"];
    XCTAssertTrue([object save:&error], @"error %@", error);
    
    // requery
    count = 0;
    
    [query getFirstObjectInBackgroundWithBlock:^(AVObject *result, NSError *error) {
        if ([query hasCachedResult]) {
            NSLog(@"有缓存");
        } else {
            NSLog(@"没有缓存");
        }
        if (count == 0) {
            XCTAssertNotNil(result, @"query failed");
            XCTAssertEqualObjects(result.objectId, object.objectId, @"object id not equal");
            int value = [[result objectForKey:@"value"] intValue];
            XCTAssertTrue(value == max - 1, @"value error");
        } else {
            XCTAssertNotNil(result, @"error %@", error);
            int value = [[result objectForKey:@"value"] intValue];
            XCTAssertTrue(value == max / 2 * 10, @"value error");
            [query clearCachedResult];
            NOTIFY;
        }
        ++count;
    }];
    WAIT;
}

-(void)testQueryPolicyCacheElseNetwork {
    
    NSString * className = NSStringFromClass([self class]);
    NSString * keyName = @"objectId";
    NSError * error = nil;
    int max = 4;
    NSString * objectId = nil;
    for(int i = 0; i < max; ++i) {
        AVObject * object = [AVObject objectWithClassName:className];
        [object setObject:@(i) forKey:@"value"];
        XCTAssertTrue([object save:&error], @"error %@", error);
        [self addDeleteObject:object];
        objectId = object.objectId;
    }
    
    AVQuery * query = [AVQuery queryWithClassName:className];
    [query whereKey:keyName equalTo:objectId];
    query.cachePolicy = kAVCachePolicyCacheElseNetwork;
    query.maxCacheAge=60*60;
    
    if ([query hasCachedResult]) {
        NSLog(@"有缓存");
    } else {
        NSLog(@"没有缓存");
    }
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertNil(error);
        if ([query hasCachedResult]) {
            NSLog(@"有缓存");
        } else {
            NSLog(@"没有缓存");
        }
        NOTIFY;
    }];
    WAIT;
    query = [AVQuery queryWithClassName:className];
    [query whereKey:keyName equalTo:objectId];
    query.cachePolicy = kAVCachePolicyCacheElseNetwork;
    query.maxCacheAge=60*60;
    
    if ([query hasCachedResult]) {
        NSLog(@"有缓存");
    } else {
        NSLog(@"没有缓存");
    }
}

- (void)testQueryNull {
    NSString * className = NSStringFromClass([self class]);
    
    NSError *err=nil;
    AVObject *obj=[AVObject objectWithClassName:className];
    [obj setObject:@"test" forKey:@"dataa"];
    XCTAssertTrue([obj save:&err], @"save fail:%@",[err description]);
    [self addDeleteObject:obj];
    obj=[AVObject objectWithClassName:className];
    [obj setObject:@"test" forKey:@"datab"];
    XCTAssertTrue([obj save:&err], @"save fail:%@",[err description]);
    [self addDeleteObject:obj];
    AVQuery *q=[AVQuery queryWithClassName:className];
    [q whereKey:@"dataa" notEqualTo:[NSNull null]];
    
    XCTAssertTrue([q findObjects:&err], @"get fail:%@",[err description]);

}

- (void)testQueryPolicyCacheElseNetwork2 {
    NSString * className = NSStringFromClass([self class]);
    NSString * keyName = @"objectId";
    NSError * error = nil;
    int max = 4;
    NSString * objectId = nil;
    for(int i = 0; i < max; ++i) {
        AVObject * object = [AVObject objectWithClassName:className];
        [object setObject:@(i) forKey:@"value"];
        XCTAssertTrue([object save:&error], @"error %@", error);
        [self addDeleteObject:object];
        objectId = object.objectId;
    }
    
    AVQuery * query = [AVQuery queryWithClassName:className];
    [query whereKey:keyName equalTo:objectId];
    query.cachePolicy = kAVCachePolicyCacheElseNetwork;
    query.maxCacheAge=60*60;
    __block AVObject * object = nil;
    
    [query getFirstObjectInBackgroundWithBlock:^(AVObject *result, NSError *error) {
        // 缓存获取失败，从服务器获取
        XCTAssertNotNil(result, @"query failed");
        XCTAssertEqualObjects(result.objectId, objectId, @"object id test failed");
        object = result;
        NOTIFY;
    }];
    WAIT;
    
    // contain local cache now, change the value now.
    [object setObject:@(max / 2 * 10) forKey:@"value"];
    XCTAssertTrue([object save:&error], @"error %@", error);
    
    [query getFirstObjectInBackgroundWithBlock:^(AVObject *result, NSError *error) {
        // 缓存获取成功，直接返回
        XCTAssertNotNil(result, @"query failed");
        XCTAssertEqualObjects(result.objectId, object.objectId, @"object id not equal");
        int value = [[result objectForKey:@"value"] intValue];
        XCTAssertTrue(value == max - 1, @"value error");
        NOTIFY;
    }];
    WAIT;
}

-(void)testAssertDifferentClassNameForANDOR{
    AVQuery *query1=[AVUser query];
    AVQuery *query2=[AVQuery queryWithClassName:@"_Follower"];
    
    NSArray *arr=@[query1,query2];
#ifdef DEBUG
    // Default, NSAssert just compiled for debug
    XCTAssertThrows([AVQuery orQueryWithSubqueries:arr], @"not check className");
    XCTAssertThrows([AVQuery andQueryWithSubqueries:arr], @"not check className");
#endif
}

-(void)testANDQuery{
    
    NSString *USER_NAME_FIELD=@"username";
    NSString *boolField = @"BoolField";
    NSString *arrayF = @"ArrayF";
    
    NSString *unamePrefix = NSStringFromSelector(_cmd);
    
    AVUser *user = [AVUser user];
    user.username = [NSString stringWithFormat:@"%@1", unamePrefix];
    user.password = @"123456";
    [user setObject:[NSNumber numberWithBool:NO] forKey:boolField];
    [user signUp:nil];
    [self addDeleteObject:user];
    
    user = [AVUser user];
    user.username = [NSString stringWithFormat:@"%@2", unamePrefix];
    user.password = @"123456";
    [user setObject:[NSNumber numberWithBool:YES] forKey:boolField];
    [user setObject:@[[NSString stringWithFormat:@"%@1", unamePrefix], [NSString stringWithFormat:@"%@2", unamePrefix]] forKey:arrayF];
    [user signUp:nil];
    [self addDeleteObject:user];
    
    user = [AVUser user];
    user.username = [NSString stringWithFormat:@"test2"];
    user.password = @"123456";
    [user setObject:[NSNumber numberWithBool:YES] forKey:boolField];
    [user setObject:@[[NSString stringWithFormat:@"%@1", unamePrefix], [NSString stringWithFormat:@"%@2", unamePrefix]] forKey:arrayF];
    [user signUp:nil];
    [self addDeleteObject:user];
    
    [AVUser logInWithUsername:[NSString stringWithFormat:@"%@2", unamePrefix] password:@"123456" error:nil];
    
//    AVQuery *inQuery = [AVUser query];
//    [inQuery whereKey:boolField equalTo:[NSNumber numberWithBool:NO]];
    
    AVQuery *query1 = [AVUser query];
    [query1 whereKey:USER_NAME_FIELD containedIn:[[AVUser currentUser]objectForKey:arrayF] ];

    AVQuery *query2 = [AVUser query];
    
    //服务器对AND操作时 对notMatch返回错误
    //[query2 whereKey:USER_NAME_FIELD doesNotMatchKey:USER_NAME_FIELD inQuery:inQuery];
    [query2 whereKey:USER_NAME_FIELD hasPrefix:[NSString stringWithFormat:@"%@", unamePrefix]];
    
    AVQuery *andQuery= [AVQuery andQueryWithSubqueries:@[query2]];
    
    [andQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertGreaterThan([objects count], 0, "result count should large than 0");
        for(AVUser *i in objects) {
            NSLog(@"username: %@\n", i.username);
        }
        NOTIFY;
    }];
    
    WAIT;
}

-(void)testMultiRequestFromOneQueryObject{
    NSString * className = NSStringFromClass([self class]);
    NSError *err=nil;
    AVObject *obj1=[AVObject objectWithClassName:className];
    [obj1 setObject:@"test" forKey:@"data"];
    XCTAssertTrue([obj1 save:&err], @"save fail:%@",[err description]);
    [self addDeleteObject:obj1];
    AVObject *obj2=[AVObject objectWithClassName:className];
    [obj2 setObject:obj1 forKey:@"child"];
    XCTAssertTrue([obj2 save:&err], @"save fail:%@",[err description]);
    [self addDeleteObject:obj2];
    
    AVObject *object=[AVObject objectWithoutDataWithClassName:className objectId:obj2.objectId];
    [object fetchIfNeeded];
    
    AVRelation *postRel=[object relationforKey:@"child"];
    
    AVQuery *q=[postRel query];
    
    NSInteger count= [q countObjects];
    
    NSArray *rels=[q findObjects:&err];
    
    XCTAssertEqual(rels.count,count,@"关联数量不相等");
}

-(void)testAddAscendingOrder {
    NSString * className = NSStringFromClass([self class]);
    NSError * error = nil;
    int max = 15;
    for(int i = 0; i < max; ++i) {
        AVObject * object = [AVObject objectWithClassName:className];
        [object setObject:@((i + 3) % max) forKey:@"score"];
        XCTAssertTrue([object save:&error], @"error %@", error);
        [self addDeleteObject:object];
    }
    
    AVQuery *q=[AVQuery queryWithClassName:className];
    [q orderByDescending:@"score"];
    [q addDescendingOrder:@"createdAt"];
    [q setLimit:5];
    NSArray *objs= [q findObjects];
    XCTAssertEqual(objs.count, q.limit, @"query fail");
    AVObject *object = [objs objectAtIndex:0];
    XCTAssertEqual(max-1, [[object objectForKey:@"score"] intValue], @"first object score should the largest one");
}

-(void)testOrderBySortDescriptors {
    NSString * className = NSStringFromClass([self class]);
    NSError * error = nil;
    NSInteger max = 15;
    for(NSInteger i = 0; i < max; ++i) {
        AVObject * object = [AVObject objectWithClassName:className];
        [object setObject:@((i + 3) % max) forKey:@"score"];
        XCTAssertTrue([object save:&error], @"error %@", error);
        [self addDeleteObject:object];
    }
    
    AVQuery *q=[AVQuery queryWithClassName:className];
    [q orderBySortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"score" ascending:NO],
                                [NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]
                                ]];
    [q setLimit:3];
    NSArray *objs= [q findObjects];
    XCTAssertGreaterThan(objs.count, 0, @"query fail");
    AVObject *object = [objs objectAtIndex:0];
    XCTAssertEqual(max-1, [[object objectForKey:@"score"] intValue], @"first object score should the largest one");
}

-(void)testCountSizeEqual{
    NSString * className = NSStringFromClass([self class]);
    NSString *fieldName = NSStringFromSelector(_cmd);
    AVObject *gs=[AVObject objectWithClassName:className];
    [gs setObject:@[@"Travis",@"Someone"] forKey:fieldName];
    [gs save];
    [self addDeleteObject:gs];
    
    gs=[AVObject objectWithClassName:className];
    [gs setObject:@[@"Travis",@"Someone",@"OOKK"] forKey:fieldName];
    [gs save];
    [self addDeleteObject:gs];
    
    AVQuery *q=[AVQuery queryWithClassName:className];
    
    [q whereKey:fieldName sizeEqualTo:3];
    AVObject *ret= [q getFirstObject];
    XCTAssertEqual([[ret objectForKey:fieldName] count], 3, @"query fail");
    
    q=[AVQuery queryWithClassName:className];
    [q whereKey:fieldName sizeEqualTo:2];
    ret= [q getFirstObject];
    XCTAssertEqual([[ret objectForKey:fieldName] count], 2, @"query fail");
}

-(void)testMultipleQueryConditions{
    NSString * className = NSStringFromClass([self class]);
    NSError * error = nil;
    int max = 10;
    NSDate *firstDate = nil;
    NSDate *lastDate = nil;
    for(int i = 0; i < max; ++i) {
        AVObject * object = [AVObject objectWithClassName:className];
        [object setObject:@((i + 3) % max) forKey:@"score"];
        int k = arc4random() % 4;
        if (k == 0) {
            [object setObject:@"yyy" forKey:@"5678"];
        } else if (k == 1) {
            [object setObject:@"xxxyyy" forKey:@"5678"];
        } else if (k == 2) {
            [object setObject:@"aaabbba" forKey:@"5678"];
        }
        k = arc4random() % 3;
        if (k == 0) {
            [object setObject:@"yyy" forKey:@"content"];
        } else if (k == 1) {
            [object setObject:@"assddd" forKey:@"content"];
        }
        if (i == 6) {
            [object setObject:@"xxxyyy" forKey:@"5678"];
            [object setObject:@"yyy" forKey:@"content"];
        }
        XCTAssertTrue([object save:&error], @"error %@", error);
        if (i == 0) {
            firstDate = object.createdAt;
        } else if (i == max - 1) {
            lastDate = object.createdAt;
        }
        [self addDeleteObject:object];
    }
//    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
//    [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSS'Z'"];
//    NSDate *lastDate = [dateFormatter dateFromString:@"2014-04-15T11:02:42.245Z"];
//    NSDate *nextDate = [dateFormatter dateFromString:@"2014-04-30T11:02:42.245Z"];

    AVQuery *query1 = [AVQuery queryWithClassName:className];
    [query1 whereKey:@"createdAt" greaterThan:firstDate];
    NSArray *objects1 = [query1 findObjects];
    
    AVQuery *query2 = [AVQuery queryWithClassName:className];
    [query2 whereKey:@"createdAt" greaterThan:firstDate];
    [query2 whereKey:@"createdAt" lessThan:lastDate];
    [query2 whereKey:@"5678" equalTo:@"xxxyyy"];
    [query2 whereKey:@"content" equalTo:@"yyy"];

    
    NSArray *objects2 = [query2 findObjects];

    XCTAssertTrue(objects1.count > objects2.count, @"query fail");
}

- (void)testQueryWithAVObject {
    NSString * className = NSStringFromClass([self class]);
    NSError * error = nil;
    AVObject * objectSub = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_sub", className]];

    AVObject * object = [AVObject objectWithClassName:className];
    [object setObject:objectSub forKey:@"sub"];
    [object save:&error];
    [self addDeleteObject:objectSub];
    [self addDeleteObject:object];
    XCTAssertNil(error, @"%@", error);
    AVQuery* query = [AVQuery queryWithClassName:className];
    [query whereKey:@"sub" equalTo:objectSub];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertNil(error, @"%@", error);
        XCTAssertGreaterThan(objects.count, 0, @"objects count should greater than 0");
    }];
}

- (void)testCloudQuery {
    NSString * className = NSStringFromClass([self class]);
    NSError * error = nil;
    AVUser *user = [[AVUser alloc] init];
    user.username = className;
    user.password = @"123456";
    [user signUp];
    [self addDeleteObject:user];
    int max = 15;
    for(int i = 0; i < max; ++i) {
        AVObject * object = [AVObject objectWithClassName:className];
        [object setObject:@((i + 3) % max) forKey:@"score"];
//        if (i == 6) {
//            AVACL *acl = [AVACL ACLWithUser:[AVUser currentUser]];
//            [acl setPublicReadAccess:NO];
//            [acl setReadAccess:YES forUser:[AVUser currentUser]];
//            [object setACL:acl];
//        }
        XCTAssertTrue([object save:&error], @"error %@", error);
        [self addDeleteObject:object];
    }
    [AVUser logOut];
    NSString *cql = [NSString stringWithFormat:@"select * from %@", className];
    AVCloudQueryResult *result = [AVQuery doCloudQueryWithCQL:cql error:&error];
    XCTAssertGreaterThanOrEqual(result.results.count, max, @"result count mismatch");
    
    cql = [NSString stringWithFormat:@"select count(*) from %@", className];
    result = [AVQuery doCloudQueryWithCQL:cql error:&error];
    XCTAssertGreaterThanOrEqual(result.count, max, @"result count mismatch");

    cql = [NSString stringWithFormat:@"select score from %@", className];
    result = [AVQuery doCloudQueryWithCQL:cql error:&error];
    XCTAssertGreaterThanOrEqual(result.results.count, max, @"result count mismatch");

    cql = [NSString stringWithFormat:@"select a from %@", @"_User"];
    result = [AVQuery doCloudQueryWithCQL:cql error:&error];
    XCTAssertGreaterThanOrEqual(result.results.count, 1, @"result count mismatch");

    cql = [NSString stringWithFormat:@"select * from %@", className];
    [AVQuery doCloudQueryInBackgroundWithCQL:cql callback:^(AVCloudQueryResult *result, NSError *error) {
        if (!error) {
            XCTAssertGreaterThanOrEqual(result.results.count, max, @"result count mismatch");
        } else {
            NSLog(@"error:%@", error);
        }
        NOTIFY;
    }];
    WAIT;
}

- (void)testCloudQueryWithPvalues {
    NSString * className = NSStringFromClass([self class]);
    NSError * error = nil;
    int max = 15;
    for(int i = 0; i < max; ++i) {
        AVObject * object = [AVObject objectWithClassName:className];
        [object setObject:@((i + 3) % max) forKey:@"score"];
        //        if (i == 6) {
        //            AVACL *acl = [AVACL ACLWithUser:[AVUser currentUser]];
        //            [acl setPublicReadAccess:NO];
        //            [acl setReadAccess:YES forUser:[AVUser currentUser]];
        //            [object setACL:acl];
        //        }
        XCTAssertTrue([object save:&error], @"error %@", error);
        [self addDeleteObject:object];
    }
    NSString *cql = [NSString stringWithFormat:@"select * from %@ where score>?", className];
    AVCloudQueryResult *result = [AVQuery doCloudQueryWithCQL:cql pvalues:@[@5] error:&error];
    XCTAssertGreaterThanOrEqual(result.results.count, 0, @"result count mismatch");

    [AVQuery doCloudQueryInBackgroundWithCQL:cql pvalues:@[@5] callback:^(AVCloudQueryResult *result, NSError *error) {
        if (!error) {
            XCTAssertGreaterThanOrEqual(result.results.count, 0, @"result count mismatch");
        } else {
            NSLog(@"error:%@", error);
        }
        NOTIFY;
    }];
    WAIT;
}

@end
