//
//  AVUserTest.m
//  paas
//
//  Created by Travis on 14-3-6.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import "AVTestBase.h"
#import "AVPaasClient.h"
#import "AVCustomUser.h"

@interface XXUser : AVUser<AVSubclassing>

@property (nonatomic, assign) int age;

@end


@implementation XXUser

@dynamic age;

@end

@interface TestUser : AVUser
@property (nonatomic, strong) NSString *testAttr;
@end
@implementation TestUser

- (void)setTestAttr:(NSString *)testAttr {
    [self setObject:testAttr forKey:@"_testAttr"];
}

- (NSString *)testAttr {
    return [self objectForKey:@"_testAttr"];
}

@end
@interface AVUserTest : AVTestBase

@end

@implementation AVUserTest

- (void)testCurrentUser {
    NSError *error = nil;
    {
        [AVUser logOut];
        AVUser *user = [AVUser currentUser];
        XCTAssertNil(user);
    }
    {
        AVUser *user = [AVUser user];
        user.username = @"testCurrentUser";
        user.password = @"111111";
        [user signUp:&error];
        user = [AVUser currentUser];
        XCTAssertNotNil(user);
        [self addDeleteObject:user];
    }
}

-(void)testSignUp{
    [self deleteUserWithUsername:@"testSignUp" password:@"111111"];
    
    AVUser *user=[AVUser user];
    user.email=[NSString stringWithFormat:@"%ld@qq.com", (long)arc4random()];
    user.username=@"testSignUp";
    user.password=@"111111";
    [user setObject:@"bio" forKey:@"helloworld"];
    NSError *err=nil;
    [user signUp:&err];
    [self addDeleteObject:user];
    //XCTestAssertNil(err,@"%@",err);
    XCTAssertNil(err,@"%@",err);
}

-(void)testEmailVerify{
    [self deleteUserWithUsername:NSStringFromSelector(_cmd) password:@"111111"];
    
    AVUser *user=[AVUser user];
    user.email=@"651142978@qq.com";
    user.username=NSStringFromSelector(_cmd);
    user.password=@"111111";
    NSError *err=nil;
    [user signUp:&err];
    XCTAssertNil(err);
    [self addDeleteObject:user];
    
    // 需要启用邮箱验证
    [AVUser requestEmailVerify:@"651142978@qq.com" withBlock:^(BOOL succeeded, NSError *err) {
        if (err && err.code!=kAVErrorUserWithEmailNotFound && err.code != kAVErrorInternalServer) {
            NSLog(@"%@",err);
            [self notify:XCTAsyncTestCaseStatusFailed];
        } else {
            [self notify:XCTAsyncTestCaseStatusSucceeded];
        }
        
    }];
    WAIT_10;
}

//FIXME:Test Fails
- (void)testUserWithFile {
    [self deleteUserWithUsername:NSStringFromSelector(_cmd) password:@"123456"];
    
    AVUser *user=[AVUser user];
    user.email=@"test1111@qq.com";
    user.username=NSStringFromSelector(_cmd);
    user.password=@"123456";
    NSError *err=nil;
    [user signUp:&err];
    [self addDeleteObject:user];
    XCTAssertNil(err, @"%@", err);
    
    AVFile *file = [AVFile fileWithData:[[NSString stringWithFormat:@"%@", NSStringFromSelector(_cmd)] dataUsingEncoding:NSUTF8StringEncoding]];
    [[AVUser currentUser] setObject:file forKey:NSStringFromSelector(_cmd)];
    err = nil;
    [[AVUser currentUser] save:&err];
    [self addDeleteFile:file];
    XCTAssertNil(err, @"%@", err);
    user = [AVUser logInWithUsername:NSStringFromSelector(_cmd) password:@"123456"];
    [[AVUser currentUser] setObject:file forKey:NSStringFromSelector(_cmd)];
    err = nil;
    [[AVUser currentUser] save:&err];
    XCTAssertNil(err, @"%@", err);
    NSString *filePath=[[NSBundle bundleForClass:[self class]] pathForResource:@"alpacino" ofType:@"jpg"];
    AVFile *fileLarge = [AVFile fileWithName:@"alpacino.jpg" contentsAtPath:filePath];
    [fileLarge save:&err];
    XCTAssertNil(err, @"%@", err);
    [self addDeleteFile:fileLarge];
    [[AVUser currentUser] setObject:file forKey:NSStringFromSelector(_cmd)];
    [[AVUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error, @"%@", error);
        NOTIFY;
    }];
    WAIT;
}

