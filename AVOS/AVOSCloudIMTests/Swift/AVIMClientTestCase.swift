//
//  AVIMClientTestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 2018/4/11.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVIMClientTestCase: LCIMTestBase {
    
    // MARK: - Server Testing
    
    func tests_session_open_close() {
        
        var client: AVIMClient! = AVIMClient(clientId: String(#function[..<#function.firstIndex(of: "(")!]))
        let delegate: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        client.delegate = delegate
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.open(with: .forceOpen, callback: { (succeeded: Bool, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue({ if !succeeded { client = nil }; return succeeded }())
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        if client != nil {
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                client.close(callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func tests_session_conflict() {
        
        let clientId: String = String(#function[..<#function.firstIndex(of: "(")!])
        let tag: String = "tag"
        
        let delegate1 = AVIMClientDelegateWrapper()
        var client1: AVIMClient! = {
            let client: AVIMClient  = AVIMClient(clientId: clientId, tag: tag, installation: AVInstallation())
            client.pushManager.installation.setDeviceTokenHexString(UUID().uuidString, teamId: "LeanCloud")
            client.delegate = delegate1
            return client
        }()
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client1.open(with: .forceOpen, callback: { (succeeded: Bool, error: Error?  ) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue({ if !succeeded { client1 = nil }; return succeeded }())
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        if client1 != nil {
            
            var client2: AVIMClient! = {
                let client: AVIMClient  = AVIMClient(clientId: clientId, tag: tag, installation: AVInstallation())
                client.pushManager.installation.setDeviceTokenHexString(UUID().uuidString, teamId: "LeanCloud")
                return client
            }()
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment(2)
                delegate1.didOfflineClosure = { (client: AVIMClient, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual((error as NSError?)?.code, AVIMErrorCode.sessionConflict.rawValue)
                    XCTAssertTrue(client === client1)
                }
                client2.open(with: .forceOpen, callback: { (succeeded: Bool, error: Error?  ) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue({ if !succeeded { client2 = nil }; return succeeded }())
                    XCTAssertNil(error)
                })
            }, failure: { XCTFail("timeout") })
            
            if client2 != nil {
                
                RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                    semaphore.increment()
                    client1.open(with: .reopen, callback: { (succeeded: Bool, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertFalse(succeeded)
                        XCTAssertNotNil(error)
                        XCTAssertEqual((error as NSError?)?.code, AVIMErrorCode.sessionConflict.rawValue)
                    })
                }, failure: { XCTFail("timeout") })
            }
        }
    }
    
    func tests_session_refresh() {
        
        guard let client: AVIMClient = LCIMTestBase.newOpenedClient(clientId: String(#function[..<#function.firstIndex(of: "(")!])) else {
            XCTFail()
            return
        }
        
        var oldToken: String!
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.getSessionToken(withForcingRefresh: false, callback: { (token: String?, error: Error?) in
                semaphore.decrement()
                XCTAssertNotNil(token)
                XCTAssertNil(error)
                oldToken = token
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.getSessionToken(withForcingRefresh: true, callback: { (token: String?, error: Error?) in
                semaphore.decrement()
                XCTAssertNotNil(token)
                XCTAssertNil(error)
                XCTAssertNotEqual(oldToken, token)
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func tests_session_query() {
        
        let clientId1: String = String(#function[..<#function.firstIndex(of: "(")!]) + "1"
        let clientId2: String = String(#function[..<#function.firstIndex(of: "(")!]) + "2"
        
        guard let client1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId1) else {
            XCTFail()
            return
        }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client1.queryOnlineClients(inClients: [clientId1], callback: { (clientIds: [String]?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(clientIds)
                XCTAssertNil(error)
                XCTAssertEqual(clientIds?.count, 1)
                XCTAssertEqual(clientIds?.contains(clientId1), true)
            })
        }, failure: { XCTFail("timeout") })
        
        guard let client2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId2) else {
            XCTFail()
            return
        }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client2.queryOnlineClients(inClients: [clientId1, clientId2], callback: { (clientIds: [String]?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(clientIds)
                XCTAssertNil(error)
                XCTAssertEqual(clientIds?.count, 2)
                XCTAssertEqual(clientIds?.contains(clientId1), true)
                XCTAssertEqual(clientIds?.contains(clientId2), true)
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func tests_conv_start() {
        
        let clientId1: String = String(#function[..<#function.firstIndex(of: "(")!]) + "1"
        let clientId2: String = String(#function[..<#function.firstIndex(of: "(")!]) + "2"
        let clientId3: String = String(#function[..<#function.firstIndex(of: "(")!]) + "3"
        
        guard let client: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId1) else {
            XCTFail()
            return
        }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.createConversation(withName: "name", clientIds: [clientId1, clientId2, clientId3], attributes: ["key": "value"], options: [.unique], temporaryTTL: 0, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                XCTAssertNotNil(conv?.createAt)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.createConversation(withName: nil, clientIds: [], attributes: nil, options: [.transient], temporaryTTL: 0, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                XCTAssertNotNil(conv?.createAt)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            let temporaryTTL: Int32 = 600
            client.createConversation(withName: nil, clientIds: [clientId1, clientId2], attributes: nil, options: [.temporary], temporaryTTL: temporaryTTL, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                XCTAssertNotNil(conv?.createAt)
                XCTAssertEqual(conv?.temporaryTTL, UInt(temporaryTTL))
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func tests_conv_batch_query() {
        
        let clientId: String = String(#function[..<#function.firstIndex(of: "(")!])
        guard let client: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId) else {
            XCTFail()
            return
        }
        
        let batchSize: Int = 30
        var conversationIds: Set<String> = []
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            let query: AVIMConversationQuery = client.conversationQuery()
            query.limit = batchSize
            query.cachePolicy = .networkOnly
            query.findConversations(callback: { (convs: [AVIMConversation]?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(convs)
                XCTAssertNil(error)
                for item in convs ?? [] {
                    if let convId: String = item.conversationId {
                        conversationIds.insert(convId)
                    }
                }
            })
        }, failure: { XCTFail("timeout") })
        
        if conversationIds.count < batchSize {
            for i in 0..<(batchSize - conversationIds.count) {
                RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                    semaphore.increment()
                    client.createConversation(withName: nil, clientIds: [clientId, clientId + "\(i)"], callback: { (conv: AVIMConversation?, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertNotNil(conv)
                        XCTAssertNil(error)
                        XCTAssertNotNil({
                            if let convId = conv?.conversationId {
                                conversationIds.insert(convId)
                            }
                            return conv?.conversationId }()
                        )
                    })
                }, failure: { XCTFail("timeout") })
            }
        }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.removeAllConversationsInMemory {
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
            }
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(conversationIds.count)
            client.addOperation(toInternalSerialQueue: { (_) in
                client.conversationManager.queryConversations(withIds: Array<String>(conversationIds), callback: { (conv: AVIMConversation?, error: Error?) in
                    semaphore.decrement()
                    XCTAssertNotNil(conv)
                    XCTAssertNil(error)
                    XCTAssertNotNil({
                        if let convId = conv?.conversationId {
                            XCTAssertTrue(conversationIds.contains(convId))
                        }
                        return conv?.conversationId }()
                    )
                })
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func tests_push() {
        
        let installation: AVInstallation = AVInstallation()
        installation.setDeviceTokenHexString(UUID().uuidString, teamId: "LeanCloud")
        guard let client: AVIMClient = LCIMTestBase.newOpenedClient(clientId: String(#function[..<#function.firstIndex(of: "(")!]), installation: installation) else {
            XCTFail()
            return
        }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.pushManager.saveInstallation(withAddingClientId: true, callback: { (succeeded: Bool, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.pushManager.saveInstallation(withAddingClientId: false, callback: { (succeeded: Bool, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.addOperation(toInternalSerialQueue: { (_) in
                client.pushManager.uploadingDeviceToken(false, callback: { (error: Error?) in
                    semaphore.decrement()
                    XCTAssertNil(error)
                })
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func test_goaway() {
        AVOSCloudIM.defaultOptions().rtmServer = "wss://rtm51.leancloud.cn";
        
        guard let client: AVIMClient = LCIMTestBase.newOpenedClient(clientId: String(#function[..<#function.firstIndex(of: "(")!])) else {
            XCTFail()
            return
        }
        let delegator = AVIMClientDelegateWrapper()
        client.delegate = delegator
        
        AVOSCloudIM.defaultOptions().rtmServer = nil;
        
        let exp = expectation(description: "test goaway")
        exp.expectedFulfillmentCount = 3
        LCRouter.sharedInstance().getRTMURLWithAppID(AVOSCloud.getApplicationId()) { (response, error) in
            XCTAssertNotNil(response)
            XCTAssertNil(error)
            exp.fulfill()
        }
        delegator.pausedClosure = { _ in
            exp.fulfill()
        }
        delegator.resumedClosure = { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 90)
    }
    
}
