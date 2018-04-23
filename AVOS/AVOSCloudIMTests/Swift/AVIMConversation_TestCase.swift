//
//  AVIMConversation_TestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 2018/4/18.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVIMConversation_TestCase: LCIMTestBase {
    
    // MARK: - Member Info
    
    let test_conv_member_info_clientIds: [String] = [
        "test_conv_member_info_1",
        "test_conv_member_info_2",
        "test_conv_member_info_3"
    ]
    
    func test_get_all_member_info() {
        
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: self.test_conv_member_info_clientIds[0]) else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment().increment()
            
            client_1.createConversation(withName: nil, clientIds: self.test_conv_member_info_clientIds, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                
                if let _conversation: AVIMConversation = conversation {
                    
                    _conversation.getAllMemberInfo(withIgnoringCache: true, callback: { (memberInfos: [AVIMConversationMemberInfo]?, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotNil(memberInfos)
                        XCTAssertNil(error)
                    })
                    
                } else {
                    
                    semaphore.decrement()
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        self.recycleClient(client_1)
    }
    
    func test_get_member_info() {
        
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: self.test_conv_member_info_clientIds[0]) else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment().increment().increment()
            
            client_1.createConversation(withName: nil, clientIds: self.test_conv_member_info_clientIds, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                
                if let _conversation: AVIMConversation = conversation {
                    
                    let memberId: String = self.test_conv_member_info_clientIds[1]
                    let role: AVIMConversationMemberRole = .manager
                    
                    _conversation.updateMemberRole(withMemberId: memberId, role: role, callback: { (succeeded: Bool, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                        
                        if succeeded {
                            
                            _conversation.getMemberInfo(withMemberId: memberId, callback: { (memberInfo: AVIMConversationMemberInfo?, error: Error?) in
                                
                                semaphore.decrement()
                                XCTAssertTrue(Thread.isMainThread)
                                
                                XCTAssertNotNil(memberInfo)
                                XCTAssertNil(error)
                                
                                if let _memberInfo: AVIMConversationMemberInfo = memberInfo {
                                    XCTAssertEqual(_memberInfo.memberId(), memberId)
                                    XCTAssertEqual(_memberInfo.role(), role)
                                    XCTAssertEqual(_memberInfo.conversationId(), _conversation.conversationId)
                                    if memberId == client_1.clientId {
                                        XCTAssertTrue(_memberInfo.isOwner())
                                    } else {
                                        XCTAssertFalse(_memberInfo.isOwner())
                                    }
                                }
                            })
                            
                        } else {
                            
                            semaphore.decrement().decrement()
                        }
                    })
                    
                } else {
                    
                    semaphore.decrement()
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        self.recycleClient(client_1)
    }
    
    func test_update_member_info_role() {
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: self.test_conv_member_info_clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: self.test_conv_member_info_clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment().increment().increment().increment()
            
            client_1.createConversation(withName: nil, clientIds: self.test_conv_member_info_clientIds, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                
                if let _conversation: AVIMConversation = conversation {
                    
                    let updatingRole: AVIMConversationMemberRole = .manager
                    
                    delegate_1.memberInfoChangeClosure = { (conv: AVIMConversation, byClientId: String?, memberId: String?, role: String?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertEqual(conv.conversationId, _conversation.conversationId)
                        XCTAssertEqual(byClientId, client_1.clientId)
                        XCTAssertEqual(memberId, client_2.clientId)
                        XCTAssertEqual(role, AVIMConversationMemberInfo_StringFromRole(updatingRole))
                    }
                    
                    delegate_2.memberInfoChangeClosure = { (conv: AVIMConversation, byClientId: String?, memberId: String?, role: String?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertEqual(conv.conversationId, _conversation.conversationId)
                        XCTAssertEqual(byClientId, client_1.clientId)
                        XCTAssertEqual(memberId, client_2.clientId)
                        XCTAssertEqual(role, AVIMConversationMemberInfo_StringFromRole(updatingRole))
                    }
                    
                    _conversation.updateMemberRole(withMemberId: client_2.clientId, role: updatingRole, callback: { (succeeded: Bool, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                        
                        if error != nil {
                            
                            semaphore.decrement().decrement()
                        }
                    })
                    
                } else {
                    
                    semaphore.decrement().decrement().decrement()
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        self.recycleClient(client_1)
        self.recycleClient(client_2)
    }
    
}
