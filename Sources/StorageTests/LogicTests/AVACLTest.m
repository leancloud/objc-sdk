//
//  AVACLAPITest.m
//  AVOS
//
//  Created by Qihe Bian on 1/27/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVTestBase.h"
#import "AVPaasClient.h"

@interface AVACLTest : AVTestBase

@end

@implementation AVACLTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    [super tearDown];
    // 不影响其它测试
    [AVACL setDefaultACL:nil withAccessForCurrentUser:NO];
}

- (void)testACL {
    AVACL *acl = [AVACL ACL];
    XCTAssertNotNil(acl);
}

- (void)testACLWithUser {
    [AVTestUtil loginUserWithName:@"testacl"];
    AVACL *acl = [AVACL ACLWithUser:[AVUser currentUser]];
    XCTAssertNotNil(acl);
}

- (void)testSetPublicReadAccess {
    AVACL *acl = [AVACL ACL];
    [acl setPublicReadAccess:YES];
    XCTAssertTrue([acl getPublicReadAccess]);
}

- (void)testGetPublicReadAccess {
    AVACL *acl = [AVACL ACL];
    XCTAssertFalse([acl getPublicReadAccess]);
}

- (void)testSetPublicWriteAccess {
    AVACL *acl = [AVACL ACL];
    [acl setPublicWriteAccess:YES];
    XCTAssertTrue([acl getPublicWriteAccess]);
}

- (void)testGetPublicWriteAccess {
    AVACL *acl = [AVACL ACL];
    XCTAssertFalse([acl getPublicWriteAccess]);
}

- (void)testSetReadAccess_forUserId {
    [AVTestUtil loginUserWithName:@"testacl"];
    AVACL *acl = [AVACL ACL];
    NSString *userId = [AVUser currentUser].objectId;
    [acl setReadAccess:YES forUserId:userId];
    XCTAssertTrue([acl getReadAccessForUserId:userId]);
}

- (void)testGetReadAccessForUserId {
    [AVTestUtil loginUserWithName:@"testacl"];
    AVACL *acl = [AVACL ACL];
    NSString *userId = [AVUser currentUser].objectId;
    XCTAssertFalse([acl getReadAccessForUserId:userId]);
}

- (void)testSetWriteAccess_forUserId {
    [AVTestUtil loginUserWithName:@"testacl"];
    AVACL *acl = [AVACL ACL];
    NSString *userId = [AVUser currentUser].objectId;
    [acl setWriteAccess:YES forUserId:userId];
    XCTAssertTrue([acl getWriteAccessForUserId:userId]);
}

- (void)testGetWriteAccessForUserId {
    [AVTestUtil loginUserWithName:@"testacl"];
    AVACL *acl = [AVACL ACL];
    NSString *userId = [AVUser currentUser].objectId;
    XCTAssertFalse([acl getWriteAccessForUserId:userId]);
}

- (void)testSetReadAccess_forUser {
    [AVTestUtil loginUserWithName:@"testacl"];
    AVACL *acl = [AVACL ACL];
    AVUser *user = [AVUser currentUser];
    [acl setReadAccess:YES forUser:user];
    XCTAssertTrue([acl getReadAccessForUser:user]);
}

- (void)testGetReadAccessForUser {
    [AVTestUtil loginUserWithName:@"testacl"];
    AVACL *acl = [AVACL ACL];
    AVUser *user = [AVUser currentUser];
    XCTAssertFalse([acl getReadAccessForUser:user]);
}

- (void)testSetWriteAccess_forUser {
    [AVTestUtil loginUserWithName:@"testacl"];
    AVACL *acl = [AVACL ACL];
    AVUser *user = [AVUser currentUser];
    [acl setWriteAccess:YES forUser:user];
    XCTAssertTrue([acl getWriteAccessForUser:user]);
}

- (void)testGetWriteAccessForUser {
    [AVTestUtil loginUserWithName:@"testacl"];
    AVACL *acl = [AVACL ACL];
    AVUser *user = [AVUser currentUser];
    XCTAssertFalse([acl getWriteAccessForUser:user]);
}

- (void)testGetReadAccessForRoleWithName {
    NSString *rolename = @"testacl";
    AVACL *acl = [AVACL ACL];
    XCTAssertFalse([acl getReadAccessForRoleWithName:rolename]);
}

