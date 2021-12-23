//
//  LCIMMessageTestCase.swift
//  LeanCloudObjcTests
//
//  Created by 黄驿峰 on 2021/12/16.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import XCTest
import XCTest
@testable import LeanCloudObjc

class LCIMMessageTestCase: RTMBaseTestCase {
    func testMessageSendingAndReceiving() {
        guard
            let tuples = convenienceInit(),
            let tuple1 = tuples.first,
            let tuple2 = tuples.last
            else
        {
            XCTFail()
            return
        }

        let delegatorA = tuple1.delegator
        let conversationA = tuple1.conversation
        let delegatorB = tuple2.delegator
        let conversationB = tuple2.conversation

        let checkMessage: (LCIMConversation, LCIMMessage) -> Void = { conv, message in
            XCTAssertEqual(message.status, .sent)
            XCTAssertNotNil(message.ID)
            XCTAssertEqual(conv.ID, message.conversationID)
            XCTAssertEqual(conv.clientID, message.currentClientID)
            XCTAssertNotNil(message.sentTimestamp)
            XCTAssertNotNil(message.sentDate)
            XCTAssertNotNil(message.content)
        }

        let exp1 = expectation(description: "A send message to B")
        exp1.expectedFulfillmentCount = 6
        let stringMessage = LCIMMessage.init(content: "string")
        delegatorA.conversationEvent = { client, converstion, event in
            switch event {
            case .lastMessageUpdated:
                XCTAssertTrue(stringMessage === converstion.lastMessage)
                exp1.fulfill()
            case .unreadMessageCountUpdated:
                XCTFail()
            default:
                break
            }
        }
        delegatorB.conversationEvent = { client, conversation, event in
            switch event {
            case .message(event: let mEvent):
                if case let .received(message: message) = mEvent {
                    checkMessage(conversation, message)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.fromClientID, conversationA.clientID)
                    XCTAssertNotNil(message.content)
                    exp1.fulfill()
                    conversation.read()
                }
            case .lastMessageUpdated:
                exp1.fulfill()
            case .unreadMessageCountUpdated:
                XCTAssertTrue([0,1].contains(conversation.unreadMessageCount))
                exp1.fulfill()
            default:
                break
            }
        }
        conversationA.send(stringMessage) { ret, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            checkMessage(conversationA, stringMessage)
            XCTAssertEqual(stringMessage.ioType, .out)
            XCTAssertEqual(stringMessage.fromClientID, conversationA.clientID)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: timeout)

        delegatorA.reset()
        delegatorB.reset()

        let exp2 = expectation(description: "B send message to A")
        exp2.expectedFulfillmentCount = 6
        let dataMessage = LCIMMessage.init(content: "data")
        delegatorA.conversationEvent = { client, conversation, event in
            switch event {
            case .message(event: let mEvent):
                if case let .received(message: message) = mEvent {
                    checkMessage(conversation, message)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.fromClientID, conversationB.clientID)
                    XCTAssertNotNil(message.content?.data)
                    exp2.fulfill()
                    conversation.read()
                }
            case .lastMessageUpdated:
                exp2.fulfill()
            case .unreadMessageCountUpdated:
                XCTAssertTrue([0,1].contains(conversation.unreadMessageCount))
                exp2.fulfill()
            default:
                break
            }
        }
        delegatorB.conversationEvent = { client, conversation, event in
            switch event {
            case .lastMessageUpdated:
                XCTAssertTrue(conversation.lastMessage === dataMessage)
                exp2.fulfill()
            case .unreadMessageCountUpdated:
                XCTFail()
            default:
                break
            }
        }
        conversationB.send(dataMessage) { ret, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            checkMessage(conversationB, dataMessage)
            XCTAssertEqual(dataMessage.ioType, .out)
            XCTAssertEqual(dataMessage.fromClientID, conversationB.clientID)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: timeout)

        delegatorA.reset()
        delegatorB.reset()

        XCTAssertEqual(conversationA.unreadMessageCount, 0)
        XCTAssertEqual(conversationB.unreadMessageCount, 0)
        XCTAssertNotNil(conversationA.lastMessage?.ID)
        XCTAssertNotNil(conversationA.lastMessage?.conversationID)
        XCTAssertNotNil(conversationA.lastMessage?.sentTimestamp)
        XCTAssertEqual(
            conversationA.lastMessage?.ID,
            conversationB.lastMessage?.ID
        )
        XCTAssertEqual(
            conversationA.lastMessage?.conversationID,
            conversationB.lastMessage?.conversationID
        )
        XCTAssertEqual(
            conversationA.lastMessage?.sentTimestamp,
            conversationB.lastMessage?.sentTimestamp
        )

        expecting { (exp) in
            conversationB.quit { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }

        expecting { (exp) in
            let message = LCIMTextMessage.init(text: uuid)
            conversationB.send(message) { ret, error in
                XCTAssertTrue(!ret)
                XCTAssertNotNil(error)
                XCTAssertNotNil(message.ID)
                XCTAssertNotNil(message.sentTimestamp)
                XCTAssertEqual(message.status, .failed)
                exp.fulfill()
            }
        }
    }

}

extension LCIMMessageTestCase {
    
    typealias ConversationSuite = (client: LCIMClient, delegator: LCIMClientDelegator, conversation: LCIMConversation)
    
