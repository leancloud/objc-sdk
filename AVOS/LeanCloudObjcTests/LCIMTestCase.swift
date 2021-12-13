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
            tomClient = try LCIMClient.init(clientId: "Tom")
            jerryClient = try LCIMClient.init(clientId: "Jerry")
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
                jerryDelegator.didUpdateForKey = { [weak jerryDelegator]
                    conversation, updateKey in
                    XCTAssertNotNil(conversation.conversationId)
                    self.jerryConversation = conversation
                    jerryDelegator?.didUpdateForKey = nil
                    exp.fulfill()
                }
            }
        } catch let error as NSError  {
            XCTFail(error.localizedDescription)
        }
    }
    
    override func tearDown() {
        super.tearDown()
        self.tomClient = nil
        self.jerryClient = nil
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
    
    
//    func testTypedMessage() {
//        let jerryDelegator = LCIMClientDelegator.init()
//        jerryClient.delegate = jerryDelegator
//        expecting (count: 2){ exp in
//            let members = ["Mary", "rry", "r677886555ry"]
//            jerryDelegator.membersAdded = { [weak self]
//                conversation, clientIds, byClientId in
//                XCTAssertEqual(byClientId, self?.tomConversation.clientId)
//                XCTAssertEqual(clientIds, members)
//                exp.fulfill()
//            }
//            
//            tomConversation.addMembers(withClientIds: members) { ret, error in
//                XCTAssertTrue(ret)
//                XCTAssertNil(error)
//                exp.fulfill()
//            }
//        }
//    }
    


}
