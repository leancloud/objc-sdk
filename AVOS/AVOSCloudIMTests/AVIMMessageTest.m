//
//  AVIMMessageTest.m
//  AVOS
//
//  Created by lzw on 15/7/6.
//  Copyright (c) 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVIMTestBase.h"
#import "AVIMCustomMessage.h"

@interface AVIMMessageTest : AVIMTestBase<AVIMClientDelegate>

@property (nonatomic, strong) AVIMConversation *conversation;

@property (nonatomic, strong) AVIMClient *otherClient;

@end

const void *AVIMTestSendMessage = &AVIMTestSendMessage;
const void *AVIMTestSendTypedMessage = &AVIMTestSendTypedMessage;
const void *AVIMTestSendTransientMessage = &AVIMTestSendTransientMessage;
const void *AVIMTestReceiveMessage = &AVIMTestReceiveMessage;
const void *AVIMTestMessageDelivered = &AVIMTestMessageDelivered;
const void *AVIMTestQueryMessages = &AVIMTestQueryMessages;
const void *AVIMTestQueryManyMessages = &AVIMTestQueryManyMessages;
const void *AVIMTestQueryMessagesFromSever = &AVIMTestQueryMessagesFromSever;

@implementation AVIMMessageTest {
    const void *_AVIMTestOpenClient;
    const void *_AVIMTestCreateConversation;
}

- (instancetype)init {
    if ((self = [super init])) {
        _AVIMTestOpenClient = &_AVIMTestOpenClient;
        _AVIMTestCreateConversation = &_AVIMTestCreateConversation;
    }

    return self;
}

- (void)setUp {
    [super setUp];
    [self openClientForTest];
    self.conversation = [self queryConversationById:AVIM_TEST_ConversationID];
    if (self.otherClient == nil) {
         self.otherClient = [[AVIMClient alloc] init];
    }
    [self.otherClient openWithClientId:@"other" callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        [self postNotification:_AVIMTestOpenClient];
    }];
    [self waitNotification:_AVIMTestOpenClient];
    
    [AVIMClient defaultClient].delegate = self;
    self.otherClient.delegate = self;
}

- (void)tearDown {
    [super tearDown];
}

#pragma mark - delegate

- (AVIMConversation *)createConversationOfTwoClient {
    __block AVIMConversation *conv;
    [[AVIMClient defaultClient] createConversationWithName:NSStringFromSelector(_cmd) clientIds:@[@"other"] attributes:nil options:AVIMConversationOptionNone callback:^(AVIMConversation *conversation, NSError *error) {
        XCTAssertNil(error);
        conv = conversation;
        [self postNotification:_AVIMTestCreateConversation];
    }];
    [self waitNotification:_AVIMTestCreateConversation];
    return conv;
}

- (void)testSendMessage {
    AVIMMessage *message = [AVIMMessage messageWithContent:@"hi"];
    [self.conversation sendMessage:message callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(message.clientId, AVIM_TEST_ClinetID);
        XCTAssertTrue(message.sendTimestamp > 0);
        XCTAssertEqualObjects(message.content, @"hi");
        [self postNotification:AVIMTestSendMessage];
    }];
    [self waitNotification:AVIMTestSendMessage];
}

- (void)testSendTransientMessage {
    AVIMMessage *message = [AVIMMessage messageWithContent:@"inputing..."];
    [self.conversation sendMessage:message options:AVIMMessageSendOptionTransient callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(message.clientId, AVIM_TEST_ClinetID);
        XCTAssertEqualObjects(message.content, @"inputing...");
        [self postNotification:AVIMTestSendTransientMessage];
    }];
    [self waitNotification:AVIMTestSendTransientMessage];
}

- (void)conversation:(AVIMConversation *)conversation didReceiveCommonMessage:(AVIMMessage *)message {
    XCTAssertNotNil(message.messageId);
    XCTAssertTrue(message.sendTimestamp > 0);
    XCTAssertNotNil(message.clientId);
    XCTAssertNotNil(message.conversationId);
    if ([message.clientId isEqualToString:AVIM_TEST_ClinetID] && [message.content isEqualToString:@"testReceiveMessage"]) {
        [self postNotification:AVIMTestReceiveMessage];
    }
}

- (void)testReceiveMessage {
    AVIMConversation *conv = [self createConversationOfTwoClient];
    AVIMMessage *message = [AVIMMessage messageWithContent:@"testReceiveMessage"];
    [conv sendMessage:message callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        [self postNotification:AVIMTestReceiveMessage];
    }];
    [self waitNotification:AVIMTestReceiveMessage];
}

