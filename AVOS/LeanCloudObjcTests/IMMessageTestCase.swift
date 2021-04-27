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
        var chatRoom1: AVIMChatRoom?
        var chatRoom2: AVIMChatRoom?
        var chatRoom3: AVIMChatRoom?
        var chatRoom4: AVIMChatRoom?
        
        expecting(count: 7) { (exp) in
            client1.createChatRoom(withName: nil, attributes: nil) { (chatRoom, error) in
                XCTAssertNil(error)
                chatRoom1 = chatRoom
                exp.fulfill()
                if let ID = chatRoom1?.conversationId {
                    client2.conversationQuery().getConversationById(ID) { (conv, error) in
                        XCTAssertNil(error)
                        chatRoom2 = conv as? AVIMChatRoom
                        exp.fulfill()
                        chatRoom2?.join(callback: { (success, error) in
                            XCTAssertTrue(success)
                            XCTAssertNil(error)
                            exp.fulfill()
                            client3.conversationQuery().getConversationById(ID) { (conv, error) in
                                XCTAssertNil(error)
                                chatRoom3 = conv as? AVIMChatRoom
                                exp.fulfill()
                                chatRoom3?.join(callback: { (success, error) in
                                    XCTAssertTrue(success)
                                    XCTAssertNil(error)
                                    exp.fulfill()
                                    client4.conversationQuery().getConversationById(ID) { (conv, error) in
                                        XCTAssertNil(error)
                                        chatRoom4 = conv as? AVIMChatRoom
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
            let options = AVIMMessageOption()
            options.priority = .high
            chatRoom1?.send(AVIMTextMessage(text: "1", attributes: nil), option: options, callback: { (success, error) in
                XCTAssertTrue(success)
                XCTAssertNil(error)
                exp.fulfill()
                chatRoom2?.send(AVIMTextMessage(text: "2", attributes: nil), option: options, callback: { (success, error) in
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
        var client: LCIMClient? = try! LCIMClient(clientId: ID, error: ())
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