- (void)testSetReadAccess_forRoleWithName {
    NSString *rolename = @"testacl";
    AVACL *acl = [AVACL ACL];
    [acl setReadAccess:YES forRoleWithName:rolename];
    XCTAssertTrue([acl getReadAccessForRoleWithName:rolename]);
}

- (void)testGetWriteAccessForRoleWithName {
    NSString *rolename = @"testacl";
    AVACL *acl = [AVACL ACL];
    XCTAssertFalse([acl getWriteAccessForRoleWithName:rolename]);
}

- (void)testSetWriteAccess_forRoleWithName {
    NSString *rolename = @"testacl";
    AVACL *acl = [AVACL ACL];
    [acl setWriteAccess:YES forRoleWithName:rolename];
    XCTAssertTrue([acl getWriteAccessForRoleWithName:rolename]);
}

- (void)testGetReadAccessForRole {
    NSString *rolename = @"testacl";
    AVRole *role = [AVRole roleWithName:rolename];
    AVACL *acl = [AVACL ACL];
    XCTAssertFalse([acl getReadAccessForRole:role]);
}

- (void)testSetReadAccess_forRole {
    NSString *rolename = @"testacl";
    AVRole *role = [AVRole roleWithName:rolename];
    AVACL *acl = [AVACL ACL];
    [acl setReadAccess:YES forRole:role];
    XCTAssertTrue([acl getReadAccessForRole:role]);
}

- (void)testGetWriteAccessForRole {
    NSString *rolename = @"testacl";
    AVRole *role = [AVRole roleWithName:rolename];
    AVACL *acl = [AVACL ACL];
    XCTAssertFalse([acl getWriteAccessForRole:role]);
}

- (void)testSetWriteAccess_forRole {
    NSString *rolename = @"testacl";
    AVRole *role = [AVRole roleWithName:rolename];
    AVACL *acl = [AVACL ACL];
    [acl setWriteAccess:YES forRole:role];
    XCTAssertTrue([acl getWriteAccessForRole:role]);
}

- (void)testSetDefaultACL_withAccessForCurrentUser {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd)];
    AVACL *acl = [AVACL ACL];
    [AVACL setDefaultACL:acl withAccessForCurrentUser:YES];
    AVObject *object = [AVObject objectWithClassName:[self className]];
    [object setObject:NSStringFromSelector(_cmd) forKey:@"action"];
    NSError *error;
    [object save:&error];
    XCTAssertNil(error);
    
    AVACL *objectACL = [object ACL];
    XCTAssertNotNil(objectACL);
    XCTAssertTrue([objectACL getReadAccessForUser:user]);
    XCTAssertTrue([objectACL getWriteAccessForUser:user]);
    XCTAssertFalse([objectACL getPublicReadAccess]);
    XCTAssertFalse([objectACL getPublicWriteAccess]);
    
    [self addDeleteObject:object];
}

- (void)testSetDefaultACL_withAccessForCurrentUser_NotLogin {
    [AVUser logOut];
    AVACL *acl = [AVACL ACL];
    [acl setPublicReadAccess:YES];
    [acl setPublicWriteAccess:YES];
    [AVACL setDefaultACL:acl withAccessForCurrentUser:YES];
    AVObject *object = [AVObject objectWithClassName:[self className]];
    [object setObject:NSStringFromSelector(_cmd) forKey:@"action"];
    NSError *error;
    [object save:&error];
    XCTAssertNil(error);
    
    AVACL *objectACL = [object ACL];
    XCTAssertNotNil(objectACL);
    XCTAssertTrue([objectACL getPublicReadAccess]);
    XCTAssertTrue([objectACL getPublicWriteAccess]);
    
    [self addDeleteObject:object];
}

- (void)testSetDefaultACLButNotSetAccessForCurrentUser {
    AVACL *acl = [AVACL ACL];
    [acl setPublicReadAccess:YES];
    [acl setPublicWriteAccess:NO];
    [AVACL setDefaultACL:acl withAccessForCurrentUser:NO];
    
    AVACL *defaultACL = [AVPaasClient sharedInstance].updatedDefaultACL;
    XCTAssertTrue([defaultACL getPublicReadAccess]);
    XCTAssertFalse([defaultACL getPublicWriteAccess]);
}

