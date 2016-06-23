//
//  AVIMConversationTest.m
//  AVOS
//
//  Created by lzw on 15/7/6.
//  Copyright (c) 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVIMTestBase.h"
#import "LCIMConversationCacheStore.h"

@interface AVIMConversationTest : AVIMTestBase

@property (nonatomic, strong) AVIMConversation *conversation;

@end

@implementation AVIMConversationTest

- (void)setUp {
    [super setUp];
    [self openClientForTest];
    self.conversation = [self queryConversationById:AVIM_TEST_ConversationID];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testCreate {
    NSString *name = NSStringFromSelector(_cmd);
    [[AVIMClient defaultClient] createConversationWithName:name clientIds:@[AVIM_TEST_ClinetID_Peer] attributes:@{@"type": @0} options:AVIMConversationOptionNone callback:^(AVIMConversation *conversation, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(conversation.name, name);
        XCTAssertEqual(conversation.members.count, 2);
        XCTAssertTrue([conversation.members containsObject:AVIM_TEST_ClinetID]);
        XCTAssertTrue([conversation.members containsObject:AVIM_TEST_ClinetID_Peer]);
        XCTAssertEqual([conversation.attributes[@"type"] intValue], 0);
        XCTAssertEqualObjects(conversation.creator, AVIM_TEST_ClinetID);
        XCTAssertNotNil(conversation.createAt);
        XCTAssertNotNil(conversation.conversationId);
        XCTAssertFalse(conversation.muted);
        XCTAssertFalse(conversation.transient);
        NOTIFY;
    }];
    WAIT;
}

- (void)testQueryByConversationId {
    // test created conversation by above test
    __block NSString *convid;
    NSString *name = NSStringFromSelector(_cmd);
    [[AVIMClient defaultClient] createConversationWithName:name clientIds:@[ AVIM_TEST_ClinetID_Peer ] attributes:@{@"type": @0} options:AVIMConversationOptionNone callback:^(AVIMConversation *conversation, NSError *error) {
        XCTAssertNil(error);
        convid = conversation.conversationId;
        NOTIFY;
    }];
    WAIT;
    AVIMConversationQuery *query = [[AVIMClient defaultClient] conversationQuery];
    [query getConversationById:convid callback:^(AVIMConversation *conversation, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(conversation.name, name);
        XCTAssertEqual(conversation.members.count, 2);
        XCTAssertTrue([conversation.members containsObject:AVIM_TEST_ClinetID]);
        XCTAssertTrue([conversation.members containsObject:AVIM_TEST_ClinetID_Peer]);
        XCTAssertEqual([conversation.attributes[@"type"] intValue], 0);
        XCTAssertEqualObjects(conversation.creator, AVIM_TEST_ClinetID);
        XCTAssertNotNil(conversation.createAt);
        XCTAssertNotNil(conversation.conversationId);
        XCTAssertFalse(conversation.muted);
        XCTAssertFalse(conversation.transient);
        NOTIFY;
    }];
    WAIT;
}

//FIXME:TEST FAILED ==> ALL XCTAssertNil FAILED
//AVIMConvCommand should has cid
- (void)testUpdateConversation {
    AVIMConversation *conversation = [self conversationForTest];
    AVIMConversationUpdateBuilder *builder = [[AVIMConversationUpdateBuilder alloc] init];
    NSString *name = NSStringFromSelector(_cmd);
    builder.name = name;
    builder.attributes = @{@"address":@"kunshan"};
    [conversation update:[builder dictionary] callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(conversation.name, name);
        XCTAssertEqualObjects(conversation.attributes[@"address"], @"kunshan");
        NOTIFY;
    }];
    WAIT;
    
    AVIMConversationUpdateBuilder *builder2 = [[AVIMConversationUpdateBuilder alloc] init];
    [builder2 setObject:@"ShangHai" forKey:@"address"];
    [conversation update:[builder2 dictionary] callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(conversation.name, name);
        XCTAssertEqualObjects(conversation.attributes[@"address"], @"ShangHai");
        NOTIFY;
    }];
    WAIT;
}

