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
        
        let checkMessage: (LCIMConversation, LCIMMessage, LCIMMessageStatus) -> Void = { conv, message, status in
            XCTAssertEqual(message.status, status)
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
                    checkMessage(conversation, message, .delivered)
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
            checkMessage(conversationA, stringMessage, .sent)
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
                    checkMessage(conversation, message, .delivered)
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
                XCTAssertEqual(conversation.unreadMessagesCount, 0)
            default:
                break
            }
        }
        conversationB.send(dataMessage) { ret, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            checkMessage(conversationB, dataMessage, .sent)
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
                XCTAssertEqual(message.status, .failed)
                exp.fulfill()
            }
        }
    }
    
    func testMessageContinuousSendingAndReceiving() {
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
        var lastMessageIDSet: Set<String> = []
        
        let exp = expectation(description: "message continuous sending and receiving")
        let count = 5
        exp.expectedFulfillmentCount = (count * 2) + 2
        var receivedMessageCountA = count
        delegatorA.conversationEvent = { client, conversation, event in
            switch event {
            case .message(event: let mEvent):
                switch mEvent {
                case .received(message: let message):
                    receivedMessageCountA -= 1
                    if receivedMessageCountA == 0,
                       let msgID = message.ID {
                        lastMessageIDSet.insert(msgID)
                    }
                    conversation.read()
                    exp.fulfill()
                default:
                    break
                }
            case .unreadMessageCountUpdated:
                if receivedMessageCountA == 0,
                   conversation.unreadMessageCount == 0 {
                    exp.fulfill()
                }
            default:
                break
            }
        }
        var receivedMessageCountB = count
        delegatorB.conversationEvent = { client, conversation, event in
            switch event {
            case .message(event: let mEvent):
                switch mEvent {
                case .received(message: let message):
                    receivedMessageCountB -= 1
                    if receivedMessageCountB == 0,
                       let msgID = message.ID {
                        lastMessageIDSet.insert(msgID)
                    }
                    conversation.read()
                    exp.fulfill()
                default:
                    break
                }
            case .unreadMessageCountUpdated:
                if receivedMessageCountB == 0,
                   conversation.unreadMessageCount == 0 {
                    exp.fulfill()
                }
            default:
                break
            }
        }
        for _ in 0..<count {
            let sendAExp = expectation(description: "send message")
            let messageA = LCIMMessage.init(content: "test")
            conversationA.send(messageA) { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                sendAExp.fulfill()
            }
            
            wait(for: [sendAExp], timeout: timeout)
            let sendBExp = expectation(description: "send message")
            let messageB = LCIMMessage.init(content: "test")
            conversationB.send(messageB) { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                sendBExp.fulfill()
            }
            wait(for: [sendBExp], timeout: timeout)
        }
        wait(for: [exp], timeout: timeout)
        
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
        XCTAssertTrue([1,2].contains(lastMessageIDSet.count))
        XCTAssertTrue(lastMessageIDSet.contains(conversationA.lastMessage?.ID ?? ""))
    }
    
    func testMessageReceipt() {
        guard
            let convSuites = convenienceInit(shouldConnectionShared: false),
            let convSuite1 = convSuites.first,
            let convSuite2 = convSuites.last else
            {
                XCTFail()
                return
            }
        
        var message = LCIMTextMessage.init(text: "")
        var deliveredMessageID: String?
        
        expecting(description: "delivery rcp", count: 3) { (exp) in
            convSuite1.delegator.messageEvent = { client, conv, event in
                if case let .delivered(message: message) = event {
                    //                    XCTAssertEqual(message.fromClientID, convSuite2.client.ID)
                    XCTAssertGreaterThan(message.deliveredTimestamp, 0)
                    deliveredMessageID = message.ID
                    exp.fulfill()
                }
            }
            convSuite2.delegator.messageEvent = { client, conv, event in
                if case .received(message: _) = event {
                    exp.fulfill()
                }
            }
            let msgOpt = LCIMMessageOption.init()
            msgOpt.receipt = true
            convSuite1.conversation.send(message, option: msgOpt) { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        convSuite1.delegator.reset()
        convSuite2.delegator.reset()
        
        XCTAssertNotNil(deliveredMessageID)
        XCTAssertEqual(deliveredMessageID, message.ID)
        
        expecting(description: "read rcp", count: 2) { (exp) in
            convSuite1.delegator.messageEvent = { client, conv, event in
                if case let .read(lastReadAt: date) = event {
                    XCTAssertNotNil(date)
                    exp.fulfill()
                }
                
            }
            convSuite2.delegator.conversationEvent = { client, conv, event in
                if case .unreadMessageCountUpdated = event {
                    exp.fulfill()
                }
            }
            convSuite2.conversation.read()
        }
        
        
        convSuite1.delegator.reset()
        convSuite2.delegator.reset()
        delay()
        
        // test offline rcp event 👇
        
        expecting(description: "send need receipt message", count: 2) { (exp) in
            message = LCIMTextMessage.init(text: "")
            convSuite2.delegator.conversationEvent = { client, conv, event in
                if case .unreadMessageCountUpdated = event {
                    exp.fulfill()
                }
            }
            convSuite1.conversation.send(message) { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        convSuite1.delegator.reset()
        convSuite2.delegator.reset()
        convSuite1.client.connection.disconnect()   // connection 1 disconnect
        delay()
        
        
        expecting { (exp) in
            convSuite2.delegator.conversationEvent = { client, conv, event in
                if case .unreadMessageCountUpdated = event {
                    if conv.unreadMessageCount == 0 {
                        exp.fulfill()
                    }
                }
            }
            convSuite2.conversation.read()
        }
        
        convSuite1.delegator.reset()
        convSuite2.delegator.reset()
        delay(seconds: 5)
        
        //        expecting { (exp) in
        //            convSuite1.delegator.messageEvent = { client, conv, event in
        //                if case let .read(lastReadAt: date) = event {
        //                    XCTAssertNotNil(date)
        //                    exp.fulfill()
        //                }
        //            }
        //            convSuite1.client.connection.testConnect()
        //        }
    }
    
    func testTransientMessageSendingAndReceiving() {
        guard
            let tuples = convenienceInit(),
            let tuple1 = tuples.first,
            let tuple2 = tuples.last
        else
        {
            XCTFail()
            return
        }
        
        let conversationA = tuple1.conversation
        let delegatorB = tuple2.delegator
        let checkMessage: (LCIMMessage) -> Void = { message in
            XCTAssertTrue(message.isTransient)
            XCTAssertNotNil(message.ID)
            XCTAssertNotNil(message.sentTimestamp)
            XCTAssertNotNil(message.conversationID)
            //            XCTAssertEqual(message.status, .sent)
        }
        
        let exp = expectation(description: "send transient message")
        exp.expectedFulfillmentCount = 2
        delegatorB.messageEvent = { client, conversation, event in
            switch event {
            case .received(message: let message):
                XCTAssertEqual(message.ioType, .in)
                checkMessage(message)
                exp.fulfill()
            default:
                break
            }
        }
        let message = LCIMMessage.init(content: "test")
        let msgOpt = LCIMMessageOption.init()
        msgOpt.transient = true
        conversationA.send(message, option: msgOpt) { ret, error in
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            XCTAssertEqual(message.ioType, .out)
            checkMessage(message)
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
    }
    
    func testMessageAutoSendingWhenOfflineAndReceiving() {
        guard
            let tuples = convenienceInit(shouldConnectionShared: false),
            let tuple1 = tuples.first,
            let tuple2 = tuples.last
        else
        {
            XCTFail()
            return
        }
        
        let clientA = tuple1.client
        let conversationA = tuple1.conversation
        let delegatorB = tuple2.delegator
        
        let sendExp = expectation(description: "send message")
        let willMessage = LCIMMessage.init(content: "test")
        let msgOpt = LCIMMessageOption.init()
        msgOpt.will = true
        conversationA.send(willMessage, option: msgOpt) { ret, error in
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            XCTAssertNil(conversationA.lastMessage)
            //            XCTAssertTrue(willMessage.isWill)
            XCTAssertNotNil(willMessage.sentTimestamp)
            sendExp.fulfill()
        }
        wait(for: [sendExp], timeout: timeout)
        
        let receiveExp = expectation(description: "receive message")
        delegatorB.messageEvent = { client, conversation, event in
            switch event {
            case .received(message: let message):
                XCTAssertNotNil(message.ID)
                XCTAssertNotNil(message.conversationID)
                XCTAssertNotNil(message.sentTimestamp)
                XCTAssertEqual(message.ID, willMessage.ID)
                XCTAssertEqual(message.conversationID, willMessage.conversationID)
                XCTAssertNotNil(conversation.lastMessage)
                receiveExp.fulfill()
            default:
                break
            }
        }
        clientA.connection.disconnect()
        wait(for: [receiveExp], timeout: timeout)
    }
    
    func testSendMessageToChatRoom() {
        let client1ID = uuid + "1"
        let client2ID = uuid + "2"
        let client3ID = uuid + "3"
        let client4ID = uuid + "4"
        let delegator1 = LCIMClientDelegator.init()
        let delegator2 = LCIMClientDelegator.init()
        let delegator3 = LCIMClientDelegator.init()
        let delegator4 = LCIMClientDelegator.init()
        
        let client1 = newOpenedClient(clientID: client1ID, delegator: delegator1)
        let client2 = newOpenedClient(clientID: client2ID, delegator: delegator2)
        let client3 = newOpenedClient(clientID: client3ID, delegator: delegator3)
        
        LCRTMConnectionManager.shared().imProtobuf1Registry.removeAllObjects()
        LCRTMConnectionManager.shared().imProtobuf3Registry.removeAllObjects()
        
        let client4 = newOpenedClient(clientID: client4ID, delegator: delegator4)
        
        
        client4.delegate = delegator4
        var chatRoom1: LCIMChatRoom?
        var chatRoom2: LCIMChatRoom?
        var chatRoom3: LCIMChatRoom?
        var chatRoom4: LCIMChatRoom?
        
        expecting { exp in
            client1.createChatRoom { chatRoom, error in
                XCTAssertNil(error)
                XCTAssertNotNil(chatRoom)
                chatRoom1 = chatRoom
                exp.fulfill()
            }
        }
        
        guard let ID = chatRoom1?.ID else {
            XCTFail()
            return
        }
        
        expecting { exp in
            client2.conversationQuery().getConversationById(ID) { conv, error in
                XCTAssertNil(error)
                let value = conv as? LCIMChatRoom
                XCTAssertNotNil(value)
                chatRoom2 = value
                exp.fulfill()
            }
        }
        
        expecting { exp in
            chatRoom2?.join(callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
        }
        
        expecting { exp in
            client3.conversationQuery().getConversationById(ID) { conv, error in
                XCTAssertNil(error)
                let value = conv as? LCIMChatRoom
                XCTAssertNotNil(value)
                chatRoom3 = value
                exp.fulfill()
            }
        }
        
        expecting { exp in
            chatRoom3?.join(callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
        }
        
        expecting { exp in
            client4.conversationQuery().getConversationById(ID) { conv, error in
                XCTAssertNil(error)
                let value = conv as? LCIMChatRoom
                XCTAssertNotNil(value)
                chatRoom4 = value
                exp.fulfill()
            }
        }
        
        expecting { exp in
            chatRoom4?.join(callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
        }
        
        delay()
        
        expecting(count: 8) { (exp) in
            delegator1.messageEvent = { client, conv, event in
                switch event {
                case .received(message: _):
                    exp.fulfill()
                default:
                    break
                }
            }
            delegator2.messageEvent = { client, conv, event in
                switch event {
                case .received(message: _):
                    exp.fulfill()
                default:
                    break
                }
            }
            delegator3.messageEvent = { client, conv, event in
                switch event {
                case .received(message: _):
                    exp.fulfill()
                default:
                    break
                }
            }
            delegator4.messageEvent = { client, conv, event in
                switch event {
                case .received(message: _):
                    exp.fulfill()
                default:
                    break
                }
            }
            let msgOpt = LCIMMessageOption.init()
            msgOpt.priority = .high
            chatRoom1?.send(LCIMTextMessage.init(text: "1"), option: msgOpt, callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
                let msgOpt = LCIMMessageOption.init()
                msgOpt.priority = .high
                chatRoom2?.send(LCIMTextMessage.init(text: "2"), option: msgOpt, callback: { ret, error in
                    XCTAssertTrue(ret)
                    XCTAssertNil(error)
                    exp.fulfill()
                })
            })
        }
        
        delegator1.reset()
        delegator2.reset()
        delegator3.reset()
        delegator4.reset()
        
        XCTAssertNil(chatRoom1?.lastMessage)
        XCTAssertNil(chatRoom2?.lastMessage)
        XCTAssertNil(chatRoom3?.lastMessage)
        XCTAssertNil(chatRoom4?.lastMessage)
        //        XCTAssertTrue((chatRoom1?.members ?? []).isEmpty)
        //        XCTAssertTrue((chatRoom2?.members ?? []).isEmpty)
        //        XCTAssertTrue((chatRoom3?.members ?? []).isEmpty)
        //        XCTAssertTrue((chatRoom4?.members ?? []).isEmpty)
    }
    
    func testReceiveMessageFromServiceConversation() {
        
        let convID = newServiceConversation()
        let delegator = LCIMClientDelegator.init()
        let client = newOpenedClient(delegator: delegator)
        
        delay(seconds: 5)
        
        var serviceConv: LCIMServiceConversation? = nil
        
        let subscribeExp = expectation(description: "subscribe service converastion")
        subscribeExp.expectedFulfillmentCount = 2
        client.conversationQuery().getConversationById(convID) { conv, error in
            XCTAssertNil(error)
            let value = conv as? LCIMServiceConversation
            XCTAssertNotNil(value)
            serviceConv = value
            subscribeExp.fulfill()
            serviceConv?.subscribe(callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                subscribeExp.fulfill()
            })
        }
        wait(for: [subscribeExp], timeout: timeout)
        
        let receiveExp = expectation(description: "receive message")
        delegator.messageEvent = { client, conv, event in
            if conv === serviceConv {
                switch event {
                case .received(message: let message):
                    XCTAssertEqual(message.content, "test")
                    receiveExp.fulfill()
                    delegator.messageEvent = nil
                default:
                    break
                }
            }
        }
        broadcastingMessage(to: convID, content: "test")
        wait(for: [receiveExp], timeout: timeout)
        
        delay(seconds: 5)
        
        let unsubscribeExp = expectation(description: "unsubscribe service conversation")
        serviceConv?.unsubscribe(callback: { ret, error in
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            unsubscribeExp.fulfill()
        })
        wait(for: [unsubscribeExp], timeout: timeout)
        
        let shouldNotReceiveExp = expectation(description: "should not receive message")
        shouldNotReceiveExp.isInverted = true
        delegator.messageEvent = { client, conv, event in
            if conv === serviceConv {
                switch event {
                case .received(message: let message):
                    XCTAssertEqual(message.content, "test")
                    shouldNotReceiveExp.fulfill()
                default:
                    break
                }
            }
        }
        broadcastingMessage(to: convID, content: "test")
        wait(for: [shouldNotReceiveExp], timeout: 5)
    }
    
    func testCustomMessageSendingAndReceiving() {
        CustomMessage.registerSubclass()
        let message = CustomMessage()
        XCTAssertTrue(sendingAndReceiving(sentMessage: message))
    }
    
    func testTextMessageSendingAndReceiving() {
        let message = LCIMTextMessage.init(text: "test")
        let success = sendingAndReceiving(sentMessage: message, receivedMessageChecker: { (rMessage) in
            XCTAssertNotNil(rMessage?.text)
            XCTAssertEqual(rMessage?.text, message.text)
        })
        XCTAssertTrue(success)
    }
    
    func testImageMessageSendingAndReceiving() {
        for i in 0...1 {
            let format: String = (i == 0) ? "png" : "jpg"
            let imageFile = try? LCFile.init(localPath: bundleResourceURL(name: "test", ext: format).path)
            XCTAssertNotNil(imageFile)
            let outMessage = LCIMImageMessage.init(text: "test", file: imageFile!, attributes: nil)
            
            XCTAssertTrue(sendingAndReceiving(sentMessage: outMessage, receivedMessageChecker: { (inMessage) in
                XCTAssertNotNil(inMessage?.file?.objectId)
                XCTAssertEqual(inMessage?.format, format)
                XCTAssertNotNil(inMessage?.size)
                XCTAssertNotNil(inMessage?.height)
                XCTAssertNotNil(inMessage?.width)
                XCTAssertNotNil(inMessage?.url)
                XCTAssertEqual(inMessage?.file?.objectId, outMessage.file?.objectId)
                XCTAssertEqual(inMessage?.format, outMessage.format)
                XCTAssertEqual(inMessage?.size, outMessage.size)
                XCTAssertEqual(inMessage?.height, outMessage.height)
                XCTAssertEqual(inMessage?.width, outMessage.width)
                XCTAssertEqual(inMessage?.url, outMessage.url)
            }))
        }
    }
    
    func testAudioMessageSendingAndReceiving() {
        let format: String = "mp3"
        let audioFile = try? LCFile.init(localPath: bundleResourceURL(name: "test", ext: format).path)
        XCTAssertNotNil(audioFile)
        let message = LCIMAudioMessage.init(text: "test", file: audioFile!, attributes: nil)
        
        var progress = 0.0
        let success = sendingAndReceiving(sentMessage: message, progress: { p in
            progress = p
        }) { (rMessage) in
            XCTAssertNotNil(rMessage?.file?.objectId)
            XCTAssertEqual(rMessage?.format, format)
            XCTAssertNotNil(rMessage?.size)
            XCTAssertNotNil(rMessage?.duration)
            XCTAssertNotNil(rMessage?.url)
            XCTAssertEqual(rMessage?.file?.objectId, message.file?.objectId)
            XCTAssertEqual(rMessage?.format, message.format)
            XCTAssertEqual(rMessage?.size, message.size)
            XCTAssertEqual(rMessage?.duration, message.duration)
            XCTAssertEqual(rMessage?.url, message.url)
        }
        XCTAssertTrue(success)
        XCTAssertTrue(progress > 0.0)
    }
    
    func testVideoMessageSendingAndReceiving() {
        let format: String = "mp4"
        let file = try? LCFile.init(localPath: bundleResourceURL(name: "test", ext: format).path)
        XCTAssertNotNil(file)
        let message = LCIMVideoMessage.init(text: "test", file: file!, attributes: nil)
        
        var progress = 0.0
        let success = sendingAndReceiving(sentMessage: message, progress: { p in
            progress = p
        }) { (rMessage) in
            XCTAssertNotNil(rMessage?.file?.objectId)
            XCTAssertEqual(rMessage?.format, format)
            XCTAssertNotNil(rMessage?.size)
            XCTAssertNotNil(rMessage?.duration)
            XCTAssertNotNil(rMessage?.url)
            XCTAssertEqual(rMessage?.file?.objectId, message.file?.objectId)
            XCTAssertEqual(rMessage?.format, message.format)
            XCTAssertEqual(rMessage?.size, message.size)
            XCTAssertEqual(rMessage?.duration, message.duration)
            XCTAssertEqual(rMessage?.url, message.url)
        }
        XCTAssertTrue(success)
        XCTAssertTrue(progress > 0.0)
    }
    
    func testFileMessageSendingAndReceiving() {
        let format: String = "zip"
        let file = try? LCFile.init(localPath: bundleResourceURL(name: "test", ext: format).path)
        XCTAssertNotNil(file)
        let message = LCIMFileMessage.init(text: "test", file: file!, attributes: nil)
        
        let success = sendingAndReceiving(sentMessage: message, receivedMessageChecker: { (rMessage) in
            XCTAssertNotNil(rMessage?.file?.objectId)
            XCTAssertEqual(rMessage?.format, format)
            XCTAssertNotNil(rMessage?.size)
            XCTAssertNotNil(rMessage?.url)
            XCTAssertEqual(rMessage?.file?.objectId, message.file?.objectId)
            XCTAssertEqual(rMessage?.format, message.format)
            XCTAssertEqual(rMessage?.size, message.size)
            XCTAssertEqual(rMessage?.url, message.url)
        })
        XCTAssertTrue(success)
    }
    
    func testLocationMessageSendingAndReceiving() {
        let latitude = 31.3753285
        let longitude = 120.9664658
        let message = LCIMLocationMessage.init(text: "坐标", latitude: latitude, longitude: longitude, attributes: nil)
        let success = sendingAndReceiving(sentMessage: message, receivedMessageChecker: { (rMessage) in
            XCTAssertEqual(rMessage?.latitude, latitude)
            XCTAssertEqual(rMessage?.longitude, longitude)
            XCTAssertEqual(rMessage?.latitude, message.latitude)
            XCTAssertEqual(rMessage?.longitude, message.longitude)
        })
        XCTAssertTrue(success)
    }
    
    func testBinaryMessage() {
        guard let tuples = convenienceInit(),
              let clientA = tuples.first?.client,
              let clientB = tuples.last?.client,
              let delegatorB = tuples.last?.delegator,
              let conversation = tuples.first?.conversation else {
                  XCTFail()
                  return
              }
        let content = "bin"
        let message = LCIMMessage.init(content: content)
        
        expecting(count: 5) { (exp) in
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case .unreadMessageCountUpdated:
                    exp.fulfill() // 3 times
                case let .message(event: messageEvent):
                    if case .received(message: _) = messageEvent {
                        conv.read()
                        exp.fulfill()
                    }
                default:
                    break
                }
            }
            let msgOpt = LCIMMessageOption.init()
            msgOpt.receipt = true
            conversation.send(message, option: msgOpt) { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        delay()
        delegatorB.reset()
        
        
        expecting { (exp) in
            let newMessage = LCIMMessage.init(content: content)
            newMessage.isAllMembersMentioned = true
            newMessage.mentionList = [clientB.ID]
            conversation.update(message, toNewMessage: newMessage) { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        delay()
        
        expecting { (exp) in
            let query = clientA.conversationQuery()
            query.option = .withMessage
            query.getConversationById(conversation.ID) { conv, error in
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        expecting { (exp) in
            conversation.queryMessages(withLimit: 20) { msgs, error in
                XCTAssertNil(error)
                XCTAssertEqual(msgs?.first?.content, content)
                exp.fulfill()
            }
        }
    }
    
    func testMessageUpdating() {
        let oldContent: String = "old"
        let oldMessage = LCIMMessage.init(content: oldContent)
        let newContent: String = "new"
        let newMessage = LCIMMessage.init(content: newContent)
        
        var sendingTuple: ConversationSuite? = nil
        var receivingTuple: ConversationSuite? = nil
        XCTAssertTrue(sendingAndReceiving(sentMessage: oldMessage, sendingTuple: &sendingTuple, receivingTuple: &receivingTuple))
        
        delay()
        
        let patchedMessageChecker: (LCIMMessage, LCIMMessage) -> Void = { patchedMessage, originMessage in
            XCTAssertNotNil(patchedMessage.ID)
            XCTAssertNotNil(patchedMessage.conversationID)
            XCTAssertNotNil(patchedMessage.sentTimestamp)
            XCTAssertEqual(patchedMessage.ID, originMessage.ID)
            XCTAssertEqual(patchedMessage.conversationID, originMessage.conversationID)
            XCTAssertEqual(patchedMessage.sentTimestamp, originMessage.sentTimestamp)
            XCTAssertEqual(originMessage.content, oldContent)
            XCTAssertEqual(patchedMessage.content, newContent)
        }
        
        //        expecting { exp in
        //            receivingTuple?.conversation.update(oldMessage, toNewMessage: newMessage, callback: { ret, error in
        //                XCTAssertNotNil(error)
        //                XCTAssertFalse(ret)
        //            })
        //        }
        
        
        let exp = expectation(description: "message patch")
        exp.expectedFulfillmentCount = 2
        
        receivingTuple?.delegator.messageEvent = { client, conv, event in
            switch event {
            case .updated(updatedMessage: let patchedMessage, reason: let reason):
                XCTAssertTrue(conv.lastMessage === patchedMessage)
                patchedMessageChecker(patchedMessage, oldMessage)
                XCTAssertNil(reason)
                exp.fulfill()
            default:
                break
            }
        }
        sendingTuple?.conversation.update(oldMessage, toNewMessage: newMessage, callback: { ret, error in
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            XCTAssertTrue(newMessage === sendingTuple?.conversation.lastMessage)
            patchedMessageChecker(newMessage, oldMessage)
            exp.fulfill()
        })
        wait(for: [exp], timeout: timeout)
        
    }
    
    func testMessageRecalling() {
        let oldContent: String = "old"
        let oldMessage = LCIMMessage.init(content: oldContent)
        
        var sendingTuple: ConversationSuite? = nil
        var receivingTuple: ConversationSuite? = nil
        XCTAssertTrue(sendingAndReceiving(sentMessage: oldMessage, sendingTuple: &sendingTuple, receivingTuple: &receivingTuple))
        
        delay()
        
        let recalledMessageChecker: (LCIMMessage, LCIMMessage) -> Void = { patchedMessage, originMessage in
            XCTAssertNotNil(patchedMessage.ID)
            XCTAssertNotNil(patchedMessage.conversationID)
            XCTAssertNotNil(patchedMessage.sentTimestamp)
            //            XCTAssertNotNil(patchedMessage.patchedTimestamp)
            //            XCTAssertNotNil(patchedMessage.patchedDate)
            XCTAssertEqual(patchedMessage.ID, originMessage.ID)
            XCTAssertEqual(patchedMessage.conversationID, originMessage.conversationID)
            XCTAssertEqual(patchedMessage.sentTimestamp, originMessage.sentTimestamp)
            XCTAssertEqual(originMessage.content, oldContent)
            XCTAssertTrue(patchedMessage is LCIMRecalledMessage)
            XCTAssertEqual((patchedMessage as? LCIMRecalledMessage)?.isRecall, true)
        }
        
        //        expecting { exp in
        //            receivingTuple?.conversation.recall(oldMessage, callback: { ret, error, reMsg in
        //                XCTAssertNotNil(error)
        //                XCTAssertFalse(ret)
        //            })
        //        }
        
        let exp = expectation(description: "message patch")
        exp.expectedFulfillmentCount = 2
        
        receivingTuple?.delegator.messageEvent = { client, conv, event in
            switch event {
            case .updated(updatedMessage: let recalledMessage, reason: let reason):
                XCTAssertTrue(conv.lastMessage === recalledMessage)
                recalledMessageChecker(recalledMessage, oldMessage)
                XCTAssertNil(reason)
                exp.fulfill()
            default:
                break
            }
        }
        sendingTuple?.conversation.recall(oldMessage, callback: { ret, error, reMsg in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            if let recalledMessage = reMsg {
                XCTAssertTrue(sendingTuple?.conversation.lastMessage === recalledMessage)
                recalledMessageChecker(recalledMessage, oldMessage)
            } else {
                XCTFail()
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: timeout)
        
    }
    
    func testMessagePatchNotification() {
        guard
            let tuples = convenienceInit(shouldConnectionShared: false),
            let sendingTuple = tuples.first,
            let receivingTuple = tuples.last
        else
        {
            XCTFail()
            return
        }
        
        let conversationA = sendingTuple.conversation
        
        let clientB = receivingTuple.client
        let delegatorB = receivingTuple.delegator
        
        var oldMessage = LCIMTextMessage.init(text: "old")
        
        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "send msg")
            exp.expectedFulfillmentCount = 2
            return exp
        }) { (exp) in
            delegatorB.messageEvent = { client, conversation, event in
                switch event {
                case .received:
                    exp.fulfill()
                default:
                    break
                }
            }
            conversationA.send(oldMessage) { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        delegatorB.reset()
        
        delay()
        
        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "update msg")
            exp.expectedFulfillmentCount = 2
            return exp
        }) { (exp) in
            delegatorB.messageEvent = { client, conv, event in
                switch event {
                case .updated:
                    exp.fulfill()
                default:
                    break
                }
            }
            let newMessage = LCIMTextMessage.init(text: "new")
            conversationA.update(oldMessage, toNewMessage: newMessage) { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        delegatorB.reset()
        
        delay()
        clientB.connection.disconnect()
        delay()
        
        for i in 0...1 {
            oldMessage = LCIMTextMessage.init(text: "old\(i)")
            expecting(description: "send msg") { (exp) in
                conversationA.send(oldMessage) { ret, error in
                    XCTAssertTrue(ret)
                    XCTAssertNil(error)
                    exp.fulfill()
                }
            }
            delay()
            expecting(description: "update msg") { (exp) in
                let newMessage = LCIMTextMessage.init(text: "new\(i)")
                conversationA.update(oldMessage, toNewMessage: newMessage) { ret, error in
                    XCTAssertTrue(ret)
                    XCTAssertNil(error)
                    exp.fulfill()
                }
            }
        }
        
        delay()
        
        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "receive offline patch")
            exp.expectedFulfillmentCount = 2
            return exp
        }) { (exp) in
            delegatorB.messageEvent = { client, conv, event in
                switch event {
                case .updated:
                    exp.fulfill()
                default:
                    break
                }
            }
            clientB.connection.testConnect()
        }
    }
    
    func testMessagePatchError() {
        //        guard LCApplication.default.id != BaseTestCase.usApp.id else {
        //            return
        //        }
        guard
            let tuples = convenienceInit(clientCount: 3),
            let sendingTuple = tuples.first,
            let receivingTuple = tuples.last
        else
        {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "patch error")
        exp.expectedFulfillmentCount = 3
        let invalidContent = "无码种子"
        receivingTuple.delegator.messageEvent = { client, conv, event in
            if receivingTuple.conversation === conv {
                switch event {
                case .received(message: let message):
                    XCTAssertNotNil(message.content)
                    XCTAssertNotEqual(message.content, invalidContent)
                    exp.fulfill()
                default:
                    break
                }
            }
        }
        sendingTuple.delegator.messageEvent = { client, conv, event in
            if sendingTuple.conversation === conv {
                switch event {
                case .updated(updatedMessage: let message, reason: let reason):
                    XCTAssertNotNil(message.content)
                    XCTAssertNotEqual(message.content, invalidContent)
                    XCTAssertNotNil(reason)
                    XCTAssertNotNil(reason?.code)
                    XCTAssertNotNil(reason?.reason)
                    exp.fulfill()
                default:
                    break
                }
            }
        }
        let contentInvalidMessage = LCIMMessage.init(content: invalidContent)
        sendingTuple.conversation.send(contentInvalidMessage) { ret, error in
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
    }
    
    func testGetMessageReceiptFlag() {
        let message = LCIMMessage.init(content: "text")
        var sendingTuple: ConversationSuite? = nil
        var receivingTuple: ConversationSuite? = nil
        let success = sendingAndReceiving(
            sentMessage: message,
            sendingTuple: &sendingTuple,
            receivingTuple: &receivingTuple
        )
        XCTAssertTrue(success)
        
        delay()
        
        let readExp = expectation(description: "read message")
        readExp.expectedFulfillmentCount = 2
        receivingTuple?.delegator.conversationEvent = { client, conv, event in
            if conv === receivingTuple?.conversation,
               case .unreadMessageCountUpdated = event {
                XCTAssertEqual(conv.unreadMessageCount, 0)
                readExp.fulfill()
            }
        }
        receivingTuple?.conversation.read()
        wait(for: [readExp], timeout: timeout)
        
        delay()
        
        let getReadFlagExp = expectation(description: "get read flag timestamp")
        getReadFlagExp.expectedFulfillmentCount = 1
        sendingTuple?.delegator.conversationEvent = { client, conv, event in
            switch event {
            case .lastDeliveredAtUpdated:
                XCTAssertNotNil(conv.lastDeliveredAt)
                getReadFlagExp.fulfill()
                //            case .lastReadAtUpdated:
                //                XCTAssertNotNil(conv.lastReadAt)
                //                getReadFlagExp.fulfill()
            default:
                break
            }
        }
        sendingTuple?.conversation.fetchReceiptTimestampsInBackground()
        wait(for: [getReadFlagExp], timeout: timeout)
        
        let sendNeedRCPMessageExp = expectation(description: "send need RCP message")
        sendNeedRCPMessageExp.expectedFulfillmentCount = 3
        sendingTuple?.delegator.conversationEvent = { client, conv, event in
            switch event {
            case .message(event: let messageEvent):
                switch messageEvent {
                case .delivered(message: _):
                    sendNeedRCPMessageExp.fulfill()
                default:
                    break
                }
            default:
                break
            }
        }
        receivingTuple?.delegator.conversationEvent = { client, conv, event in
            if conv === receivingTuple?.conversation {
                switch event {
                case .lastMessageUpdated:
                    sendNeedRCPMessageExp.fulfill()
                default:
                    break
                }
            }
        }
        let needRCPMessage = LCIMMessage.init(content: "test")
        let msgOpt = LCIMMessageOption.init()
        //        msgOpt.transient = true
        msgOpt.receipt = true
        sendingTuple?.conversation.send(needRCPMessage, option: msgOpt, callback: { ret, error in
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            sendNeedRCPMessageExp.fulfill()
        })
        wait(for: [sendNeedRCPMessageExp], timeout: timeout)
        
        //        delay()
        
        //        let getDeliveredFlagExp = expectation(description: "get delivered flag timestamp")
        //        try! sendingTuple?.conversation.getMessageReceiptFlag(completion: { (result) in
        //            XCTAssertTrue(Thread.isMainThread)
        //            XCTAssertTrue(result.isSuccess)
        //            XCTAssertNil(result.error)
        //            XCTAssertNotNil(result.value?.deliveredFlagTimestamp)
        //            XCTAssertNotNil(result.value?.deliveredFlagDate)
        //            XCTAssertNotEqual(result.value?.deliveredFlagTimestamp, result.value?.readFlagTimestamp)
        //            XCTAssertNotEqual(result.value?.deliveredFlagDate, result.value?.readFlagDate)
        //            XCTAssertGreaterThanOrEqual(result.value?.deliveredFlagTimestamp ?? 0, needRCPMessage.sentTimestamp ?? 0)
        //            getDeliveredFlagExp.fulfill()
        //        })
        //        wait(for: [getDeliveredFlagExp], timeout: timeout)
        //
        //        let client = try! IMClient(ID: uuid, options: [])
        //        let conversation = IMConversation(ID: uuid, rawData: [:], convType: .normal, client: client, caching: false)
        //        do {
        //            try conversation.getMessageReceiptFlag(completion: { (_) in })
        //            XCTFail()
        //        } catch {
        //            XCTAssertTrue(error is LCError)
        //        }
    }
    
    func testMessageQuery() {
        CustomMessage.registerSubclass()
        
        let clientA = newOpenedClient()
        let clientB = newOpenedClient()
        let conversation = createConversation(client: clientA, clientIDs: [clientA.ID, clientB.ID])
        
        
        var sentTuples: [(String, Int64)] = []
        for i in 0...8 {
            var message: LCIMMessage!
            switch i {
            case 0:
                message = LCIMMessage.init(content: "test")
            case 1:
                message = LCIMMessage.init(content: "bin")
            case 2:
                message = LCIMTextMessage.init(text: "text")
            case 3:
                let format: String = "jpg"
                let file = try? LCFile.init(localPath: bundleResourceURL(name: "test", ext: format).path)
                XCTAssertNotNil(file)
                message = LCIMImageMessage.init(text: "test", file: file!, attributes: nil)
            case 4:
                let format: String = "mp3"
                let file = try? LCFile.init(localPath: bundleResourceURL(name: "test", ext: format).path)
                XCTAssertNotNil(file)
                message = LCIMAudioMessage.init(text: "test", file: file!, attributes: nil)
            case 5:
                let format: String = "mp4"
                let file = try? LCFile.init(localPath: bundleResourceURL(name: "test", ext: format).path)
                XCTAssertNotNil(file)
                message = LCIMVideoMessage.init(text: "test", file: file!, attributes: nil)
            case 6:
                let format: String = "zip"
                let file = try? LCFile.init(localPath: bundleResourceURL(name: "test", ext: format).path)
                XCTAssertNotNil(file)
                message = LCIMFileMessage.init(text: "test", file: file!, attributes: nil)
            case 7:
                let latitude = 31.3753285
                let longitude = 120.9664658
                message = LCIMLocationMessage.init(text: "坐标", latitude: latitude, longitude: longitude, attributes: nil)
            case 8:
                message = CustomMessage()
                (message as! CustomMessage).text = "custom"
            default:
                XCTFail()
            }
            let exp = expectation(description: "send message")
            conversation?.send(message, callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                if let messageID = message.ID, let ts = message.sentTimestamp {
                    sentTuples.append((messageID, ts))
                }
                exp.fulfill()
            })
            wait(for: [exp], timeout: timeout)
        }
        XCTAssertEqual(sentTuples.count, 9)
        
        delay(seconds: 5)
        
        let defaultQueryExp = expectation(description: "default query")
        conversation?.queryMessages(withLimit: 50, callback: { msgs, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(error)
            XCTAssertEqual(msgs?.count, sentTuples.count)
            for i in 0..<sentTuples.count {
                XCTAssertEqual(msgs?[i].ID, sentTuples[i].0)
                XCTAssertEqual(msgs?[i].sentTimestamp, sentTuples[i].1)
            }
            defaultQueryExp.fulfill()
        })
        wait(for: [defaultQueryExp], timeout: timeout)
        
        let directionQueryExp = expectation(description: "direction query")
        directionQueryExp.expectedFulfillmentCount = 2
        conversation?.queryMessages(in: nil, direction: LCIMMessageQueryDirection.fromOldToNew, limit: 1, callback: { msgs, error in
            XCTAssertNil(error)
            XCTAssertEqual(msgs?.count, 1)
            XCTAssertEqual(msgs?.first?.ID, sentTuples.first?.0)
            XCTAssertEqual(msgs?.first?.sentTimestamp, sentTuples.first?.1)
            directionQueryExp.fulfill()
        })
        conversation?.queryMessages(in: nil, direction: LCIMMessageQueryDirection.fromNewToOld, limit: 1, callback: { msgs, error in
            XCTAssertNil(error)
            XCTAssertEqual(msgs?.count, 1)
            XCTAssertEqual(msgs?.first?.ID, sentTuples.last?.0)
            XCTAssertEqual(msgs?.first?.sentTimestamp, sentTuples.last?.1)
            directionQueryExp.fulfill()
        })
        wait(for: [directionQueryExp], timeout: timeout)
        
        let endpointQueryExp = expectation(description: "endpoint query")
        endpointQueryExp.expectedFulfillmentCount = 2
        let endpointQueryTuple = sentTuples[sentTuples.count / 2]
        let endpointQueryStart1 = LCIMMessageIntervalBound.init(messageId: endpointQueryTuple.0, timestamp: endpointQueryTuple.1, closed: true)
        let iMMessageInterval1 = LCIMMessageInterval.init(start: endpointQueryStart1, end: nil)
        
        conversation?.queryMessages(in: iMMessageInterval1, direction: .fromNewToOld, limit: 5, callback: { msgs, error in
            XCTAssertNil(error)
            XCTAssertEqual(msgs?.count, 5)
            for i in 0..<5 {
                XCTAssertEqual(msgs?[i].ID, sentTuples[i].0)
                XCTAssertEqual(msgs?[i].sentTimestamp, sentTuples[i].1)
            }
            endpointQueryExp.fulfill()
        })
        
        let endpointQueryStart2 = LCIMMessageIntervalBound.init(messageId: endpointQueryTuple.0, timestamp: endpointQueryTuple.1, closed: false)
        let iMMessageInterval2 = LCIMMessageInterval.init(start: endpointQueryStart2, end: nil)
        conversation?.queryMessages(in: iMMessageInterval2, direction: .fromOldToNew, limit: 5, callback: { msgs, error in
            XCTAssertNil(error)
            XCTAssertEqual(msgs?.count, 4)
            for i in 0..<4 {
                XCTAssertEqual(msgs?[i].ID, sentTuples[i + 5].0)
                XCTAssertEqual(msgs?[i].sentTimestamp, sentTuples[i + 5].1)
            }
            endpointQueryExp.fulfill()
        })
        
        wait(for: [endpointQueryExp], timeout: timeout)
        
        let intervalQueryExp = expectation(description: "interval query")
        
        let end = LCIMMessageIntervalBound.init(messageId: sentTuples.first?.0, timestamp: sentTuples.first!.1, closed: true)
        let start = LCIMMessageIntervalBound.init(messageId: sentTuples.last?.0, timestamp: sentTuples.last!.1, closed: true)
        let iMMessageInterval = LCIMMessageInterval.init(start: start, end: end)
        
        conversation?.queryMessages(in: iMMessageInterval, direction: .fromNewToOld, limit: UInt(sentTuples.count), callback: { msgs, error in
            XCTAssertNil(error)
            XCTAssertEqual(msgs?.count, sentTuples.count)
            for i in 0..<sentTuples.count {
                XCTAssertEqual(msgs?[i].ID, sentTuples[i].0)
                XCTAssertEqual(msgs?[i].sentTimestamp, sentTuples[i].1)
            }
            intervalQueryExp.fulfill()
        })
        
        wait(for: [intervalQueryExp], timeout: timeout)
        
        let typeQuery = expectation(description: "type query")
        conversation?.queryMediaMessagesFromServer(withType: .text, limit: 10, fromMessageId: nil, fromTimestamp: 0, callback: { msgs, error in
            XCTAssertNil(error)
            XCTAssertEqual(msgs?.count, 1)
            XCTAssertNotNil(msgs?.first?.deliveredTimestamp)
            XCTAssertEqual(msgs?.first?.status, .sent)
            typeQuery.fulfill()
        })
        wait(for: [typeQuery], timeout: timeout)
        
        XCTAssertEqual(conversation?.lastMessage?.ID, sentTuples.last?.0)
        XCTAssertEqual(conversation?.lastMessage?.sentTimestamp, sentTuples.last?.1)
    }
}

extension LCIMMessageTestCase {
    
    typealias ConversationSuite = (client: LCIMClient, delegator: LCIMClientDelegator, conversation: LCIMConversation)
    
    class CustomMessage: LCIMTypedMessage, LCIMTypedMessageSubclassing {
        static func classMediaType() -> LCIMMessageMediaType {
            return LCIMMessageMediaType(1)
        }
    }
    
    class InvalidCustomMessage: LCIMTypedMessage, LCIMTypedMessageSubclassing {
        static func classMediaType() -> LCIMMessageMediaType {
            return LCIMMessageMediaType(-1)
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