    class CustomMessage: LCIMTypedMessage, LCIMTypedMessageSubclassing {
        static func classMediaType() -> MessageMediaType {
            return 1
        }
    }
    
    class InvalidCustomMessage: LCIMTypedMessage, LCIMTypedMessageSubclassing {
        static func classMediaType() -> MessageMediaType {
            return -1
        }
    }
    
    
    func createConversation(client: LCIMClient, clientIDs: Set<String>, isTemporary: Bool = false) -> LCIMConversation? {
        var conversation: LCIMConversation? = nil
        let exp = expectation(description: "create conversation")
        if isTemporary {
            let option = LCIMConversationCreationOption.init()
            option.timeToLive = 3600
            client.createTemporaryConversation(withClientIds: Array(clientIDs), option: option) { conv, error in
                XCTAssertNil(error)
                XCTAssertNotNil(conv)
                conversation = conv
                exp.fulfill()
            }
        } else {
            let option = LCIMConversationCreationOption.init()
            option.isUnique = false
            client.createConversation(withClientIds: Array(clientIDs), option: option) {  conv, error in
                XCTAssertNil(error)
                XCTAssertNotNil(conv)
                conversation = conv
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: timeout)
        return conversation
    }
    
    func convenienceInit(clientCount: Int = 2, shouldConnectionShared: Bool = true) -> [ConversationSuite]? {
        var tuples: [ConversationSuite] = []
        let exp = expectation(description: "get conversations")
        exp.expectedFulfillmentCount = clientCount
        var clientMap: [String: LCIMClient] = [:]
        var delegatorMap: [String: LCIMClientDelegator] = [:]
        var conversationMap: [String: LCIMConversation] = [:]
        var clientIDs: [String] = []
        for _ in 0..<clientCount {
            let delegator = LCIMClientDelegator.init()
            let client = newOpenedClient(delegator: delegator)
            delegator.conversationEvent = { c, conv, event in
                if c === client, case .joined = event {
                    conversationMap[c.ID] = conv
                    exp.fulfill()
                }
            }
            clientMap[client.ID] = client
            delegatorMap[client.ID] = delegator
            clientIDs.append(client.ID)
            if !shouldConnectionShared {
                LCRTMConnectionManager.shared().imProtobuf1Registry.removeAllObjects()
                LCRTMConnectionManager.shared().imProtobuf3Registry.removeAllObjects()
            }
        }
        if let clientID: String = clientIDs.first,
            let client = clientMap[clientID] {
            let _ = createConversation(client: client, clientIDs: Set(clientIDs))
        }
        wait(for: [exp], timeout: timeout)
        var convID: String? = nil
        for item in clientIDs {
            if let client = clientMap[item],
                let conv = conversationMap[item],
                let delegator = delegatorMap[item] {
                if let convID = convID {
                    XCTAssertEqual(convID, conv.ID)
                } else {
                    convID = conv.ID
                }
                tuples.append((client, delegator, conv))
            }
        }
        if tuples.count == clientCount {
            return tuples
        } else {
            return nil
        }
    }
    
    func sendingAndReceiving<T: LCIMTypedMessage>(
        sentMessage: T,
        progress: ((Double) -> Void)? = nil,
        receivedMessageChecker: ((T?) -> Void)? = nil)
        -> Bool
    {
        var sendingTuple: ConversationSuite? = nil
        var receivingTuple: ConversationSuite? = nil
        return sendingAndReceiving(
            sentMessage: sentMessage,
            sendingTuple: &sendingTuple,
            receivingTuple: &receivingTuple,
            progress: progress,
            receivedMessageChecker: receivedMessageChecker
        )
    }
    
    func sendingAndReceiving<T: LCIMMessage>(
        sentMessage: T,
        sendingTuple: inout ConversationSuite?,
        receivingTuple: inout ConversationSuite?,
        progress: ((Double) -> Void)? = nil,
        receivedMessageChecker: ((T?) -> Void)? = nil)
        -> Bool
    {
        guard
            let tuples = convenienceInit(),
            let tuple1 = tuples.first,
            let tuple2 = tuples.last
            else
        {
            XCTFail()
            return false
        }
        sendingTuple = tuple1
        receivingTuple = tuple2
        var flag: Int = 0
        var receivedMessage: T? = nil
        let exp = expectation(description: "message send and receive")
        exp.expectedFulfillmentCount = 2
        tuple2.delegator.messageEvent = { _, _, event in
            switch event {
            case .received(message: let message):
                if let msg: T = message as? T {
                    receivedMessage = msg
                    flag += 1
                } else {
                    XCTFail()
                }
                exp.fulfill()
            default:
                break
            }
        }
        tuple1.conversation.send(sentMessage) { value in
            progress?(Double(value))
        } callback: { ret, error in
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            if ret {
                flag += 1
            } else {
                XCTFail()
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: timeout)
        tuple2.delegator.messageEvent = nil
        XCTAssertNotNil(sentMessage.ID)
        XCTAssertNotNil(sentMessage.conversationID)
        XCTAssertNotNil(sentMessage.sentTimestamp)
        XCTAssertEqual(sentMessage.ID, receivedMessage?.ID)
        XCTAssertEqual(sentMessage.conversationID, receivedMessage?.conversationID)
        XCTAssertEqual(sentMessage.sentTimestamp, receivedMessage?.sentTimestamp)
        receivedMessageChecker?(receivedMessage)
        return (flag == 2)
    }
    
}
