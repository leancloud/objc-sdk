//
//  AVIMClient_TestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 2018/4/11.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVIMClient_TestCase: LCIMTestBase {
    
    // MARK: - Client Open
    
    func test_client_open_with_avuser() {
        
        var aUser: AVUser! = nil;
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            let user: AVUser = AVUser()
            user.username = "\(#function)\(#line)"
            user.password = "12345678"
            
            semaphore.increment()
            semaphore.increment()
            
            user.signUpInBackground({ (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                if let _ = error {
                    
                    AVUser.logInWithUsername(inBackground: user.username!, password: user.password!, block: { (user: AVUser?, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotNil(user)
                        XCTAssertNotNil(user?.objectId)
                        XCTAssertNotNil(user?.sessionToken)
                        
                        if let _ = user?.objectId, let _ = user?.sessionToken {
                            
                            aUser = user;
                        }
                    })
                    
                } else {
                    
                    semaphore.decrement()
                    
                    XCTAssertNotNil(user.objectId)
                    XCTAssertNotNil(user.sessionToken)
                    
                    if let _ = user.objectId, let _ = user.sessionToken {
                        
                        aUser = user;
                    }
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        guard aUser != nil else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            let client: AVIMClient = AVIMClient(user: aUser)
            
            semaphore.increment()
            
            client.open(callback: { (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
    // MARK: - Temporary Conversation
    
    func test_create_temp_conv() {
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: "\(#function.substring(to: #function.index(of: "(")!))_\(#line)", delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: "\(#function.substring(to: #function.index(of: "(")!))_\(#line)", delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment(5)
            
            let clientIds: [String] = [client_1.clientId, client_2.clientId]
            
            delegate_1.invitedByClosure = { (conv: AVIMConversation, byClientId: String?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertEqual(byClientId, client_1.clientId)
                
                XCTAssertTrue((conv.conversationId ?? "").hasPrefix(kTemporaryConversationIdPrefix))
                XCTAssertTrue(conv.isKind(of: AVIMTemporaryConversation.self))
            }
            
            delegate_1.membersAddedClosure = { (conv: AVIMConversation, memberIds: [String]?, byClientId: String?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(memberIds)
                XCTAssertEqual(memberIds?.count, clientIds.count)
                XCTAssertNotNil((memberIds ?? []).contains(client_1.clientId))
                XCTAssertNotNil((memberIds ?? []).contains(client_2.clientId))
                XCTAssertEqual(byClientId, client_1.clientId)
                
                XCTAssertTrue((conv.conversationId ?? "").hasPrefix(kTemporaryConversationIdPrefix))
                XCTAssertTrue(conv.isKind(of: AVIMTemporaryConversation.self))
            }
            
            delegate_2.invitedByClosure = { (conv: AVIMConversation, byClientId: String?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertEqual(byClientId, client_1.clientId)
                
                XCTAssertTrue((conv.conversationId ?? "").hasPrefix(kTemporaryConversationIdPrefix))
                XCTAssertTrue(conv.isKind(of: AVIMTemporaryConversation.self))
            }
            
            delegate_2.membersAddedClosure = { (conv: AVIMConversation, memberIds: [String]?, byClientId: String?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(memberIds)
                XCTAssertEqual(memberIds?.count, clientIds.count)
                XCTAssertNotNil((memberIds ?? []).contains(client_1.clientId))
                XCTAssertNotNil((memberIds ?? []).contains(client_2.clientId))
                XCTAssertEqual(byClientId, client_1.clientId)
                
                XCTAssertTrue((conv.conversationId ?? "").hasPrefix(kTemporaryConversationIdPrefix))
                XCTAssertTrue(conv.isKind(of: AVIMTemporaryConversation.self))
            }
            
            client_1.createTemporaryConversation(withClientIds: clientIds, timeToLive: 0, callback: { (conversation: AVIMTemporaryConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                if let conv: AVIMTemporaryConversation = conversation,
                    let convId: String = conv.conversationId {
                    XCTAssertTrue(convId.hasPrefix(kTemporaryConversationIdPrefix))
                    XCTAssertTrue(conv.isKind(of: AVIMTemporaryConversation.self))
                }
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        self.recycleClient(client_1)
        self.recycleClient(client_2)
    }
    
    func test_client_create_conversation() {
        
        guard let client: AVIMClient = self.newOpenedClient(clientId: "\(#function)\(#line)") else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.createConversation(withName: nil, clientIds: [], attributes: nil, options: [], temporaryTTL: 0, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertTrue(conversation?.isMember(of: AVIMConversation.self) == true)
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            let name: String = "\(#function)\(#line)"
            let clientId: String = "\(#function)\(#line)"
            let testKey: String = "\(#function)\(#line)"
            let testValue: String = "\(#function)\(#line)"
            let attributes: [String : Any] = [testKey : testValue]
            
            semaphore.increment()
            semaphore.increment()
            
            client.createConversation(withName: name, clientIds: [clientId], attributes: attributes, options: [], temporaryTTL: 0, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertTrue(conversation?.isMember(of: AVIMConversation.self) == true)
                XCTAssertNil(error)
                
                if let conversationId: String = conversation?.conversationId {
                    
                    client.conversationQuery().getConversationById(conversationId, callback: { (conversation: AVIMConversation?, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotNil(conversation)
                        XCTAssertEqual(conversationId, conversation?.conversationId)
                        XCTAssertTrue(conversation?.isMember(of: AVIMConversation.self) == true)
                        XCTAssertNil(error)
                        
                        XCTAssertEqual(name, conversation?.name)
                        XCTAssertTrue( ((conversation?.members as? [String])?.count == 2) &&
                            ((conversation?.members as? [String])?.contains(clientId) == true) &&
                            ((conversation?.members as? [String])?.contains(client.clientId) == true)
                        )
                        XCTAssertTrue( (conversation?.attributes?.count == 1) &&
                            ((conversation?.attributes?.keys.first as? String) == testKey) &&
                            ((conversation?.attributes?[testKey] as? String) == testValue)
                        )
                    })
                    
                } else {
                    
                    XCTFail()
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.createConversation(withName: nil, clientIds: [], attributes: nil, options: [.transient], temporaryTTL: 0, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertTrue(conversation?.isMember(of: AVIMChatRoom.self) == true)
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.createConversation(withName: nil, clientIds: [], attributes: nil, options: [.temporary], temporaryTTL: 0, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertTrue(conversation?.isMember(of: AVIMTemporaryConversation.self) == true)
                XCTAssertTrue((conversation?.temporaryTTL ?? 0) > 0)
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.createConversation(withName: nil, clientIds: [], attributes: nil, options: [.unique], temporaryTTL: 0, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNotNil(conversation?.uniqueId)
                XCTAssertTrue(conversation?.isMember(of: AVIMConversation.self) == true)
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        self.recycleClient(client)
    }
    
    func test_client_refresh_session_token() {
        
        guard let client: AVIMClient = self.newOpenedClient(clientId: "\(#function)\(#line)") else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            semaphore.increment()
            
            client.getSessionToken(withForcingRefresh: false, callback: { (token: String?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(!Thread.isMainThread)
                
                XCTAssertNotNil(token)
                XCTAssertNil(error)
                
                if let _token: String = token {
                    
                    client.getSessionToken(withForcingRefresh: true, callback: { (token: String?, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(!Thread.isMainThread)
                        
                        XCTAssertNotNil(token)
                        XCTAssertNil(error)
                        XCTAssertNotEqual(_token, token)
                    })
                    
                } else {
                    
                    semaphore.decrement()
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        self.recycleClient(client)
    }
    
}

class AVIMClientDelegate_TestCase: NSObject, AVIMClientDelegate {
    
    var invitedByClosure: ((AVIMConversation, String?) -> Void)?
    var kickedByClosure: ((AVIMConversation, String?) -> Void)?
    var membersAddedClosure: ((AVIMConversation, [String]?, String?) -> Void)?
    var membersRemovedClosure: ((AVIMConversation, [String]?, String?) -> Void)?
    var memberInfoChangeClosure: ((AVIMConversation, String?, String?, String?) -> Void)?
    var blockByClosure: ((AVIMConversation, String?) -> Void)?
    var unblockByClosure: ((AVIMConversation, String?) -> Void)?
    var membersBlockByClosure: ((AVIMConversation, String?, [String]?) -> Void)?
    var membersUnblockByClosure: ((AVIMConversation, String?, [String]?) -> Void)?
    var muteByClosure: ((AVIMConversation, String?) -> Void)?
    var unmuteByClosure: ((AVIMConversation, String?) -> Void)?
    var membersMuteByClosure: ((AVIMConversation, String?, [String]?) -> Void)?
    var membersUnmuteByClosure: ((AVIMConversation, String?, [String]?) -> Void)?
    
    func imClientPaused(_ imClient: AVIMClient) {}
    func imClientResuming(_ imClient: AVIMClient) {}
    func imClientResumed(_ imClient: AVIMClient) {}
    func imClientClosed(_ imClient: AVIMClient, error: Error?) {}
    
    func conversation(_ conversation: AVIMConversation, invitedByClientId clientId: String?) {
        self.invitedByClosure?(conversation, clientId)
    }
    
    func conversation(_ conversation: AVIMConversation, kickedByClientId clientId: String?) {
        self.kickedByClosure?(conversation, clientId)
    }
    
    func conversation(_ conversation: AVIMConversation, membersAdded clientIds: [String]?, byClientId clientId: String?) {
        self.membersAddedClosure?(conversation, clientIds, clientId)
    }
    
    func conversation(_ conversation: AVIMConversation, membersRemoved clientIds: [String]?, byClientId clientId: String?) {
        self.membersRemovedClosure?(conversation, clientIds, clientId)
    }
    
    func conversation(_ conversation: AVIMConversation, didMemberInfoUpdateBy byClientId: String?, memberId: String?, role: String?) {
        self.memberInfoChangeClosure?(conversation, byClientId, memberId, role)
    }
    
    func conversation(_ conversation: AVIMConversation, didBlockBy byClientId: String?) {
        self.blockByClosure?(conversation, byClientId)
    }
    
    func conversation(_ conversation: AVIMConversation, didUnblockBy byClientId: String?) {
        self.unblockByClosure?(conversation, byClientId)
    }
    
    func conversation(_ conversation: AVIMConversation, didMembersBlockBy byClientId: String?, memberIds: [String]?) {
        self.membersBlockByClosure?(conversation, byClientId, memberIds)
    }
    
    func conversation(_ conversation: AVIMConversation, didMembersUnblockBy byClientId: String?, memberIds: [String]?) {
        self.membersUnblockByClosure?(conversation, byClientId, memberIds)
    }
    
    func conversation(_ conversation: AVIMConversation, didMuteBy byClientId: String?) {
        self.muteByClosure?(conversation, byClientId)
    }
    
    func conversation(_ conversation: AVIMConversation, didMembersMuteBy byClientId: String?, memberIds: [String]?) {
        self.membersMuteByClosure?(conversation, byClientId, memberIds)
    }
    
    func conversation(_ conversation: AVIMConversation, didUnmuteBy byClientId: String?) {
        self.unmuteByClosure?(conversation, byClientId)
    }
    
    func conversation(_ conversation: AVIMConversation, didMembersUnmuteBy byClientId: String?, memberIds: [String]?) {
        self.membersUnmuteByClosure?(conversation, byClientId, memberIds)
    }
    
}