- (void)conversation:(AVIMConversation *)conversation messageDelivered:(AVIMMessage *)message {
    XCTAssertNotNil(message.messageId);
    XCTAssertTrue(message.sendTimestamp > 0);
    XCTAssertTrue(message.deliveredTimestamp > 0);
    XCTAssertNotNil(message.clientId);
    XCTAssertNotNil(message.conversationId);
    if ([message.clientId isEqualToString:AVIM_TEST_ClinetID] && [message.content isEqualToString:@"testMessageDelivered"]) {
        [self postNotification:AVIMTestMessageDelivered];
    }
}

- (void)testMessageDelivered {
    AVIMConversation *conv = [self createConversationOfTwoClient];
    AVIMMessage *message1 = [AVIMMessage messageWithContent:@"testMessageDelivered"];
    [conv sendMessage:message1 options:AVIMMessageSendOptionRequestReceipt callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        [self postNotification:AVIMTestMessageDelivered];
    }];
    [self waitNotification:AVIMTestMessageDelivered];
}

- (void)conversation:(AVIMConversation *)conversation didReceiveTypedMessage:(AVIMTypedMessage *)message {
    if ([message.clientId isEqualToString:AVIM_TEST_ClinetID]) {
        switch (message.mediaType) {
            case kAVIMMessageMediaTypeText:{
                AVIMTextMessage *textMessage = (AVIMTextMessage *)message;
                XCTAssertEqualObjects(textMessage.clientId, AVIM_TEST_ClinetID);
                XCTAssertTrue(textMessage.sendTimestamp > 0);
                XCTAssertEqualObjects(textMessage.attributes, @{@"link":@"https://leancloud.cn"});
                [self postNotification:AVIMTestSendTypedMessage];
                break;
            }
            case kAVIMMessageMediaTypeAudio:{
                AVIMAudioMessage *audioMessage = (AVIMAudioMessage *)message;
                XCTAssertNotNil(audioMessage.file.url);
                XCTAssertNotNil(audioMessage.file.metaData);
                XCTAssertEqualWithAccuracy(audioMessage.duration, 6.582857, 0.001);
                XCTAssertEqual(audioMessage.size, 52695);
                XCTAssertEqualObjects(audioMessage.format, @"mp3");
                XCTAssertEqualObjects(audioMessage.attributes, @{@"title":@"dudu"});
                XCTAssertEqualObjects(audioMessage.text, @"audio");
                [self postNotification:AVIMTestSendTypedMessage];
                break;
            }
            case kAVIMMessageMediaTypeImage:{
                AVIMImageMessage *imageMessage = (AVIMImageMessage *)message;
                XCTAssertEqualObjects(imageMessage.attributes, @{@"title":@"rainbow"});
                XCTAssertEqualObjects(imageMessage.text, @"test");
                XCTAssertNotNil(imageMessage.file.url);
                XCTAssertNotNil(imageMessage.file.metaData);
                XCTAssertEqual(imageMessage.height, 1200);
                XCTAssertEqual(imageMessage.width, 1200);
                [self postNotification:AVIMTestSendTypedMessage];
                break;
            }
            case kAVIMMessageMediaTypeLocation: {
                AVIMLocationMessage *locationMessage = (AVIMLocationMessage *)message;
                XCTAssertNil(locationMessage.attributes);
                XCTAssertEqualObjects(locationMessage.text, @"location");
                XCTAssertEqualWithAccuracy(locationMessage.latitude, 37.8, 0.01);
                XCTAssertEqualWithAccuracy(locationMessage.longitude, 38.8, 0.01);
                [self postNotification:AVIMTestSendTypedMessage];
                break;
            }
            case kAVIMMessageMediaTypeCustom: {
                AVIMCustomMessage *customMessage = (AVIMCustomMessage *)message;
                XCTAssertNotNil(customMessage.attributes);
                XCTAssertEqualObjects(customMessage.attributes[@"articleId"], @100);
                [self postNotification:AVIMTestSendTypedMessage];
            }
            default:
                break;
        }
    }
}

