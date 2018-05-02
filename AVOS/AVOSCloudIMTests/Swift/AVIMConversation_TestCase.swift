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
    
    // MARK: - Member Block
    
    func test_block_unblock_member_query_blocked_member() {
        
        let cliendIds: [String] = [
            "test_conv_block_member_1",
            "test_conv_block_member_2",
            "test_conv_block_member_3",
            "test_conv_block_member_4"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: cliendIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: cliendIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        let delegate_3: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_3: AVIMClient = self.newOpenedClient(clientId: cliendIds[3], delegate: delegate_3) else {
            XCTFail()
            return
        }
        
        var conversation_0: AVIMConversation!
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client_1.createConversation(withName: nil, clientIds: cliendIds, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                
                if let _conversation: AVIMConversation = conversation,
                    let _: String = conversation?.conversationId {
                    
                    conversation_0 = _conversation
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        let blockingId_1: String = cliendIds[1]
        let blockingId_2: String = cliendIds[2]
        
        if conversation_0 != nil {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(4)
                
                delegate_1.membersBlockByClosure = { (conv: AVIMConversation, byId: String?, mIds: [String]?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv.conversationId, conversation_0.conversationId)
                    XCTAssertEqual(byId, client_1.clientId)
                    XCTAssertEqual(mIds?.count, 2)
                    XCTAssertTrue((mIds ?? []).contains(blockingId_1))
                    XCTAssertTrue((mIds ?? []).contains(blockingId_2))
                }
                
                delegate_2.blockByClosure = { (conv: AVIMConversation, byId: String?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv.conversationId, conversation_0.conversationId)
                    XCTAssertEqual(byId, client_1.clientId)
                }
                
                delegate_3.membersBlockByClosure = { (conv: AVIMConversation, byId: String?, mIds: [String]?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv.conversationId, conversation_0.conversationId)
                    XCTAssertEqual(byId, client_1.clientId)
                    XCTAssertEqual(mIds?.count, 2)
                    XCTAssertTrue((mIds ?? []).contains(blockingId_1))
                    XCTAssertTrue((mIds ?? []).contains(blockingId_2))
                }
                
                conversation_0.blockMembers([blockingId_1, blockingId_2], callback: { (successfulIds: [String]?, failedIds: [AVIMOperationFailure]?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(successfulIds)
                    XCTAssertNotNil(failedIds)
                    XCTAssertNil(error)
                    
                    if let _successfulIds: [String] = successfulIds,
                        let _failedIds: [AVIMOperationFailure] = failedIds {
                        
                        XCTAssertEqual(_successfulIds.count, 2)
                        XCTAssertTrue(_successfulIds.contains(blockingId_1))
                        XCTAssertTrue(_successfulIds.contains(blockingId_2))
                        XCTAssertEqual(_failedIds.count, 0)
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(3)
                
                conversation_0.queryBlockedMembers(withLimit: 0, next: nil, callback: { (blockedIds: [String]?, next_1: String?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(blockedIds)
                    XCTAssertEqual(blockedIds?.count, 2)
                    XCTAssertTrue((blockedIds ?? []).contains(blockingId_1))
                    XCTAssertTrue((blockedIds ?? []).contains(blockingId_2))
                    XCTAssertTrue((next_1 ?? "").isEmpty)
                    XCTAssertNil(error)
                })
                
                conversation_0.queryBlockedMembers(withLimit: 1, next: nil, callback: { (blockedIds: [String]?, next_2: String?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(blockedIds)
                    XCTAssertEqual(blockedIds?.count, 1)
                    XCTAssertTrue(
                        (blockedIds?.first ?? "") == blockingId_1 ||
                            (blockedIds?.first ?? "") == blockingId_2
                    )
                    XCTAssertNotNil(next_2)
                    XCTAssertNotEqual(next_2, "")
                    XCTAssertNil(error)
                    
                    conversation_0.queryBlockedMembers(withLimit: 0, next: next_2, callback: { (blockedIds_0: [String]?, next_3: String?, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotNil(blockedIds_0)
                        XCTAssertEqual(blockedIds_0?.count, 1)
                        XCTAssertTrue(
                            (blockedIds_0?.first ?? "") == blockingId_1 ||
                                (blockedIds_0?.first ?? "") == blockingId_2
                        )
                        XCTAssertNotEqual(blockedIds_0?.first, blockedIds?.first)
                        XCTAssertTrue((next_3 ?? "").isEmpty)
                        XCTAssertNil(error)
                    })
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(4)
                
                delegate_1.membersUnblockByClosure = { (conv: AVIMConversation, byId: String?, mIds: [String]?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv.conversationId, conversation_0.conversationId)
                    XCTAssertEqual(byId, client_1.clientId)
                    XCTAssertEqual(mIds?.count, 2)
                    XCTAssertTrue((mIds ?? []).contains(blockingId_1))
                    XCTAssertTrue((mIds ?? []).contains(blockingId_2))
                }
                
                delegate_2.unblockByClosure = { (conv: AVIMConversation, byId: String?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv.conversationId, conversation_0.conversationId)
                    XCTAssertEqual(byId, client_1.clientId)
                }
                
                delegate_3.membersUnblockByClosure = { (conv: AVIMConversation, byId: String?, mIds: [String]?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv.conversationId, conversation_0.conversationId)
                    XCTAssertEqual(byId, client_1.clientId)
                    XCTAssertEqual(mIds?.count, 2)
                    XCTAssertTrue((mIds ?? []).contains(blockingId_1))
                    XCTAssertTrue((mIds ?? []).contains(blockingId_2))
                }
                
                conversation_0.unblockMembers([blockingId_1, blockingId_2], callback: { (successfulIds: [String]?, failedIds: [AVIMOperationFailure]?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(successfulIds)
                    XCTAssertNotNil(failedIds)
                    XCTAssertNil(error)
                    
                    if let _successfulIds: [String] = successfulIds,
                        let _failedIds: [AVIMOperationFailure] = failedIds {
                        
                        XCTAssertEqual(_successfulIds.count, 2)
                        XCTAssertTrue(_successfulIds.contains(blockingId_1))
                        XCTAssertTrue(_successfulIds.contains(blockingId_2))
                        XCTAssertEqual(_failedIds.count, 0)
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        self.recycleClient(client_3)
        self.recycleClient(client_2)
        self.recycleClient(client_1)
    }
    
    func test_failure_block_member() {
        
        let clientIds: [String] = [
            "test_failure_block_member_1",
            "test_failure_block_member_2",
            "test_failure_block_member_3"
        ]
        let invalidMemberId: String = "test_failure_block_member_0"
        
        guard let client: AVIMClient = self.newOpenedClient(clientId: clientIds[0]) else {
            XCTFail()
            return
        }
        
        var aConversation: AVIMConversation!
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.createConversation(withName: nil, clientIds: clientIds, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                
                if let conv: AVIMConversation = conversation {
                    
                    aConversation = conv
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        if let conversation: AVIMConversation = aConversation {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                conversation.blockMembers([invalidMemberId], callback: { (successfulIds: [String]?, failedIds: [AVIMOperationFailure]?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(successfulIds)
                    XCTAssertEqual(successfulIds?.count, 0)
                    XCTAssertNotNil(failedIds)
                    XCTAssertEqual(failedIds?.count, 1)
                    if let operationFailure: AVIMOperationFailure = failedIds?.first {
                        XCTAssertTrue(operationFailure.code > 0)
                        XCTAssertNotNil(operationFailure.reason)
                        XCTAssertNotNil(operationFailure.clientIds)
                        XCTAssertEqual(operationFailure.clientIds?.count, 1)
                        XCTAssertEqual(operationFailure.clientIds?.first, invalidMemberId)
                    }
                    XCTAssertNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        self.recycleClient(client)
    }
    
    // MARK: - Member Mute
    
    func test_mute_unmute_member_query_muted_member() {
        
        let clientIds: [String] = [
            "test_conv_shutup_member_1",
            "test_conv_shutup_member_2",
            "test_conv_shutup_member_3",
            "test_conv_shutup_member_4"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        let delegate_3: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_3: AVIMClient = self.newOpenedClient(clientId: clientIds[3], delegate: delegate_3) else {
            XCTFail()
            return
        }
        
        var conversation_0: AVIMConversation!
        
        let mutingMembers: [String] = [
            clientIds[1],
            clientIds[2]
        ]
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment(5)
            
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conversation: AVIMConversation?, error: Error?) in
              
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                
                if let _conversation: AVIMConversation = conversation {
                    
                    conversation_0 = _conversation
                    
                    delegate_1.membersMuteByClosure = { (conversation: AVIMConversation, byClientId: String?, memberIds: [String]?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertEqual(conversation, _conversation)
                        XCTAssertNotNil(byClientId)
                        XCTAssertEqual(_conversation.clientId, byClientId)
                        XCTAssertNotNil(memberIds)
                        XCTAssertEqual(memberIds?.count, mutingMembers.count)
                        for item in (memberIds ?? []) {
                            XCTAssertTrue(mutingMembers.contains(item))
                        }
                    }
                    
                    delegate_2.muteByClosure = { (conversation: AVIMConversation, byClientId: String?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotEqual(conversation, _conversation)
                        XCTAssertNotNil(byClientId)
                        XCTAssertEqual(_conversation.clientId, byClientId)
                    }
                    
                    delegate_3.membersMuteByClosure = { (conversation: AVIMConversation, byClientId: String?, memberIds: [String]?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotEqual(conversation, _conversation)
                        XCTAssertNotNil(byClientId)
                        XCTAssertEqual(_conversation.clientId, byClientId)
                        XCTAssertNotNil(memberIds)
                        XCTAssertEqual(memberIds?.count, mutingMembers.count)
                        for item in (memberIds ?? []) {
                            XCTAssertTrue(mutingMembers.contains(item))
                        }
                    }
                    
                    _conversation.muteMembers(mutingMembers, callback: { (successfulIds: [String]?, failedIds: [AVIMOperationFailure]?, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotNil(successfulIds)
                        XCTAssertEqual(successfulIds?.count, mutingMembers.count)
                        for item in (successfulIds ?? []) {
                            XCTAssertTrue(mutingMembers.contains(item))
                        }
                        XCTAssertNotNil(failedIds)
                        XCTAssertEqual(failedIds?.count, 0)
                        XCTAssertNil(error)
                    })
                    
                } else {
                    
                    semaphore.decrement(4)
                }
            })
        }, failure: {
            
            conversation_0 = nil
            
            XCTFail("timeout")
        })
        
        if let conversation: AVIMConversation = conversation_0 {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(3)
                
                let limit: Int = 1
                
                conversation.queryMutedMembers(withLimit: limit, next: nil) { (mutedMembers_1: [String]?, next_1: String?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(mutedMembers_1)
                    XCTAssertEqual(mutedMembers_1?.count, limit)
                    for item in (mutedMembers_1 ?? []) {
                        XCTAssertTrue(mutingMembers.contains(item))
                    }
                    XCTAssertNotNil(next_1)
                    XCTAssertNil(error)
                    
                    conversation.queryMutedMembers(withLimit: 0, next: next_1, callback: { (mutedMembers_2: [String]?, next_2: String?, error: Error?) in

                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotNil(mutedMembers_2)
                        XCTAssertEqual(mutedMembers_2?.count, mutingMembers.count - limit)
                        for item in (mutedMembers_2 ?? []) {
                            XCTAssertTrue(mutingMembers.contains(item))
                            XCTAssertFalse((mutedMembers_1 ?? []).contains(item))
                        }
                        XCTAssertTrue(next_2 == nil || (next_2 ?? "").isEmpty)
                        XCTAssertNil(error)
                    })
                }
                
                conversation.queryMutedMembers(withLimit: 0, next: nil, callback: { (mutedMembers: [String]?, next: String?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(mutedMembers)
                    XCTAssertEqual(mutedMembers?.count, mutingMembers.count)
                    for item in (mutedMembers ?? []) {
                        XCTAssertTrue(mutingMembers.contains(item))
                    }
                    XCTAssertTrue(next == nil || (next ?? "").isEmpty)
                    XCTAssertNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        if let conversation: AVIMConversation = conversation_0 {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(4)
                
                delegate_1.membersUnmuteByClosure = { (conv: AVIMConversation, byClientId: String?, memberIds: [String]?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv, conversation)
                    XCTAssertNotNil(byClientId)
                    XCTAssertEqual(conversation.clientId, byClientId)
                    XCTAssertNotNil(memberIds)
                    XCTAssertEqual(memberIds?.count, mutingMembers.count)
                    for item in (memberIds ?? []) {
                        XCTAssertTrue(mutingMembers.contains(item))
                    }
                }
                
                delegate_2.unmuteByClosure = { (conv: AVIMConversation, byClientId: String?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotEqual(conv, conversation)
                    XCTAssertNotNil(byClientId)
                    XCTAssertEqual(conversation.clientId, byClientId)
                }
                
                delegate_3.membersUnmuteByClosure = { (conv: AVIMConversation, byClientId: String?, memberIds: [String]?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotEqual(conv, conversation)
                    XCTAssertNotNil(byClientId)
                    XCTAssertEqual(conversation.clientId, byClientId)
                    XCTAssertNotNil(memberIds)
                    XCTAssertEqual(memberIds?.count, mutingMembers.count)
                    for item in (memberIds ?? []) {
                        XCTAssertTrue(mutingMembers.contains(item))
                    }
                }
                
                conversation.unmuteMembers(mutingMembers, callback: { (successfulIds: [String]?, failedIds: [AVIMOperationFailure]?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(successfulIds)
                    XCTAssertEqual(successfulIds?.count, mutingMembers.count)
                    for item in (successfulIds ?? []) {
                        XCTAssertTrue(mutingMembers.contains(item))
                    }
                    XCTAssertNotNil(failedIds)
                    XCTAssertEqual(failedIds?.count, 0)
                    XCTAssertNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        self.recycleClient(client_3)
        self.recycleClient(client_2)
        self.recycleClient(client_1)
    }
    
    func test_failure_mute_member() {
        
        let clientIds: [String] = [
            "test_failure_mute_member_1",
            "test_failure_mute_member_2",
            "test_failure_mute_member_3"
        ]
        let invalidMemberId: String = "test_failure_mute_member_0"
        
        guard let client: AVIMClient = self.newOpenedClient(clientId: clientIds[0]) else {
            XCTFail()
            return
        }
        
        var aConversation: AVIMConversation!
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.createConversation(withName: nil, clientIds: clientIds, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                
                if let conv: AVIMConversation = conversation {
                    
                    aConversation = conv
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        if let conversation: AVIMConversation = aConversation {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                conversation.muteMembers([invalidMemberId], callback: { (successfulIds: [String]?, failedIds: [AVIMOperationFailure]?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(successfulIds)
                    XCTAssertEqual(successfulIds?.count, 0)
                    XCTAssertNotNil(failedIds)
                    XCTAssertEqual(failedIds?.count, 1)
                    if let operationFailure: AVIMOperationFailure = failedIds?.first {
                        XCTAssertTrue(operationFailure.code > 0)
                        XCTAssertNotNil(operationFailure.reason)
                        XCTAssertNotNil(operationFailure.clientIds)
                        XCTAssertEqual(operationFailure.clientIds?.count, 1)
                        XCTAssertEqual(operationFailure.clientIds?.first, invalidMemberId)
                    }
                    XCTAssertNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        self.recycleClient(client)
    }
    
}
