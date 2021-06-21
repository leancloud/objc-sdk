//
//  IMMessageTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2021/01/25.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

class IMMessageTestCase: RTMBaseTestCase {
    
    func testSendMessageToChatRoom() {
        guard let client1 = newOpenedClient(clientIDSuffix: "1") else {
            XCTFail()
            return
        }
        purgeConnectionRegistry()
        guard let client2 = newOpenedClient(clientIDSuffix: "2"),
              let client3 = newOpenedClient(clientIDSuffix: "3") else {
            XCTFail()
            return
        }
        purgeConnectionRegistry()
        guard let client4 = newOpenedClient(clientIDSuffix: "4") else {
            XCTFail()
            return
        }
        
        let delegator1 = LCIMClientDelegator()
        client1.delegate = delegator1
        let delegator2 = LCIMClientDelegator()
        client2.delegate = delegator2
        let delegator3 = LCIMClientDelegator()
        client3.delegate = delegator3
        let delegator4 = LCIMClientDelegator()
        client4.delegate = delegator4
        var chatRoom1: LCIMChatRoom?
        var chatRoom2: LCIMChatRoom?
        var chatRoom3: LCIMChatRoom?
        var chatRoom4: LCIMChatRoom?
        
        expecting(count: 7) { (exp) in
            client1.createChatRoom() { (chatRoom, error) in
                XCTAssertNil(error)
                chatRoom1 = chatRoom
                exp.fulfill()
                if let ID = chatRoom1?.conversationId {
                    client2.conversationQuery().getConversationById(ID) { (conv, error) in
                        XCTAssertNil(error)
                        chatRoom2 = conv as? LCIMChatRoom
                        exp.fulfill()
                        chatRoom2?.join(callback: { (success, error) in
                            XCTAssertTrue(success)
                            XCTAssertNil(error)
                            exp.fulfill()
                            client3.conversationQuery().getConversationById(ID) { (conv, error) in
                                XCTAssertNil(error)
                                chatRoom3 = conv as? LCIMChatRoom
                                exp.fulfill()
                                chatRoom3?.join(callback: { (success, error) in
                                    XCTAssertTrue(success)
                                    XCTAssertNil(error)
                                    exp.fulfill()
                                    client4.conversationQuery().getConversationById(ID) { (conv, error) in
                                        XCTAssertNil(error)
                                        chatRoom4 = conv as? LCIMChatRoom
                                        exp.fulfill()
                                        chatRoom4?.join(callback: { (success, error) in
                                            XCTAssertTrue(success)
                                            XCTAssertNil(error)
                                            exp.fulfill()
                                        })
                                    }
                                })
                            }
                        })
                    }
                }
            }
        }
        
        delay()
        
        expecting(count: 8) { (exp) in
            delegator1.didReceiveTypedMessage = { _, _ in
                exp.fulfill()
            }
            delegator2.didReceiveTypedMessage = { _, _ in
                exp.fulfill()
            }
            delegator3.didReceiveTypedMessage = { _, _ in
                exp.fulfill()
            }
            delegator4.didReceiveTypedMessage = { _, _ in
                exp.fulfill()
            }
            let options = LCIMMessageOption()
            options.priority = .high
            chatRoom1?.send(LCIMTextMessage(text: "1", attributes: nil), option: options, callback: { (success, error) in
                XCTAssertTrue(success)
                XCTAssertNil(error)
                exp.fulfill()
                chatRoom2?.send(LCIMTextMessage(text: "2", attributes: nil), option: options, callback: { (success, error) in
                    XCTAssertTrue(success)
                    XCTAssertNil(error)
                    exp.fulfill()
                })
            })
        }
        
        delegator1.reset()
        delegator2.reset()
        delegator3.reset()
        delegator4.reset()
    }
    
    func testUpdateAndRecallMessage() {
        guard let client1 = newOpenedClient(clientIDSuffix: "1"),
              let client2 = newOpenedClient(clientIDSuffix: "2") else {
            XCTFail()
            return
        }
        
        let delegator1 = LCIMClientDelegator()
        client1.delegate = delegator1
        let delegator2 = LCIMClientDelegator()
        client2.delegate = delegator2
        var conv: LCIMConversation?
        
        expecting { exp in
            client1.createConversation(withClientIds: [client2.clientId]) { conversation, error in
                if let conversation = conversation {
                    conv = conversation
                    exp.fulfill()
                } else {
                    XCTAssertNil(error)
                }
            }
        }
        
        let oldMessage = LCIMTextMessage(text: "old")
        expecting(description: "send message", count: 2) { exp in
            delegator2.didReceiveTypedMessage = { conversation, message in
                exp.fulfill()
            }
            conv?.send(oldMessage, callback: { succeeded, error in
                if succeeded {
                    exp.fulfill()
                } else {
                    XCTAssertNil(error)
                }
            })
        }
        
        delay()
        
        let newMessage = LCIMTextMessage(text: "new")
        expecting(description: "update message", count: 2) { exp in
            delegator2.messageHasBeenUpdated = { conversation, message, _ in
                exp.fulfill()
            }
            conv?.update(oldMessage, toNewMessage: newMessage, callback: { succeeded, error in
                if succeeded {
                    exp.fulfill()
                } else {
                    XCTAssertNil(error)
                }
            })
        }
        
        delay()
        
        expecting(description: "recall message", count: 2) { exp in
            delegator2.messageHasBeenRecalled = { conversation, message, _ in
                exp.fulfill()
            }
            conv?.recall(newMessage, callback: { succeeded, error, recalledMessage in
                if succeeded {
                    XCTAssertNotNil(recalledMessage)
                    exp.fulfill()
                } else {
                    XCTAssertNil(error)
                }
            })
        }
    }
    
    func testMessageCache() {
        guard let client1 = newOpenedClient(clientIDSuffix: "1") else {
            XCTFail()
            return
        }
        
        var conv: LCIMConversation?
        
        expecting { exp in
            client1.createConversation(withClientIds: [uuid]) { conversation, error in
                if let conversation = conversation {
                    conv = conversation
                    exp.fulfill()
                } else {
                    XCTAssertNil(error)
                }
            }
        }
        
        delay()
        
        let failedMessage = LCIMTextMessage(text: "failed")
        failedMessage.status = .failed
        conv?.addMessage(toCache: failedMessage)
        let result = conv?.queryMessagesFromCache(withLimit: 10)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual((result?.first as? LCIMMessage)?.status, .failed)
    }
}

extension IMMessageTestCase {
    
    func newOpenedClient(
        clientID: String? = nil,
        clientIDSuffix: String? = nil) -> LCIMClient?
    {
        var ID = clientID ?? uuid
        if let suffix = clientIDSuffix {
            ID += "-\(suffix)"
        }
        var client: LCIMClient? = try! LCIMClient(clientId: ID)
        expecting { (exp) in
            client?.open(callback: { (success, error) in
                XCTAssertTrue(success)
                XCTAssertNil(error)
                if !success {
                    client = nil
                }
                exp.fulfill()
            })
        }
        return client
    }
}
