//
//  AVTestBase.m
//  AVOS
//
//  Created by Qihe Bian on 8/13/14.
//
//

#import "AVTestBase.h"
#import <objc/runtime.h>

#define AV_YEAR_SECONDS (86400 * 365)

static NSMutableArray *filesToDelete = nil;
static NSMutableArray *objectsToDelete = nil;
static NSMutableArray *statusToDelete = nil;
const void *AVTestBaseDeleteObjects = &AVTestBaseDeleteObjects;

@implementation AVTestBase

+(void)setUp {
    // 整个类测试时运行一次
    PREPARE
#ifdef DEBUG
    [AVOSCloud setAllLogsEnabled:true];
#endif
}

- (void)setUp {
    // 每个 test 单元测试都会运行
    filesToDelete = [[NSMutableArray alloc] init];
    objectsToDelete = [[NSMutableArray alloc] init];
    statusToDelete = [[NSMutableArray alloc] init];
}

- (void)tearDown {
    __block BOOL deleted1 = NO;
    __block BOOL deleted2 = NO;
    __block int count1 = (int)filesToDelete.count;
    if (count1 == 0) {
        deleted1 = YES;
    }
    for (AVFile *file in filesToDelete) {
        [file deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            --count1;
            if (count1 == 0) {
                deleted1 = YES;
            }
        }];
    }
    NSMutableArray *deleteObjects = [NSMutableArray array];
    for (AVObject *object in objectsToDelete) {
        if ([object isKindOfClass:[AVUser class]]) {
            AVUser *u = (AVUser *)object;
            AVUser *user = [AVUser logInWithUsername:u.username password:u.password error:nil];
            [user delete];
            continue;
        }
        [deleteObjects addObject:object];
    }
    
    if (deleteObjects.count > 0) {
        [AVObject deleteAll:deleteObjects];
    }
    
    __block int count2 = (int)[statusToDelete count];
    if (count2 == 0) {
        deleted2 = YES;
    }
    for (AVStatus *status in statusToDelete) {
        [AVStatus deleteStatusWithID:status.objectId andCallback:^(BOOL succeeded, NSError *error) {
            --count2;
            if (count2 == 0) {
                deleted2 = YES;
            }
        }];
    }

    NSDate *date = [NSDate date];
//    NSDate *dt = [NSDate dateWithTimeIntervalSinceNow:0.1];
    while ((!deleted1 || !deleted2) && [date timeIntervalSinceNow] > -30) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate distantFuture]];
        float t = [date timeIntervalSinceNow];
        NSLog(@"%f", t);
//        dt = [NSDate dateWithTimeIntervalSinceNow:0.1];
    }
}

+ (void)addDeleteFile:(AVFile *)file {
    [filesToDelete addObject:file];
}

+ (void)addDeleteObject:(AVObject *)object {
    [objectsToDelete addObject:object];
}

+ (void)addDeleteFiles:(NSArray *)files {
    [filesToDelete addObjectsFromArray:files];
}

+ (void)addDeleteObjects:(NSArray *)objects {
    [objectsToDelete addObjectsFromArray:objects];
}

- (void)addDeleteFile:(AVFile *)file {
    [filesToDelete addObject:file];
}

- (void)addDeleteObject:(AVObject *)object {
    [objectsToDelete addObject:object];
}

- (void)addDeleteFiles:(NSArray *)files {
    [filesToDelete addObjectsFromArray:files];
}

- (void)addDeleteObjects:(NSArray *)objects {
    [objectsToDelete addObjectsFromArray:objects];
}

+ (void)addDeleteStatus:(AVStatus *)status {
    [statusToDelete addObject:status];
}

- (void)addDeleteStatus:(AVStatus *)status {
    [statusToDelete addObject:status];
}

- (void)waitNotification:(const void *)notification {
    NSString *name = [NSString stringWithFormat:@"%p", notification];
    [self expectationForNotification:name object:nil handler:nil];
    [self waitForExpectationsWithTimeout:AV_YEAR_SECONDS handler:nil];
}

- (void)postNotification:(const void *)notification {
    NSString *name = [NSString stringWithFormat:@"%p", notification];
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:nil];
}

#pragma mark - utils


- (NSString *)className {
    return NSStringFromClass([self class]);
}

- (id)jsonWithFileName:(NSString *)name {
    NSURL *URL = [[NSBundle bundleForClass:[self class]] URLForResource:name withExtension:@"json"];
    NSString *content = [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:nil];
    XCTAssertNotNil(content);
    return [NSJSONSerialization JSONObjectWithData:[content dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

- (AVUser *)registerOrLoginWithUsername:(NSString *)username {
    return [self registerOrLoginWithUsername:username password:@"111111"];
}

- (AVUser *)registerOrLoginWithUsername:(NSString *)username password:(NSString *)password {
    NSError *loginError;
    AVUser *loginUser = [AVUser logInWithUsername:username password:password error:&loginError];
    if (loginError == nil) {
        return loginUser;
    } else if (loginError.code == kAVErrorUserNotFound) {
        AVUser *user = [AVUser user];
        user.username = username;
        user.password = password;
        NSError *error;
        [user signUp:&error];
        assertNil(error);
        return user;
    } else {
        [NSException raise:NSInternalInconsistencyException format:@"can not sign up or login"];
        return nil;
    }
}

// 避免注册失败
- (void)deleteUserWithUsername:(NSString *)username password:(NSString *)password {
    NSError *error;
    AVUser *loginUser = [AVUser logInWithUsername:username password:password error:&error];
    if (error == nil) {
        [loginUser delete:&error];
        XCTAssertNil(error);
    }
}

// AVUser will fail: "The user cannot be altered by a client without the session."
// 注意有 ACL 保护的对象可能找不到
+ (void)deleteClass:(NSString *)className {
    AVQuery *q = [AVQuery queryWithClassName:className];
    q.limit = 1000;
    NSArray *objects = [q findObjects];
    if (objects.count > 0) {
        NSError *error;
        [AVObject deleteAll:objects error:&error];
    }
}

@end