- (void)checkACLForFile:(AVFile *)file {
    // 这里因为不使用 master key 的话，服务器不返回 ACL 字段，只能验证能不能找到
    NSError *error;
    AVQuery *query = [AVQuery queryWithClassName:@"_File"];
    [query whereKey:@"objectId" equalTo:file.objectId];
    NSInteger count1 = [query countObjects:&error];
    XCTAssertNil(error);
    XCTAssertEqual(count1, 1);
    
    [AVUser logOut];

    NSInteger count2 = [query countObjects:&error];
    XCTAssertNil(error);
    XCTAssertEqual(count2, 0);
}

- (void)testFileACL {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd)];
    AVACL *acl = [AVACL ACLWithUser:user];
    AVFile *file = [AVFile fileWithName:NSStringFromSelector(_cmd) data:[@"test" dataUsingEncoding:NSUTF8StringEncoding]];
    file.ACL = acl;
    NSError *error;
    [file save:&error];
    XCTAssertNil(error);
    XCTAssertEqual(file.ACL, acl);
    [self checkACLForFile:file];
}

- (void)testDefaultACLWithFile {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd)];
    AVACL *acl = [AVACL ACL];
    [AVACL setDefaultACL:acl withAccessForCurrentUser:YES];
    
    AVFile *file = [AVFile fileWithName:NSStringFromSelector(_cmd) data:[@"test" dataUsingEncoding:NSUTF8StringEncoding]];
    NSError *error;
    [file save:&error];
    XCTAssertNil(error);
    XCTAssertTrue([file.ACL getReadAccessForUser:user]);
    XCTAssertTrue([file.ACL getWriteAccessForUser:user]);
    XCTAssertFalse([file.ACL getPublicReadAccess]);
    XCTAssertFalse([file.ACL getPublicWriteAccess]);
    [self checkACLForFile:file];
}

- (void)testACLForFileCreatedByUrl {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd)];
    AVACL *acl = [AVACL ACL];
    [acl setReadAccess:YES forUser:user];
    AVFile *file = [AVFile fileWithURL:@"https://avatars2.githubusercontent.com/u/5022872?v=3&s=460"];
    file.ACL = acl;
    NSError *error;
    [file save:&error];
    XCTAssertNil(error);
    XCTAssertEqual(file.ACL, acl);
    [self checkACLForFile:file];
}

- (void)testDefaultACLWhenChangeUser {
    AVACL *acl = [AVACL ACL];
    [AVACL setDefaultACL:acl withAccessForCurrentUser:YES];
    
    AVUser *user1 = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd)];
    AVACL *defaultACL1 = [AVPaasClient sharedInstance].updatedDefaultACL;
    XCTAssertFalse([defaultACL1 getPublicWriteAccess]);
    XCTAssertFalse([defaultACL1 getPublicReadAccess]);
    XCTAssertTrue([defaultACL1 getReadAccessForUser:user1]);
    XCTAssertTrue([defaultACL1 getWriteAccessForUser:user1]);
    
    AVUser *user2 = [self registerOrLoginWithUsername:[[NSString alloc] initWithFormat:@"%@_1", NSStringFromSelector(_cmd)]];
    AVACL *defaultACL2 = [AVPaasClient sharedInstance].updatedDefaultACL;
    XCTAssertFalse([defaultACL2 getPublicWriteAccess]);
    XCTAssertFalse([defaultACL2 getPublicReadAccess]);
    XCTAssertFalse([defaultACL2 getReadAccessForUser:user1]);
    XCTAssertFalse([defaultACL2 getWriteAccessForUser:user1]);
    XCTAssertTrue([defaultACL2 getReadAccessForUser:user2]);
    XCTAssertTrue([defaultACL2 getWriteAccessForUser:user2]);
    
    [AVUser logOut];
    AVACL *defaultACL3 = [AVPaasClient sharedInstance].updatedDefaultACL;
    XCTAssertFalse([defaultACL3 getPublicWriteAccess]);
    XCTAssertFalse([defaultACL3 getPublicReadAccess]);
    XCTAssertFalse([defaultACL3 getReadAccessForUser:user1]);
    XCTAssertFalse([defaultACL3 getWriteAccessForUser:user1]);
    XCTAssertFalse([defaultACL3 getReadAccessForUser:user2]);
    XCTAssertFalse([defaultACL3 getWriteAccessForUser:user2]);
}

@end