- (void)testSignUpUserWithFile {
    
    AVFile *file = [AVFile fileWithData:[[NSString stringWithFormat:@"%@", NSStringFromSelector(_cmd)] dataUsingEncoding:NSUTF8StringEncoding]];
    AVUser *user=[AVUser user];
    user.email=@"test@qq.com";
    user.username=NSStringFromSelector(_cmd);
    user.password=@"123456";
    [user setObject:file forKey:NSStringFromSelector(_cmd)];
    NSError *err=nil;
    [user signUp:&err];
    [self addDeleteFile:file];
    [self addDeleteObject:user];
    XCTAssertNil(err, @"%@", err);
    //    [[AVUser currentUser] setObject:file forKey:NSStringFromSelector(_cmd)];
    //    NSError *err = nil;
    //    [[AVUser currentUser] save:&err];
    //    XCTAssertNil(err, @"%@", err);
}

- (void)testUpdatePassword {
    NSError *error = nil;
    AVUser *user=[AVUser user];
    user.username=NSStringFromSelector(_cmd);
    user.password=@"111111";
    XCTAssertTrue([user signUp:&error], @"%@", error);
    //    [AVUser logInWithUsername:@"username" password:@"password"];
    [user updatePassword:@"111111" newPassword:@"123456" withTarget:self selector:@selector(passwordUpdated:error:)];
    user.password=@"123456";
    [self addDeleteObject:user];
    WAIT;
}

- (void)passwordUpdated:(AVObject *)object error:(NSError *)error {
    XCTAssertNil(error, @"%@", error);
    NOTIFY;
}

- (void)testUpdatePassword2 {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd)];
    [user updatePassword:@"111111" newPassword:@"123456" block:^(id object, NSError *error) {
        XCTAssertNil(error, @"%@", error);
        XCTAssertEqual(object, user);
        XCTAssertEqual(object,[AVUser currentUser]);
        
        // check sessionToken
        user.username = @"afterUpdatePassword";
        NSError *theError;
        [user save:&theError];
        XCTAssertNil(theError);
        
        NOTIFY;
    }];
    WAIT;
    user.password=@"123456"; // to login and delete it
    [self addDeleteObject:user];
}

- (void)testSubClass {
    NSError *error = nil;
    TestUser *user=[TestUser user];
    user.username=NSStringFromSelector(_cmd);
    user.password=@"111111";
    user.testAttr=@"test";
    //    XCTAssertTrue([user signUp:&error], @"%@", error);
    [user signUpInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"%@", error);
        NSLog(@"%@", user.testAttr);
        NOTIFY;
    }];
    [self addDeleteObject:user];
    WAIT;
}

- (void)testAnonymousUser {
    [AVAnonymousUtils logInWithBlock:^(AVUser *user, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(user);
        XCTAssertNotNil(user.username);
        NOTIFY;
    }];
    WAIT;
}

- (void)testUsernameWithChinese {
    AVUser *user=[AVUser user];
    user.email=@"abcgf@qq.com";
    user.username=@"测试账户";
    user.password=@"111111";
    [user setObject:@"你好" forKey:@"abc"];
    NSError *err=nil;
    [user signUp:&err];
    [self addDeleteObject:user];
    //XCTestAssertNil(err,@"%@",err);
    XCTAssertNil(err,@"%@",err);
    AVQuery * query = [AVUser query];
    AVObject *obj = [query getObjectWithId:user.objectId];
    NSLog(@"%@", [obj objectForKey:@"username"]);
    [query whereKey:@"objectId" equalTo:user.objectId];
    NSArray* users=[query findObjects];
    for (AVUser *usr in users) {
        NSLog(@"%@", usr.username);
    }
    
}

- (void)testFollowerQueryClassName {
    AVUser *user=[AVUser user];
    user.email=@"etrtdgf@qq.com";
    user.username=NSStringFromSelector(_cmd);
    user.password=@"111111";
    [user setObject:@"你好" forKey:@"abc"];
    NSError *err=nil;
    [user signUp:&err];
    [self addDeleteObject:user];
    AVQuery *query = [AVQuery orQueryWithSubqueries:@[[AVUser currentUser].followerQuery]];
    [query findObjects];
}

