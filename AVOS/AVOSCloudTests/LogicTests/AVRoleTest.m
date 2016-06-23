//
//  AVRoleAPITest.m
//  AVOS
//
//  Created by Qihe Bian on 1/27/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVTestBase.h"
#import "AVRole_Internal.h"

@interface AVRoleTest : AVTestBase

@end

@implementation AVRoleTest

- (void)testInitWithName {
    NSString *rolename = @"testrole";
    AVRole *role = [[AVRole alloc] initWithName:rolename];
    XCTAssertNotNil(role);
    XCTAssertEqualObjects(rolename, role.name);
}

- (void)testInitWithName_acl {
    NSString *rolename = @"testrole";
    AVACL *acl = [AVACL ACL];
    AVRole *role = [[AVRole alloc] initWithName:rolename acl:acl];
    XCTAssertNotNil(role);
    XCTAssertEqualObjects(rolename, role.name);
//  origin version : XCTAssertEqualObjects(acl, role.ACL);
    XCTAssertEqualObjects(acl, role.acl);
}

- (void)testRoleWithName {
    NSString *rolename = @"testrole";
    AVRole *role = [AVRole roleWithName:rolename];
    XCTAssertNotNil(role);
    XCTAssertEqualObjects(rolename, role.name);
}

- (void)testRoleWithName_acl {
    NSString *rolename = @"testrole";
    AVACL *acl = [AVACL ACL];
    AVRole *role = [AVRole roleWithName:rolename acl:acl];
    XCTAssertNotNil(role);
    XCTAssertEqualObjects(rolename, role.name);
    XCTAssertEqualObjects(acl, role.acl);
}

- (void)testUsers {
    NSString *rolename = @"testrole";
    AVRole *role = [AVRole roleWithName:rolename];
    [role save];
    AVRelation *relation = [role users];
    XCTAssertNotNil(relation);
}

- (void)testRoles {
    NSString *rolename = @"testrole";
    AVRole *role = [AVRole roleWithName:rolename];
    [role save];
    AVRelation *relation = [role roles];
    XCTAssertNotNil(relation);
}

- (void)testQuery {
    AVQuery *query = [AVRole query];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertNil(error);
        NOTIFY;
    }];
    WAIT;
}

@end
