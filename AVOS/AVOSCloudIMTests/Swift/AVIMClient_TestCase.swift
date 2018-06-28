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
        
        var aUser: AVUser! = nil
        
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
                            
                            aUser = user
                        }
                    })
                    
                } else {
                    
                    semaphore.decrement()
                    
                    XCTAssertNotNil(user.objectId)
                    XCTAssertNotNil(user.sessionToken)
                    
                    if let _ = user.objectId, let _ = user.sessionToken {
                        
                        aUser = user
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
    
    // MARK: - Create Conversation
    
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
    }
    
    // MARK: - Session Token
    
    func test_refresh_session_token() {
        
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
    }
    
    // MARK: - Session Conflict
    
    func test_session_conflict() {
        
        let clientId: String = "\(#function.substring(to: #function.index(of: "(")!))"
        let tag: String = "tag"
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        let installation_1: AVInstallation = AVInstallation()
        installation_1.deviceToken = UUID().uuidString
        guard let _: AVIMClient = self.newOpenedClient(clientId: clientId, tag: tag, delegate: delegate_1, installation: installation_1) else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment(2)
            
            delegate_1.didOfflineClosure = { (client: AVIMClient, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(error)
                let _err: NSError? = error as NSError?
                XCTAssertEqual(_err?.code, 4111)
                XCTAssertEqual(_err?.domain, kLeanCloudErrorDomain)
            }
            
            let installation_2: AVInstallation = AVInstallation()
            installation_2.deviceToken = UUID().uuidString
            let client_2: AVIMClient = AVIMClient(clientId: clientId, tag: tag, installation: installation_2)
            
            client_2.open(with: .forceOpen, callback: { (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
}

class AVIMClientDelegate_TestCase: NSObject, AVIMClientDelegate {
    
    var didReceiveTypeMessageClosure: ((AVIMConversation, AVIMTypedMessage) -> Void)?
    var didReceiveCommonMessageClosure: ((AVIMConversation, AVIMMessage) -> Void)?
    var didOfflineClosure: ((AVIMClient, Error?) -> Void)?
    var messageHasBeenUpdatedClosure: ((AVIMConversation, AVIMMessage) -> Void)?
    var messageDeliveredClosure: ((AVIMConversation, AVIMMessage) -> Void)?
    var didUpdateForKeyClosure: ((AVIMConversation, AVIMConversationUpdatedKey) -> Void)?
    var updateByClosure: ((AVIMConversation, Date?, String?, [AnyHashable : Any]?) -> Void)?
    var invitedByClosure: ((AVIMConversation, String?) -> Void)?
    var kickedByClosure: ((AVIMConversation, String?) -> Void)?
    var membersAddedClosure: ((AVIMConversation, [String]?, String?) -> Void)?
    var membersRemovedClosure: ((AVIMConversation, [String]?, String?) -> Void)?
    var memberInfoChangeClosure: ((AVIMConversation, String?, String?, AVIMConversationMemberRole) -> Void)?
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
    
    func conversation(_ conversation: AVIMConversation, didReceive message: AVIMTypedMessage) {
        self.didReceiveTypeMessageClosure?(conversation, message)
    }
    
    func conversation(_ conversation: AVIMConversation, didReceiveCommonMessage message: AVIMMessage) {
        self.didReceiveCommonMessageClosure?(conversation, message)
    }
    
    func client(_ client: AVIMClient, didOfflineWithError error: Error?) {
        self.didOfflineClosure?(client, error)
    }
    
    func conversation(_ conversation: AVIMConversation, messageHasBeenUpdated message: AVIMMessage) {
        self.messageHasBeenUpdatedClosure?(conversation, message)
    }
    
    func conversation(_ conversation: AVIMConversation, messageDelivered message: AVIMMessage) {
        self.messageDeliveredClosure?(conversation, message)
    }
    
    func conversation(_ conversation: AVIMConversation, didUpdateForKey key: AVIMConversationUpdatedKey) {
        self.didUpdateForKeyClosure?(conversation, key)
    }
    
    func conversation(_ conversation: AVIMConversation, didUpdateAt date: Date?, byClientId clientId: String?, updatedData data: [AnyHashable : Any]?) {
        self.updateByClosure?(conversation, date, clientId, data)
    }
    
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
    
    func conversation(_ conversation: AVIMConversation, didMemberInfoUpdateBy byClientId: String?, memberId: String?, role: AVIMConversationMemberRole) {
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