- (void)testBecomeWithSessionToken {
    AVUser *user = [self registerOrLoginWithUsername:@"testBecome"];
    
    AVUser *otherUser = [self registerOrLoginWithUsername:@"testBecome1"];
    
    NSString *sessionToken = user.sessionToken;
    XCTAssertNotNil(sessionToken);
    
    [AVUser becomeWithSessionTokenInBackground:sessionToken block:^(AVUser *newUser, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(newUser);
        XCTAssertEqualObjects(newUser.sessionToken, sessionToken);
        XCTAssertEqualObjects(newUser.createdAt, user.createdAt);
        XCTAssertEqualObjects(newUser.objectId, user.objectId);
        NOTIFY;
    }];
    WAIT;
    
    AVUser *currentUser = [AVUser currentUser];
    XCTAssertEqualObjects(user.objectId, currentUser.objectId);
    XCTAssertEqualObjects(user.createdAt, currentUser.createdAt);
    
    NSError *error;
    AVUser *loginUser = [AVUser becomeWithSessionToken:otherUser.sessionToken error:&error];
    XCTAssertEqualObjects(loginUser.objectId, otherUser.objectId);
    
    XCTAssertNil(error);
    //    [self addDeleteObject:user];
}

- (void)testSubclassAVUser {
    // 如果下面这个语句删掉，就会出现 https://github.com/leancloud/ios-sdk/issues/43 描述的问题。
    [AVCustomUser registerSubclass];
    
    AVCustomUser *user = [[AVCustomUser alloc] init];
    
    user.username = [@"foo" stringByAppendingFormat:@"%@", @(arc4random())];
    user.password = [@"bar" stringByAppendingFormat:@"%@", @(arc4random())];
    
    NSError *error = nil;
    [user signUp:&error];
    
    XCTAssert(!error, @"%@", error);
    
    AVQuery *query = [AVQuery queryWithClassName:@"_User"];
    
    [query whereKey:@"objectId" equalTo:user.objectId];
    NSArray *users = [query findObjects:&error];
    
    XCTAssert(!error, @"%@", error);
    
    id queriedUser = [users firstObject];
    
    XCTAssert(queriedUser != nil, @"%@", error);
    XCTAssert([queriedUser isKindOfClass:[AVCustomUser class]], @"AVQuery can not deserialize AVUser subclass");
}

-(void)testSubUser {
    [XXUser registerSubclass];
    XXUser *user2=[XXUser logInWithUsername:@"travis" password:@"123456"];
    
    XCTAssertEqual([user2 class], [XXUser class], @"AVUser子类返回错误");
    XCTAssertEqual([[XXUser currentUser] class], [XXUser class], @"AVUser子类返回错误");
}

- (void)testSubclassUserIngoreCurrentClass {
    [AVCustomUser registerSubclass];
    
    AVCustomUser *user = [[AVCustomUser alloc] init];
    user.username = [@"sex" stringByAppendingFormat:@"%@", @(arc4random())];
    user.password = [@"sexual" stringByAppendingFormat:@"%@", @(arc4random())];
    NSError *error = nil;
    [user signUp:&error];
    assertNil(error);
    
    AVUser *loginUser = [XXUser logInWithUsername:user.username password:user.password error:&error];
    assertNil(error);
    assertEqual([loginUser class], [AVCustomUser class]);
}

- (void)testUserSave {
    //Relation
    [AVUser logInWithUsername:@"travis" password:@"123456"];
    int racInt = arc4random_uniform(10);
    NSString *email = [NSString stringWithFormat:@"%@luohanchenyilong@163.com",@(racInt)];
    [AVUser currentUser].email = email;
    
    [[AVUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual( [AVUser currentUser].email, email);
        NOTIFY
    }];
    WAIT
    
    // relation测试
    AVQuery *query = [AVQuery queryWithClassName:@"AVRelationTest_Post"];
    [query getObjectInBackgroundWithId:@"568fd58ccbc2e8a30c525820" block:^(AVObject *object, NSError *error) {
        if (!error) {
            AVRelation *relation = [[AVUser currentUser] relationforKey:@"myLikes"];
            [relation addObject:object];
            [[AVUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                XCTAssertNil(error);
                NOTIFY
            }];
        }
    }];
    WAIT
    
    //Test for this forum ticket https://forum.leancloud.cn/t/avrelation/5616
    AVRelation *relation2 = [[AVUser currentUser] relationforKey:@"myLikes"];
    [[relation2 query] findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        BOOL isFinded = NO;
        for (AVObject *object in objects) {
            if ([object.objectId isEqualToString:@"568fd58ccbc2e8a30c525820"]) {
                isFinded = YES;
                break;
            }
        }
        XCTAssertEqual(isFinded, YES);
        NOTIFY
    }];
    WAIT
}

@end
