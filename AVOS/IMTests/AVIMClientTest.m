//
//  AVIMClientTest.m
//  AVOS
//
//  Created by lzw on 15/7/6.
//  Copyright (c) 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVIMTestBase.h"

@interface AVIMClientTest : AVIMTestBase<AVIMSignatureDataSource>

@end

@implementation AVIMClientTest

- (void)testOpenClient {
    AVIMClient *client = [[AVIMClient alloc] initWithClientId:AVIM_TEST_ClinetID];
    [client openWithCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(client.clientId, AVIM_TEST_ClinetID);
        XCTAssertEqual(client.status, AVIMClientStatusOpened);
        NOTIFY;
    }];
    WAIT;
}

- (void)testOpenClientButSaveChannelFailed {
    AVIMClient *client = [[AVIMClient alloc] initWithClientId:AVIM_TEST_ClinetID_Peer];
    [client openWithCallback:^(BOOL succeeded, NSError *error) {
        NOTIFY
    }];
    WAIT
    //Console output should print: {"code":112,"error":"Invalid channel name. A channel name is either an empty string (the broadcast channel) or contains only a-zA-Z0-9_ or chinese characters and starts with a letter."}
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
}

- (void)testReopenClient {
    AVIMClient *client = [[AVIMClient alloc] initWithClientId:AVIM_TEST_ClinetID];
    [client openWithCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(client.status, AVIMClientStatusOpened);
        NOTIFY;
    }];
    WAIT;
    
    AVIMClient *client2 = [[AVIMClient alloc] initWithClientId:AVIM_TEST_ClinetID];
    [client2 openWithCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(client2.status, AVIMClientStatusOpened);
        NOTIFY;
    }];
    WAIT;
}

- (void)testCloseClient {
    AVIMClient *client = [[AVIMClient alloc] initWithClientId:AVIM_TEST_ClinetID];
    [client openWithCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(client.status, AVIMClientStatusOpened);
        NOTIFY;
    }];
    WAIT;
    
    [client closeWithCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(client.status, AVIMClientStatusClosed);
        NOTIFY;
    }];
    WAIT;
}

- (void)testSignature {
    AVIMClient *client = [[AVIMClient alloc] initWithClientId:AVIM_TEST_ClinetID];
    client.signatureDataSource = self;
    [client openWithCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(client.status, AVIMClientStatusOpened);
        NOTIFY;
    }];
    WAIT;
}

- (void)testCreateConversationWithNameClientIdsAttributesOptionsCallback {
    NSArray *members = @[
                         AVIM_TEST_ClinetID_Peer_2,
                         AVIM_TEST_ClinetID,
                         AVIM_TEST_ClinetID_Peer,
                         AVIM_TEST_ClinetID_Peer_1,
                         ];
    NSString *name = [NSString stringWithFormat:@"%@%@%@%@", AVIM_TEST_ClinetID_Peer_2, AVIM_TEST_ClinetID, AVIM_TEST_ClinetID_Peer, AVIM_TEST_ClinetID_Peer_1];
    AVIMClient *client = [[AVIMClient alloc] initWithClientId:AVIM_TEST_ClinetID];
    [client openWithCallback:^(BOOL succeeded, NSError *error) {
        [client createConversationWithName:name clientIds:members attributes:@{ @"type":@(1) } options:AVIMConversationOptionNone callback:^(AVIMConversation *conversation, NSError *error) {
            XCTAssertEqual(conversation.members.count, members.count);
            NOTIFY;
        }];
    }];
    WAIT;
    
    //查询语句是否正常
    AVIMConversationQuery *query = [client conversationQuery];
    [query getConversationById:AVIM_TEST_ConversationID callback:^(AVIMConversation *conversation, NSError *error) {
        XCTAssertNil(error);
        NOTIFY
    }];
    WAIT
}

- (AVIMSignature *)signatureWithClientId:(NSString *)clientId conversationId:(NSString *)conversationId action:(NSString *)action actionOnClientIds:(NSArray *)clientIds {
    XCTAssertEqual(clientId, AVIM_TEST_ClinetID);
    XCTAssertNil(conversationId);
    XCTAssertEqual(action, @"open");
    XCTAssertNil(clientIds);
    AVIMSignature *signature = [[AVIMSignature alloc] init];
    signature.signature = @"sig";
    signature.timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    signature.nonce = @"nonce";
    return signature;
}
                       
@end
