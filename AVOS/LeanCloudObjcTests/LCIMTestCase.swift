//
//  LCIMTestCase.swift
//  LeanCloudObjcTests
//
//  Created by 黄驿峰 on 2021/12/9.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import Foundation

import XCTest
@testable import LeanCloudObjc



class LCIMTestCase: BaseTestCase {
    
    var tomClient: LCIMClient!
    var jerryClient: LCIMClient!
    //    static var maryClient: LCIMClient!
    var tomConversation: LCIMConversation!
    var jerryConversation: LCIMConversation!
    //    static var maryConversation: LCIMConversation!
    
    
    override func setUp() {
        super.setUp()
        
        do {
            tomClient = try LCIMClient.init(clientId: uuid)
            jerryClient = try LCIMClient.init(clientId: uuid)
            expecting (count: 2){ exp in
                tomClient.open { ret, error in
                    XCTAssertTrue(ret)
                    XCTAssertNil(error)
                    exp.fulfill()
                }
                jerryClient.open { ret, error in
                    XCTAssertTrue(ret)
                    XCTAssertNil(error)
                    exp.fulfill()
                }
            }
            
            let jerryDelegator = LCIMClientDelegator.init()
            jerryClient.delegate = jerryDelegator
            
            expecting (count: 2){ exp in
                tomClient.createConversation(withClientIds: [jerryClient.clientId]) { [weak self] conversation, error in
                    XCTAssertNotNil(conversation?.conversationId)
                    XCTAssertNil(error)
                    self?.tomConversation = conversation
                    exp.fulfill()
                }
                jerryDelegator.invitedByClientId = { [weak self]
                    conversation, clientId in
                    XCTAssertEqual(clientId, self?.tomConversation.clientId)
                    XCTAssertEqual(conversation.conversationId, self?.tomConversation.conversationId)
                    self?.jerryConversation = conversation
                    exp.fulfill()
                }
            }
        } catch let error as NSError  {
            XCTFail(error.localizedDescription)
        }
    }
    
    override func tearDown() {
        super.tearDown()
        tomClient = nil
        jerryClient = nil
    }
    
    func testCreateWithUser() {
        guard let user = LCUser.current() else {
            return
        }
        do {
            let tom = try LCIMClient.init(user: user)
            expecting { exp in
                tom.open { ret, error in
                    XCTAssertTrue(ret)
                    XCTAssertNil(error)
                    exp.fulfill()
                }
            }
        } catch  {
            XCTFail()
        }
    }
    
