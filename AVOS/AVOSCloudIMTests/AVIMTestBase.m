//
//  AVIMTestBase.m
//  AVOS
//
//  Created by lzw on 15/7/6.
//  Copyright (c) 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVIMTestBase.h"

@implementation AVIMTestBase

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)openClientForTest {
    [[AVIMClient defaultClient] openWithClientId:AVIM_TEST_ClinetID callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        NOTIFY;
    }];
    WAIT;
}

- (AVIMConversation *)queryConversationById:(NSString *)convid {
    __block AVIMConversation *conv;
    AVIMConversationQuery *query = [[AVIMClient defaultClient] conversationQuery];
    [query getConversationById:AVIM_TEST_ConversationID callback:^(AVIMConversation *conversation, NSError *error) {
        XCTAssertNil(error);
        conv = conversation;
        NOTIFY;
    }];
    WAIT;
    return conv;
}

- (AVIMConversation *)conversationForTest {
    return [self conversationForTestWithOption:AVIMConversationOptionNone];
}

- (AVIMConversation *)transientConversationForTest {
    return [self conversationForTestWithOption:AVIMConversationOptionTransient];
}

- (AVIMConversation *)conversationForTestWithOption:(AVIMConversationOption )option {
    __block AVIMConversation *conv;
    [[AVIMClient defaultClient] createConversationWithName:NSStringFromSelector(_cmd) clientIds:@[[AVIMClient defaultClient].clientId] attributes:nil options:option callback:^(AVIMConversation *conversation, NSError *error) {
        XCTAssertNil(error);
        conv = conversation;
        NOTIFY;
    }];
    WAIT;
    return conv;
}


@end