- (void)testConversationMembersUpdate {
    __weak AVIMConversation *conversation = [self conversationForTest];
    [conversation addMembersWithClientIds:@[ AVIM_TEST_ClinetID_Peer_1 ] callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertTrue([conversation.members containsObject:AVIM_TEST_ClinetID_Peer_1]);
        NOTIFY;
    }];
    WAIT;
    
    [conversation removeMembersWithClientIds:@[AVIM_TEST_ClinetID_Peer_1] callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertFalse([conversation.members containsObject:AVIM_TEST_ClinetID_Peer_1]);
        NOTIFY;
    }];
    WAIT;
    
    XCTAssertTrue([conversation.members containsObject:AVIM_TEST_ClinetID]);
    [conversation quitWithCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertFalse([conversation.members containsObject:AVIM_TEST_ClinetID]);
        NOTIFY;
    }];
    WAIT;
    
    [conversation joinWithCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertTrue([conversation.members containsObject:AVIM_TEST_ClinetID]);
        NOTIFY;
    }];
    WAIT;
}


- (void)testMute {
    [self.conversation muteWithCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertTrue(self.conversation.muted);
        NOTIFY;
    }];
    WAIT;
    
    [self.conversation unmuteWithCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertFalse(self.conversation.muted);
        NOTIFY;
    }];
    WAIT;
}

- (void)testCountMembers {
    [self.conversation countMembersWithCallback:^(NSInteger number, NSError *error) {
        XCTAssertEqual(number, 2);
        NOTIFY;
    }];
    WAIT;
}

- (NSMutableSet *)conversationIdsFromConversations:(NSArray *)conversations {
    NSMutableSet *conversationIds = [NSMutableSet set];

    for (AVIMConversation *conversation in conversations) {
        [conversationIds addObject:conversation.conversationId];
    }

    return conversationIds;
}

- (void)testConversationQueryCache {
    const void *notification = &notification;

    AVIMConversationQuery *query = [[AVIMClient defaultClient] conversationQuery];
    query.limit = 10;

    [query findConversationsWithCallback:^(NSArray *conversations, NSError *error) {

        LCIMConversationCacheStore *cacheStore = [[LCIMConversationCacheStore alloc] initWithClientId:[AVIMClient defaultClient].clientId];
        NSArray *cachedConversations = [cacheStore allAliveConversations];

        NSSet *conversationIds = [self conversationIdsFromConversations:conversations];
        NSSet *cachedConversationIds = [self conversationIdsFromConversations:cachedConversations];

        XCTAssert([conversationIds isSubsetOfSet:cachedConversationIds], @"No cached conversations for conversation query");

        [self postNotification:notification];
    }];

    [self waitNotification:notification];
}

- (void)testConversationForId {
    AVIMConversationQuery *query = [[AVIMClient defaultClient] conversationQuery];
    query.cachePolicy = kAVCachePolicyCacheElseNetwork;
    [query findConversationsWithCallback:^(NSArray *objects, NSError *error) {
        XCTAssertNil(error);
        
        for (AVIMConversation *conversation in objects) {
            XCTAssertNotNil(conversation);
            XCTAssertNotNil([[AVIMClient defaultClient] conversationForId:conversation.conversationId]);
        }
        NOTIFY
    }];
    WAIT
}

- (void)testConversationQueryDate {
    AVIMConversationQuery *query = [[AVIMClient defaultClient] conversationQuery];
    query.cachePolicy = kAVCachePolicyNetworkOnly;
    NSDate *date = [NSDate date];
    [query whereKey:@"createdAt" lessThan:date];
    [query findConversationsWithCallback:^(NSArray *objects, NSError *error) {
        XCTAssertNil(error);
        if (objects.count > 0) {
            for (AVIMConversation *conversation in objects) {
                XCTAssertNotNil(conversation.createAt);
                XCTAssertTrue([conversation.createAt compare:date] == NSOrderedAscending);
            }
        }
        NOTIFY
    }];
    WAIT
}

@end