    func testSendMsg() {
        
        let jerryDelegator = LCIMClientDelegator.init()
        jerryClient.delegate = jerryDelegator
        
        expecting (count: 2){ exp in
            let message = LCIMTextMessage.init(text: "haha")
            tomConversation.send(message, callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
            
            jerryDelegator.didReceiveTypedMessage = {
                conversation, typedMessage in
                if let msg = typedMessage as? LCIMTextMessage {
                    XCTAssertEqual(msg.text, message.text)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
            
        }
    }
    
    func testConversationQuery() {
        let query = tomClient.conversationQuery()
        expecting (count: 1){ exp in
            let conversationId = tomConversation.conversationId!
            query.getConversationById(conversationId) { conversiation, error in
                XCTAssertEqual(conversiation?.conversationId, conversationId)
                exp.fulfill()
            }
        }
    }
    
    
    func testAddMembers() {
        let jerryDelegator = LCIMClientDelegator.init()
        jerryClient.delegate = jerryDelegator
        expecting (count: 2){ exp in
            let members = ["Mary", "rry", "r677886555ry"]
            jerryDelegator.membersAdded = { [weak self]
                conversation, clientIds, byClientId in
                XCTAssertEqual(byClientId, self?.tomConversation.clientId)
                XCTAssertEqual(clientIds, members)
                exp.fulfill()
            }
            
            tomConversation.addMembers(withClientIds: members) { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testGroupSentMessage_kick_exit_enter() {
        let maryName = uuid
        var maryClient: LCIMClient! = try? LCIMClient.init(clientId: maryName)
        XCTAssertNotNil(maryClient)
        expecting { exp in
            maryClient.open { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        let tomDelegator = LCIMClientDelegator.init()
        tomClient.delegate = tomDelegator
        
        let jerryDelegator = LCIMClientDelegator.init()
        jerryClient.delegate = jerryDelegator
        
        let maryDelegator = LCIMClientDelegator.init()
        maryClient.delegate = maryDelegator
        
        let testDelegators = [tomDelegator, jerryDelegator, maryDelegator]
        
        // 发起群聊
        expecting (count: 7){ exp in
            let option = LCIMConversationCreationOption.init()
            option.isUnique = false
            option.timeToLive = 60
            option.name = "TestCase"
            tomClient.createConversation(withClientIds: [jerryClient.clientId, maryClient.clientId], option: option) {
                [weak self] conversation, error in
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                self?.tomConversation = conversation
                exp.fulfill()
            }
            testDelegators.forEach {
                $0.invitedByClientId = { [weak self]
                    conversation, clientId in
                    XCTAssertEqual(clientId, self?.tomConversation.clientId)
                    XCTAssertEqual(conversation.conversationId, self?.tomConversation.conversationId)
                    exp.fulfill()
                }
                $0.membersAdded = { [weak self]
                    conversation, clientIds, byClientId in
                    XCTAssertEqual(byClientId, self?.tomConversation.clientId)
                    XCTAssertEqual(conversation.conversationId, self?.tomConversation.conversationId)
                    exp.fulfill()
                }
            }
        }
        
        // 群发消息
        expecting (count: 3){ exp in
            let message = LCIMTextMessage.init(text: "haha")
            tomConversation.send(message, callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
            testDelegators.forEach {
                $0.didReceiveTypedMessage = {
                    conversation, typedMessage in
                    if let msg = typedMessage as? LCIMTextMessage {
                        XCTAssertEqual(msg.text, message.text)
                    } else {
                        XCTFail()
                    }
                    exp.fulfill()
                }
            }
        }
        
        // 踢出mary
        expecting (count: 4){ exp in
            tomConversation.removeMembers(withClientIds: [maryName]) { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
            
            maryDelegator.kickedByClientId = { [weak self]
                conversation, kickedByClientId in
                XCTAssertEqual(kickedByClientId, self?.tomConversation.clientId)
                XCTAssertEqual(conversation.conversationId, self?.tomConversation.conversationId)
                exp.fulfill()
            }
            
            testDelegators.forEach {
                $0.membersRemoved = { [weak self]
                    conversation, clientIds, byClientId in
                    XCTAssertEqual(byClientId, self?.tomConversation.clientId)
                    XCTAssertEqual(conversation.conversationId, self?.tomConversation.conversationId)
                    XCTAssertEqual(clientIds, [maryName])
                    exp.fulfill()
                }
            }
        }
        
        // mary主动加入
        let query = maryClient.conversationQuery()
        var maryConversation: LCIMConversation!
        expecting (count: 1){ exp in
            let conversationId = tomConversation.conversationId!
            query.getConversationById(conversationId) { conversiation, error in
                maryConversation = conversiation
                exp.fulfill()
            }
        }
        XCTAssertNotNil(maryConversation.conversationId)
        
        expecting (count: 5){ exp in
            maryConversation.join { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
            maryDelegator.invitedByClientId = {
                conversation, clientId in
                XCTAssertEqual(clientId, maryConversation.clientId)
                XCTAssertEqual(conversation.conversationId, maryConversation.conversationId)
                exp.fulfill()
            }
            testDelegators.forEach {
                $0.membersAdded = {
                    conversation, clientIds, byClientId in
                    XCTAssertEqual(byClientId, maryConversation.clientId)
                    XCTAssertEqual(conversation.conversationId, maryConversation.conversationId)
                    exp.fulfill()
                }
            }
        }
        
        // mary主动退出
        expecting (count: 4){ exp in
            maryConversation.quit(callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
            maryDelegator.kickedByClientId = {
                conversation, kickedByClientId in
                XCTAssertEqual(kickedByClientId, maryConversation.clientId)
                XCTAssertEqual(conversation.conversationId, maryConversation.conversationId)
                exp.fulfill()
            }
            
            testDelegators.forEach {
                $0.membersRemoved = {
                    conversation, clientIds, byClientId in
                    XCTAssertEqual(byClientId, maryConversation.clientId)
                    XCTAssertEqual(conversation.conversationId, maryConversation.conversationId)
                    XCTAssertEqual(clientIds, [maryName])
                    exp.fulfill()
                }
            }
        }
        
        maryClient = nil
    }
    
    
    func testImageMessage() {
        let jerryDelegator = LCIMClientDelegator.init()
        jerryClient.delegate = jerryDelegator
        
        let path: String! = Bundle.init(for: type(of: self)).path(forResource: "yellowicon", ofType: "png")
        XCTAssertNotNil(path)
        expecting (count: 2){ exp in
            let imageFile = try? LCFile.init(localPath: path)
            XCTAssertNotNil(imageFile)
            
            let message = LCIMImageMessage.init(text: "玉米", file: imageFile!, attributes: nil)
            tomConversation.send(message, callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
            
            jerryDelegator.didReceiveTypedMessage = {
                conversation, typedMessage in
                if let msg = typedMessage as? LCIMImageMessage {
                    XCTAssertEqual(msg.text, message.text)
                    XCTAssertNotNil(msg.url)
                    XCTAssertNotNil(msg.clientId)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }
        
        expecting (count: 2){ exp in
            let imageUrl = URL.init(string: "http://ww3.sinaimg.cn/bmiddle/596b0666gw1ed70eavm5tg20bq06m7wi.gif")
            XCTAssertNotNil(imageUrl)
            let imageFile = LCFile.init(remoteURL: imageUrl!)
            
            let message = LCIMImageMessage.init(text: "玉米", file: imageFile, attributes: nil)
            tomConversation.send(message, callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
            
            jerryDelegator.didReceiveTypedMessage = {
                conversation, typedMessage in
                if let msg = typedMessage as? LCIMImageMessage {
                    XCTAssertEqual(msg.text, message.text)
                    XCTAssertNotNil(msg.url)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }
        
    }
    
    func testFileMessage() {
        let jerryDelegator = LCIMClientDelegator.init()
        jerryClient.delegate = jerryDelegator
        
        let fileUrl = URL.init(string: "http://ww3.sinaimg.cn/bmiddle/596b0666gw1ed70eavm5tg20bq06m7wi.gif")
        XCTAssertNotNil(fileUrl)
        let file = LCFile.init(remoteURL: fileUrl!)
        
        expecting (count: 2){ exp in
            let message = LCIMAudioMessage.init(text: "玉米", file: file, attributes: nil)
            tomConversation.send(message, callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
            
            jerryDelegator.didReceiveTypedMessage = {
                conversation, typedMessage in
                if let msg = typedMessage as? LCIMAudioMessage {
                    XCTAssertEqual(msg.text, message.text)
                    XCTAssertNotNil(msg.url)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }
        
        expecting (count: 2){ exp in
            let message = LCIMVideoMessage.init(text: "玉米", file: file, attributes: nil)
            tomConversation.send(message, callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
            
            jerryDelegator.didReceiveTypedMessage = {
                conversation, typedMessage in
                if let msg = typedMessage as? LCIMVideoMessage {
                    XCTAssertEqual(msg.text, message.text)
                    XCTAssertNotNil(msg.url)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }
        
        expecting (count: 2){ exp in
            let message = LCIMFileMessage.init(text: "玉米", file: file, attributes: nil)
            tomConversation.send(message, callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
            
            jerryDelegator.didReceiveTypedMessage = {
                conversation, typedMessage in
                if let msg = typedMessage as? LCIMFileMessage {
                    XCTAssertEqual(msg.text, message.text)
                    XCTAssertNotNil(msg.url)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }
        
    }
    
    
    func testLocationMessage() {
        let jerryDelegator = LCIMClientDelegator.init()
        jerryClient.delegate = jerryDelegator
        let latitude = 31.3753285
        let longitude = 120.9664658
        expecting (count: 2){ exp in
            let message = LCIMLocationMessage.init(text: "坐标", latitude: latitude, longitude: longitude, attributes: nil)
            tomConversation.send(message, callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
            
            jerryDelegator.didReceiveTypedMessage = {
                conversation, typedMessage in
                if let msg = typedMessage as? LCIMLocationMessage {
                    XCTAssertEqual(msg.text, message.text)
                    XCTAssertEqual(latitude, msg.latitude)
                    XCTAssertEqual(longitude, msg.longitude)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }
    }
    
    func testConversationCustomAttributes() {
        let option = LCIMConversationCreationOption.init()
        option.name = "猫和老鼠"
        option.attributes = [
            "type": "private",
            "pinned": true,
        ]
        option.isUnique = false
        let jerryDelegator = LCIMClientDelegator.init()
        jerryClient.delegate = jerryDelegator
        expecting (count: 2){ exp in
            tomClient.createConversation(withClientIds: [jerryClient.clientId], option: option) {
                [weak self] conversation, error in
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                self?.tomConversation = conversation
                XCTAssertEqual(conversation?.attributes?.keys, option.attributes?.keys)
                exp.fulfill()
            }
            jerryDelegator.invitedByClientId = { [weak self]
                conversation, clientId in
                XCTAssertEqual(clientId, self?.tomConversation.clientId)
                XCTAssertEqual(conversation.conversationId, self?.tomConversation.conversationId)
                XCTAssertEqual(conversation.attributes?.keys, option.attributes?.keys)
                exp.fulfill()
            }
        }
        
        let updateName = "聪明的喵星人"
        tomConversation["name"] = updateName
        
        expecting (count: 2){ exp in
            tomConversation.update { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
            
            jerryDelegator.didUpdateAt = {[weak self]
                conversation, didUpdateAt, byClientId, updatedData, updatingData in
                XCTAssertEqual(byClientId, self?.tomConversation.clientId)
                XCTAssertEqual(conversation.conversationId, self?.tomConversation.conversationId)
                XCTAssertEqual(conversation.name, updateName)
                if let updatedData = updatedData, let name = updatedData["name"] as? String {
                    XCTAssertEqual(name, updateName)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }
    }
    
    func testGetMembers() {
        expecting { exp in
            tomConversation.fetch { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        if let count = tomConversation.members?.count {
            XCTAssertEqual(count, 2)
        } else {
            XCTFail()
        }
    }
    
    
    func testQueryMessageHistoryList() {
        var messages = [String]()
        let count = 20
        let queryCount = 10
        let otherCount = count - queryCount
        for i in 0..<count {
            messages.append("message\(i)")
        }
        
        expecting (count: count){ exp in
            messages.forEach {
                delay(seconds: 0.1)
                let message = LCIMTextMessage.init(text: $0)
                tomConversation.send(message, callback: { ret, error in
                    XCTAssertTrue(ret)
                    XCTAssertNil(error)
                    exp.fulfill()
                })
            }
        }
        var queryMessages: [LCIMMessage]!
        
        expecting { exp in
            tomConversation.queryMessages(withLimit: UInt(queryCount)) { msgs, error in
                XCTAssertNil(error)
                queryMessages = msgs
                exp.fulfill()
            }
        }
        XCTAssertNotNil(queryMessages)
        XCTAssertEqual(queryMessages.count, queryCount)
        for i in 0..<queryCount {
            if let msg = queryMessages[i] as? LCIMTextMessage, let msg = msg.text {
                XCTAssertEqual(msg, messages[i + otherCount])
            } else {
                XCTFail()
            }
        }
        
        
        expecting { exp in
            guard let messageId = queryMessages.first?.messageId,
                  let timestamp = queryMessages.first?.sendTimestamp
            else {
                XCTFail()
                return;
            }
            tomConversation.queryMessages(beforeId: messageId, timestamp: timestamp, limit: UInt(otherCount)) { msgs, error in
                XCTAssertNil(error)
                queryMessages = msgs
                exp.fulfill()
            }
        }
        
        XCTAssertNotNil(queryMessages)
        XCTAssertEqual(queryMessages.count, otherCount)
        for i in 0..<otherCount {
            if let msg = queryMessages[i] as? LCIMTextMessage, let msg = msg.text {
                XCTAssertEqual(msg, messages[i])
            } else {
                XCTFail()
            }
        }
        
        
        
    }
    
    
    
}