- (void)testSendTypedMessage {
    AVIMConversation *conversation = [self createConversationOfTwoClient];
    AVIMTextMessage *textMessage = [AVIMTextMessage messageWithText:@"textMessage" attributes:@{@"link":@"https://leancloud.cn"}];
    [conversation sendMessage:textMessage callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        [self postNotification:AVIMTestSendTypedMessage];
    }];
    [self waitNotification:AVIMTestSendTypedMessage];
    
    NSString *imagePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"testImage" ofType:@"png"];
    XCTAssertNotNil(imagePath);
    AVIMImageMessage *imageMessage = [AVIMImageMessage messageWithText:@"test" attachedFilePath:imagePath attributes:@{@"title":@"rainbow"}];
    [conversation sendMessage:imageMessage callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        [self postNotification:AVIMTestSendTypedMessage];
    }];
    [self waitNotification:AVIMTestSendTypedMessage];
    
    NSString *audioPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"testAudio" ofType:@"mp3"];
    XCTAssertNotNil(audioPath);
    AVIMAudioMessage *audioMessage = [AVIMAudioMessage messageWithText:@"audio" attachedFilePath:audioPath attributes:@{@"title":@"dudu"}];
    [conversation sendMessage:audioMessage callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        [self postNotification:AVIMTestSendTypedMessage];
    }];
    [self waitNotification:AVIMTestSendTypedMessage];
    
    AVIMLocationMessage *locaionMessage = [AVIMLocationMessage messageWithText:@"location" latitude:37.8 longitude:38.8 attributes:nil];
    [conversation sendMessage:locaionMessage callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        [self postNotification:AVIMTestSendTypedMessage];
    }];
    [self waitNotification:AVIMTestSendTypedMessage];
    
    AVIMCustomMessage *customMessage = [AVIMCustomMessage messageWithAttributes:@{@"articleId":@100}];
    [conversation sendMessage:customMessage callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        [self postNotification:AVIMTestSendTypedMessage];
    }];
    [self waitNotification:AVIMTestSendTypedMessage];
}

- (void)testQueryMessages {
    AVIMTextMessage *message = [AVIMTextMessage messageWithText:@"testQueryMessages" attributes:nil];
    [self.conversation sendMessage:message callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        [self postNotification:AVIMTestQueryMessages];
    }];
    [self waitNotification:AVIMTestQueryMessages];

    [self.conversation queryMessagesWithLimit:1 callback:^(NSArray *objects, NSError *error) {
        XCTAssertEqual(objects.count, 1);
        AVIMTextMessage *textMessage = (AVIMTextMessage *)objects[0];
        XCTAssertEqualObjects(textMessage.text, @"testQueryMessages");
        [self postNotification:AVIMTestQueryMessages];
    }];
    [self waitNotification:AVIMTestQueryMessages];
}

- (void)testQueryManyMessages {
    for (int i = 0; i < 10; i++) {
        AVIMTextMessage *message = [AVIMTextMessage messageWithText:[NSString stringWithFormat:@"%ld", (long)i] attributes:nil];
        [self.conversation sendMessage:message callback:^(BOOL succeeded, NSError *error) {
            XCTAssertNil(error);
            [self postNotification:AVIMTestQueryManyMessages];
        }];
        [self waitNotification:AVIMTestQueryManyMessages];
    }
    __block AVIMTextMessage *firstMessage;
    [self.conversation queryMessagesWithLimit:1 callback:^(NSArray *objects, NSError *error) {
        XCTAssertEqual(objects.count, 1);
        firstMessage = objects[0];
        XCTAssertEqualObjects(firstMessage.text, @"9");
        [self postNotification:AVIMTestQueryManyMessages];
    }];
    [self waitNotification:AVIMTestQueryManyMessages];
    
    XCTAssertNotNil(firstMessage);
    [self.conversation queryMessagesBeforeId:firstMessage.messageId timestamp:firstMessage.sendTimestamp limit:9 callback:^(NSArray *objects, NSError *error) {
        XCTAssertEqual(objects.count, 9);
        for (int i = 0; i < 9; i++) {
            AVIMTextMessage *textMessage = (AVIMTextMessage *)objects[i];
            XCTAssertEqualObjects(textMessage.text, ([NSString stringWithFormat:@"%ld", (long)i]));
        }
    }];
}

- (void)testQueryMessagesFromServer {
    NSString *text = NSStringFromSelector(_cmd);
    AVIMTextMessage *message = [AVIMTextMessage messageWithText:text attributes:nil];
    [self.conversation sendMessage:message callback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        [self postNotification:AVIMTestQueryMessagesFromSever];
    }];
    [self waitNotification:AVIMTestQueryMessagesFromSever];
    
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:5]];
    
    [self.conversation queryMessagesFromServerWithLimit:1 callback:^(NSArray *objects, NSError *error) {
        XCTAssertEqual(objects.count, 1);
        XCTAssertTrue([objects[0] isKindOfClass:[AVIMTextMessage class]]);
        AVIMTextMessage *textMessage = (AVIMTextMessage *)objects[0];
        XCTAssertEqualObjects(textMessage.text, text);
        [self postNotification:AVIMTestQueryMessagesFromSever];
    }];
    [self waitNotification:AVIMTestQueryMessagesFromSever];
}

@end
