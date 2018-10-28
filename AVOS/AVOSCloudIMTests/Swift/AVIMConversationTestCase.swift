//
//  AVIMConversationTestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 2018/4/18.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVIMConversationTestCase: LCIMTestBase {
    
    // MARK: - Server Testing
    
    func tests_conv_read_maxread() {
        
        let clientId1: String = String(#function[..<#function.index(of: "(")!]) + "1"
        let clientId2: String = String(#function[..<#function.index(of: "(")!]) + "2"
        
        let delegate1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId1, delegate: delegate1) else {
            XCTFail()
            return
        }
        
        guard let normalConv: AVIMConversation = LCIMTestBase.newConversation(client: client1, clientIds: [clientId1, clientId2]) else {
            XCTFail()
            return
        }
        
        let messageCount: Int = 1
        for i in 0..<messageCount {
            let content: String = "test\(i)"
            let commonMessage: AVIMMessage = AVIMMessage.init(content: content)
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                normalConv.send(commonMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
            }, failure: { XCTFail("timeout") })
        }
        
        let client2: AVIMClient = AVIMClient(clientId: clientId2)
        let delegate2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        client2.delegate = delegate2
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            /// increment is 3 because both `conv.readInBackground()` & `conv read command` will update unreadMessagesCount
            /// in this case unreadMessagesCount updated event will appear 3 times.
            semaphore.increment(3)
            delegate2.didUpdateForKeyClosure = { (conv: AVIMConversation, key: AVIMConversationUpdatedKey) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId,
                    key == AVIMConversationUpdatedKey.unreadMessagesCount
                {
                    if conv.unreadMessagesCount > 0 {
                        conv.readInBackground()
                    } else {
                        semaphore.decrement()
                    }
                }
            }
            client2.open(with: .forceOpen, callback: { (succeeded: Bool, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(2)
            delegate1.didUpdateForKeyClosure = { (conv: AVIMConversation, key: AVIMConversationUpdatedKey) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId {
                    if key == AVIMConversationUpdatedKey.lastDeliveredAt {
                        semaphore.decrement()
                    }
                    if key == AVIMConversationUpdatedKey.lastReadAt {
                        semaphore.decrement()
                    }
                }
            }
            normalConv.fetchReceiptTimestampsInBackground()
        }, failure: { XCTFail("timeout") })
    }
    
    func tests_conv_add_remove() {
        
        let clientIds: [String] = [
            String(#function[..<#function.index(of: "(")!]) + "1",
            String(#function[..<#function.index(of: "(")!]) + "2",
            String(#function[..<#function.index(of: "(")!]) + "3"
        ]
        
        let delegate1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client1 = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate1) else {
            XCTFail()
            return
        }
        
        let delegate2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client2 = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate2) else {
            XCTFail()
            return
        }
        
        let delegate3: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client3 = LCIMTestBase.newOpenedClient(clientId: clientIds[2], delegate: delegate3) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        let originMemberIds: [String] = [client1.clientId, client2.clientId]
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(3)
            var convId: String? = nil
            delegate1.membersAddedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                XCTAssertTrue(Thread.isMainThread)
                if convId == conv.conversationId {
                    semaphore.decrement()
                    XCTAssertEqual(members?.count, originMemberIds.count)
                    XCTAssertEqual(conv.members?.count, originMemberIds.count)
                    XCTAssertEqual(members?.contains(client1.clientId), true)
                    XCTAssertEqual(members?.contains(client2.clientId), true)
                    XCTAssertEqual(conv.members?.contains(client1.clientId), true)
                    XCTAssertEqual(conv.members?.contains(client2.clientId), true)
                    XCTAssertEqual(byId, client1.clientId)
                }
            }
            delegate2.membersAddedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                XCTAssertTrue(Thread.isMainThread)
                if convId == conv.conversationId {
                    semaphore.decrement()
                    XCTAssertEqual(members?.count, originMemberIds.count)
                    XCTAssertEqual(conv.members?.count, originMemberIds.count)
                    XCTAssertEqual(members?.contains(client1.clientId), true)
                    XCTAssertEqual(members?.contains(client2.clientId), true)
                    XCTAssertEqual(conv.members?.contains(client1.clientId), true)
                    XCTAssertEqual(conv.members?.contains(client2.clientId), true)
                    XCTAssertEqual(byId, client1.clientId)
                }
            }
            client1.createConversation(withName: nil, clientIds: originMemberIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
                convId = conv?.conversationId
            })
        }, failure: { XCTFail("timeout") })
        
        if normalConv != nil {
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment(4)
                delegate1.membersAddedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                    XCTAssertTrue(Thread.isMainThread)
                    if conv.conversationId == normalConv.conversationId {
                        semaphore.decrement()
                        XCTAssertEqual(members?.count, 1)
                        XCTAssertEqual(members?.first, client3.clientId)
                        XCTAssertEqual(conv.members?.count, clientIds.count)
                        XCTAssertEqual(conv.members?.contains(client1.clientId), true)
                        XCTAssertEqual(conv.members?.contains(client2.clientId), true)
                        XCTAssertEqual(conv.members?.contains(client3.clientId), true)
                        XCTAssertEqual(byId, client1.clientId)
                    }
                }
                delegate2.membersAddedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                    XCTAssertTrue(Thread.isMainThread)
                    if conv.conversationId == normalConv.conversationId {
                        semaphore.decrement()
                        XCTAssertEqual(members?.count, 1)
                        XCTAssertEqual(members?.first, client3.clientId)
                        XCTAssertEqual(conv.members?.count, clientIds.count)
                        XCTAssertEqual(conv.members?.contains(client1.clientId), true)
                        XCTAssertEqual(conv.members?.contains(client2.clientId), true)
                        XCTAssertEqual(conv.members?.contains(client3.clientId), true)
                        XCTAssertEqual(byId, client1.clientId)
                    }
                }
                delegate3.invitedByClosure = { (conv: AVIMConversation, byId: String?) in
                    XCTAssertTrue(Thread.isMainThread)
                    if conv.conversationId == normalConv.conversationId {
                        semaphore.decrement()
                        XCTAssertEqual(conv.members?.count, clientIds.count)
                        XCTAssertEqual(conv.members?.contains(client1.clientId), true)
                        XCTAssertEqual(conv.members?.contains(client2.clientId), true)
                        XCTAssertEqual(conv.members?.contains(client3.clientId), true)
                        XCTAssertEqual(byId, client1.clientId)
                    }
                }
                normalConv.addMembers(withClientIds: [client3.clientId], callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
            }, failure: { XCTFail("timeout") })
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment(4)
                delegate1.membersRemovedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                    XCTAssertTrue(Thread.isMainThread)
                    if conv.conversationId == normalConv.conversationId {
                        semaphore.decrement()
                        XCTAssertEqual(members?.count, 1)
                        XCTAssertEqual(members?.first, client3.clientId)
                        XCTAssertEqual(conv.members?.count, originMemberIds.count)
                        XCTAssertEqual(conv.members?.contains(client1.clientId), true)
                        XCTAssertEqual(conv.members?.contains(client2.clientId), true)
                        XCTAssertEqual(conv.members?.contains(client3.clientId), false)
                        XCTAssertEqual(byId, client1.clientId)
                    }
                }
                delegate2.membersRemovedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                    XCTAssertTrue(Thread.isMainThread)
                    if conv.conversationId == normalConv.conversationId {
                        semaphore.decrement()
                        XCTAssertEqual(members?.count, 1)
                        XCTAssertEqual(members?.first, client3.clientId)
                        XCTAssertEqual(conv.members?.count, originMemberIds.count)
                        XCTAssertEqual(conv.members?.contains(client1.clientId), true)
                        XCTAssertEqual(conv.members?.contains(client2.clientId), true)
                        XCTAssertEqual(conv.members?.contains(client3.clientId), false)
                        XCTAssertEqual(byId, client1.clientId)
                    }
                }
                delegate3.kickedByClosure = { (conv: AVIMConversation, byId: String?) in
                    XCTAssertTrue(Thread.isMainThread)
                    if conv.conversationId == normalConv.conversationId {
                        semaphore.decrement()
                        XCTAssertEqual(conv.members?.count, originMemberIds.count)
                        XCTAssertEqual(conv.members?.contains(client1.clientId), true)
                        XCTAssertEqual(conv.members?.contains(client2.clientId), true)
                        XCTAssertEqual(conv.members?.contains(client3.clientId), false)
                        XCTAssertEqual(byId, client1.clientId)
                    }
                }
                normalConv.removeMembers(withClientIds: [client3.clientId], callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func tests_conv_count() {
        
        let clientId1: String = String(#function[..<#function.index(of: "(")!]) + "1"
        let clientId2: String = String(#function[..<#function.index(of: "(")!]) + "2"
        
        guard let client1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId1) else {
            XCTFail()
            return
        }
        
        guard let client2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId2) else {
            XCTFail()
            return
        }
        
        guard
            let chatRoom: AVIMChatRoom = LCIMTestBase.newConversation(client: client1, clientIds: [], name: nil, attributes: nil, options: [.transient], temporaryTTL: 0) as? AVIMChatRoom,
            let chatRoomId: String = chatRoom.conversationId else
        {
            XCTFail()
            return
        }
        
        let query: AVIMConversationQuery = client2.conversationQuery()
        query.cachePolicy = .networkOnly
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(3)
            query.getConversationById(chatRoomId, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                if let conv: AVIMConversation = conv {
                    conv.join(callback: { (succeeded: Bool, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                        if succeeded {
                            chatRoom.countMembers(callback: { (count: Int, error: Error?) in
                                semaphore.decrement()
                                XCTAssertTrue(Thread.isMainThread)
                                XCTAssertEqual(count, 2)
                                XCTAssertNil(error)
                            })
                        } else {
                            semaphore.decrement()
                            XCTFail()
                        }
                    })
                } else {
                    semaphore.decrement(2)
                    XCTFail()
                }
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func tests_conv_update() {
        
        let clientId1: String = String(#function[..<#function.index(of: "(")!]) + "1"
        let clientId2: String = String(#function[..<#function.index(of: "(")!]) + "2"
        
        let delegate1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId1, delegate: delegate1) else {
            XCTFail()
            return
        }
        
        let delegate2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let _: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId2, delegate: delegate2) else {
            XCTFail()
            return
        }
        
        let attrPrefix: String = "attr"
        let upsetKey: String = "upsetKey"
        let upsetValue: String = "upsetValue"
        let deleteKey: String = "deleteKey"
        let deleteValue: String = "deleteValue"
        let deleteOp: [String: Any] = [ "__op" : "Delete" ]
        
        guard let normalConv: AVIMConversation = LCIMTestBase.newConversation(client: client1, clientIds: [clientId1, clientId2], name: nil, attributes: [deleteKey : deleteValue], options: [], temporaryTTL: 0) else {
            XCTFail()
            return
        }
        
        normalConv["\(attrPrefix).\(upsetKey)"] = upsetValue
        normalConv["\(attrPrefix).\(deleteKey)"] = deleteOp
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(2)
            delegate2.updateByClosure = { (conv: AVIMConversation, date: Date?, clientId: String?, data: [AnyHashable: Any]?) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId {
                    semaphore.decrement()
                    XCTAssertNotNil(date)
                    XCTAssertEqual(clientId, client1.clientId)
                    XCTAssertNotNil(data)
                    XCTAssertEqual((data?[attrPrefix] as? [AnyHashable : Any])?[upsetKey] as? String, upsetValue)
                    XCTAssertNil((data?[attrPrefix] as? [AnyHashable : Any])?[deleteKey])
                    XCTAssertNotNil(conv.attributes)
                    XCTAssertEqual(conv.attributes?[upsetKey] as? String, upsetValue)
                    XCTAssertNil(conv.attributes?[deleteKey])
                }
            }
            normalConv.update(callback: { (succeeded: Bool, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                XCTAssertNotNil(normalConv.attributes)
                XCTAssertEqual(normalConv.attributes?[upsetKey] as? String, upsetValue)
                XCTAssertNil(normalConv.attributes?[deleteKey])
            })
            
        }, failure: { XCTFail("timeout") })
    }
    
    func tests_conv_mute_unmute() {
        
        let clientId1: String = String(#function[..<#function.index(of: "(")!]) + "1"
        let clientId2: String = String(#function[..<#function.index(of: "(")!]) + "2"
        
        guard let client: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId1) else {
            XCTFail()
            return
        }
        
        guard let normalConv: AVIMConversation = LCIMTestBase.newConversation(client: client, clientIds: [clientId1, clientId2]) else {
            XCTFail()
            return
        }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            normalConv.mute(callback: { (succeeded: Bool, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                XCTAssertTrue(normalConv.muted)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            normalConv.unmute(callback: { (succeeded: Bool, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                XCTAssertFalse(normalConv.muted)
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func tests_conv_query() {
        
        let clientId1: String = "\(#function[..<#function.index(of: "(")!])" + "1"
        let clientId2: String = "\(#function[..<#function.index(of: "(")!])" + "2"
        
        guard let client: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId1) else {
            XCTFail()
            return
        }
        
        guard
            let normalConv: AVIMConversation = LCIMTestBase.newConversation(client: client, clientIds: [clientId1, clientId2]),
            let normalConvId: String = normalConv.conversationId else
        {
            XCTFail()
            return
        }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            let query: AVIMConversationQuery = client.conversationQuery()
            query.cachePolicy = .networkOnly
            semaphore.increment()
            query.getConversationById(normalConvId, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertEqual(conv?.conversationId, normalConvId)
            })
        }, failure: { XCTFail("timeout") })
        
        guard
            let tempConv: AVIMTemporaryConversation = LCIMTestBase.newConversation(client: client, clientIds: [clientId1, clientId2], name: nil, attributes: nil, options: [.temporary], temporaryTTL: 600) as? AVIMTemporaryConversation,
            let tempConvId: String = tempConv.conversationId else {
                XCTFail()
                return
        }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            let query: AVIMConversationQuery = client.conversationQuery()
            query.cachePolicy = .networkOnly
            query.findTemporaryConversations(with: [tempConvId], callback: { (tempConvs: [AVIMTemporaryConversation]?, error: Error?    ) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(tempConvs)
                XCTAssertNil(error)
                XCTAssertNotNil(tempConvs?.first)
                XCTAssertEqual(tempConvs?.first?.conversationId, tempConvId)
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func tests_conv_memberinfo_get_update() {
        
        let clientId1: String = String(#function[..<#function.index(of: "(")!]) + "1"
        let clientId2: String = String(#function[..<#function.index(of: "(")!]) + "2"
        let clientId3: String = String(#function[..<#function.index(of: "(")!]) + "3"
        
        let delegate1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId1, delegate: delegate1) else {
            XCTFail()
            return
        }
        
        let delegate2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let _: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId2, delegate: delegate2) else {
            XCTFail()
            return
        }
        
        let delegate3: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let _: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId3, delegate: delegate3) else {
            XCTFail()
            return
        }
        
        guard let normalConv: AVIMConversation = LCIMTestBase.newConversation(client: client1, clientIds: [clientId1, clientId2, clientId3]) else {
            XCTFail()
            return
        }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(3)
            delegate2.memberInfoChangeClosure = { (conv: AVIMConversation, byClientId: String?, memberId: String?, role: AVIMConversationMemberRole) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId {
                    semaphore.decrement()
                    XCTAssertEqual(byClientId, clientId1)
                    XCTAssertEqual(memberId, clientId2)
                    XCTAssertEqual(role, .manager)
                }
            }
            delegate3.memberInfoChangeClosure = { (conv: AVIMConversation, byClientId: String?, memberId: String?, role: AVIMConversationMemberRole) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId {
                    semaphore.decrement()
                    XCTAssertEqual(byClientId, clientId1)
                    XCTAssertEqual(memberId, clientId2)
                    XCTAssertEqual(role, .manager)
                }
            }
            normalConv.updateMemberRole(withMemberId: clientId2, role: .manager, callback: { (succeeded: Bool, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            normalConv.getAllMemberInfo(withIgnoringCache: true, callback: { (memberInfos: [AVIMConversationMemberInfo]?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(memberInfos)
                XCTAssertNil(error)
                XCTAssertEqual(memberInfos?.count, 2)
                if let memberInfos: [AVIMConversationMemberInfo] = memberInfos {
                    var dic: [String : AVIMConversationMemberInfo] = [:]
                    for item in memberInfos where item.memberId() != nil {
                        dic[item.memberId()!] = item
                    }
                    XCTAssertEqual(dic[clientId1]?.role(), .owner)
                    XCTAssertEqual(dic[clientId2]?.role(), .manager)
                }
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func tests_blacklist_block_query_unblock() {
        
        let clientId1: String = String(#function[..<#function.index(of: "(")!]) + "1"
        let clientId2: String = String(#function[..<#function.index(of: "(")!]) + "2"
        let clientId3: String = String(#function[..<#function.index(of: "(")!]) + "3"
        let clientId4: String = String(#function[..<#function.index(of: "(")!]) + "4"
        
        let delegate1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId1, delegate: delegate1) else {
            XCTFail()
            return
        }
        
        let delegate2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let _: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId2, delegate: delegate2) else {
            XCTFail()
            return
        }
        
        let delegate3: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let _: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId3, delegate: delegate3) else {
            XCTFail()
            return
        }
        
        guard let normalConv: AVIMConversation = LCIMTestBase.newConversation(client: client1, clientIds: [clientId1, clientId2, clientId3]) else {
            XCTFail()
            return
        }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(3)
            delegate2.blockByClosure = { (conv: AVIMConversation, byClientId: String?) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId {
                    semaphore.decrement()
                    XCTAssertEqual(byClientId, clientId1)
                }
            }
            delegate3.membersBlockByClosure = { (conv: AVIMConversation, byClientId: String?, memberIds: [String]?) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId {
                    semaphore.decrement()
                    XCTAssertEqual(byClientId, clientId1)
                    XCTAssertEqual(memberIds?.count, 1)
                    XCTAssertEqual(memberIds?.first, clientId2)
                }
            }
            normalConv.blockMembers([clientId2, clientId4], callback: { (blockedIds: [String]?, failedOps: [AVIMOperationFailure]?, error: Error?) in
                XCTAssertTrue(Thread.isMainThread)
                semaphore.decrement()
                XCTAssertNotNil(blockedIds)
                XCTAssertEqual(blockedIds?.count, 1)
                XCTAssertEqual(blockedIds?.first, clientId2)
                XCTAssertNotNil(failedOps)
                XCTAssertEqual(failedOps?.count, 1)
                XCTAssertEqual(failedOps?.first?.clientIds?.count, 1)
                XCTAssertEqual(failedOps?.first?.clientIds?.first, clientId4)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            normalConv.queryBlockedMembers(withLimit: 10, next: nil, callback: { (blockedMemberIds: [String]?, next: String?, error: Error?) in
                XCTAssertTrue(Thread.isMainThread)
                semaphore.decrement()
                XCTAssertNotNil(blockedMemberIds)
                XCTAssertEqual(blockedMemberIds?.count, 1)
                XCTAssertEqual(blockedMemberIds?.first, clientId2)
                XCTAssertNil(next)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(3)
            delegate2.unblockByClosure = { (conv: AVIMConversation, byClientId: String?) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId {
                    semaphore.decrement()
                    XCTAssertEqual(byClientId, clientId1)
                }
            }
            delegate3.membersUnblockByClosure = { (conv: AVIMConversation, byClientId: String?, memberIds: [String]?) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId {
                    semaphore.decrement()
                    XCTAssertEqual(byClientId, clientId1)
                    XCTAssertEqual(memberIds?.count, 1)
                    XCTAssertEqual(memberIds?.first, clientId2)
                }
            }
            normalConv.unblockMembers([clientId2], callback: { (blockedIds: [String]?, failedOps: [AVIMOperationFailure]?, error: Error?) in
                XCTAssertTrue(Thread.isMainThread)
                semaphore.decrement()
                XCTAssertNotNil(blockedIds)
                XCTAssertEqual(blockedIds?.count, 1)
                XCTAssertEqual(blockedIds?.first, clientId2)
                XCTAssertNotNil(failedOps)
                XCTAssertEqual(failedOps?.count, 0)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func tests_conv_shutup_add_query_remove() {
        
        let clientId1: String = String(#function[..<#function.index(of: "(")!]) + "1"
        let clientId2: String = String(#function[..<#function.index(of: "(")!]) + "2"
        let clientId3: String = String(#function[..<#function.index(of: "(")!]) + "3"
        let clientId4: String = String(#function[..<#function.index(of: "(")!]) + "4"
        
        let delegate1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId1, delegate: delegate1) else {
            XCTFail()
            return
        }
        
        let delegate2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let _: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId2, delegate: delegate2) else {
            XCTFail()
            return
        }
        
        let delegate3: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let _: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId3, delegate: delegate3) else {
            XCTFail()
            return
        }
        
        guard let normalConv: AVIMConversation = LCIMTestBase.newConversation(client: client1, clientIds: [clientId1, clientId2, clientId3]) else {
            XCTFail()
            return
        }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(3)
            delegate2.muteByClosure = { (conv: AVIMConversation, byClientId: String?) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId {
                    semaphore.decrement()
                    XCTAssertEqual(byClientId, clientId1)
                }
            }
            delegate3.membersMuteByClosure = { (conv: AVIMConversation, byClientId: String?, memberIds: [String]?) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId {
                    semaphore.decrement()
                    XCTAssertEqual(byClientId, clientId1)
                    XCTAssertEqual(memberIds?.count, 1)
                    XCTAssertEqual(memberIds?.first, clientId2)
                }
            }
            normalConv.muteMembers([clientId2, clientId4], callback: { (mutedIds: [String]?, failedOps: [AVIMOperationFailure]?, error: Error?) in
                XCTAssertTrue(Thread.isMainThread)
                semaphore.decrement()
                XCTAssertNotNil(mutedIds)
                XCTAssertEqual(mutedIds?.count, 1)
                XCTAssertEqual(mutedIds?.first, clientId2)
                XCTAssertNotNil(failedOps)
                XCTAssertEqual(failedOps?.count, 1)
                XCTAssertEqual(failedOps?.first?.clientIds?.count, 1)
                XCTAssertEqual(failedOps?.first?.clientIds?.first, clientId4)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            normalConv.queryMutedMembers(withLimit: 10, next: nil, callback: { (mutedMemberIds: [String]?, next: String?, error: Error?) in
                XCTAssertTrue(Thread.isMainThread)
                semaphore.decrement()
                XCTAssertNotNil(mutedMemberIds)
                XCTAssertEqual(mutedMemberIds?.count, 1)
                XCTAssertEqual(mutedMemberIds?.first, clientId2)
                XCTAssertNil(next)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(3)
            delegate2.unmuteByClosure = { (conv: AVIMConversation, byClientId: String?) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId {
                    semaphore.decrement()
                    XCTAssertEqual(byClientId, clientId1)
                }
            }
            delegate3.membersUnmuteByClosure = { (conv: AVIMConversation, byClientId: String?, memberIds: [String]?) in
                XCTAssertTrue(Thread.isMainThread)
                if conv.conversationId == normalConv.conversationId {
                    semaphore.decrement()
                    XCTAssertEqual(byClientId, clientId1)
                    XCTAssertEqual(memberIds?.count, 1)
                    XCTAssertEqual(memberIds?.first, clientId2)
                }
            }
            normalConv.unmuteMembers([clientId2], callback: { (mutedIds: [String]?, failedOps: [AVIMOperationFailure]?, error: Error?) in
                XCTAssertTrue(Thread.isMainThread)
                semaphore.decrement()
                XCTAssertNotNil(mutedIds)
                XCTAssertEqual(mutedIds?.count, 1)
                XCTAssertEqual(mutedIds?.first, clientId2)
                XCTAssertNotNil(failedOps)
                XCTAssertEqual(failedOps?.count, 0)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
    }
    
}
