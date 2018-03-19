//
//  LCIMTestCaseClient.swift
//  AVOS
//
//  Created by zapcannon87 on 19/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

class LCIMTestCaseClient: LCIMTestBase {
    
    func test_Client_Open_Close_Multiple() {
        
        let openCloseClient: AVIMClient = AVIMClient(clientId: "LCIMTestCaseClient.testClientOpenCloseMultiple")
        
        for _ in 0..<5 {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                openCloseClient.open(callback: { (success, error) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(success)
                    XCTAssertNil(error)
                    XCTAssertEqual(openCloseClient.status, .opened)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                openCloseClient.close(callback: { (success, error) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(success)
                    XCTAssertNil(error)
                    XCTAssertEqual(openCloseClient.status, .closed)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
    func test_Create_Conversation() {
        
        guard let client: AVIMClient = LCIMTestBase.defaultGlobalClient else {
            
            XCTFail()
            
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.createConversation(
                withName: "LCIMTestCaseClient.testCreateConversation",
                clientIds: []
            ) { (conv, error) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(Thread.isMainThread)
                
                guard let conv: AVIMConversation = conv else  {
                    
                    XCTFail("\(error!)")
                    
                    return
                }
                
                XCTAssertNil(error)
                
                XCTAssertNotNil(conv.conversationId)
                XCTAssertNotNil(conv.createAt)
                
                XCTAssertFalse(conv.transient)
                XCTAssertFalse(conv.system)
                XCTAssertFalse(conv.temporary)
            }
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
    func test_Create_ChatRoom() {
        
        guard let client: AVIMClient = LCIMTestBase.defaultGlobalClient else {
            
            XCTFail()
            
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.createChatRoom(
                withName: "LCIMTestCaseClient.testCreateChatRoom",
                attributes: ["test" : "test"]
            ) { (chatRoom, error) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(Thread.isMainThread)
                
                guard let chatRoom: AVIMChatRoom = chatRoom else {
                    
                    XCTFail("\(error!)")
                    
                    return
                }
                
                XCTAssertNil(error)
                
                XCTAssertNotNil(chatRoom.conversationId)
                XCTAssertNotNil(chatRoom.createAt)
                
                XCTAssertTrue(chatRoom.transient)
                XCTAssertFalse(chatRoom.system)
                XCTAssertFalse(chatRoom.temporary)
            }
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
    func test_Create_TemporaryConversation() {
        
        guard let client: AVIMClient = LCIMTestBase.defaultGlobalClient else {
            
            XCTFail()
            
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.createTemporaryConversation(
                withClientIds: [],
                timeToLive: 0
            ) { (tempConv, error) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(Thread.isMainThread)
                
                guard let tempConv: AVIMTemporaryConversation = tempConv else {
                    
                    XCTFail("\(error!)")
                    
                    return
                }
                
                XCTAssertNil(error)
                
                let convId: String? = tempConv.conversationId
                
                XCTAssertNotNil(convId)
                XCTAssertTrue(convId!.hasPrefix(kTempConvIdPrefix))
                XCTAssertNotNil(tempConv.createAt)
                
                XCTAssertFalse(tempConv.transient)
                XCTAssertFalse(tempConv.system)
                XCTAssertTrue(tempConv.temporary)
            }
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
    func test_Create_Unique_Conversation() {
        
        guard let client: AVIMClient = LCIMTestBase.defaultGlobalClient else {
            
            XCTFail()
            
            return
        }
        
        var uniqueId: String? = nil
        
        for i in 0..<2 {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                client.createConversation(
                    withName: "LCIMTestCaseClient.testCreateUniqueConversation",
                    clientIds: ["testCreateUniqueConversation.otherId.1"],
                    attributes: nil,
                    options: [.unique]
                ) { (conv, error) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    guard let conv: AVIMConversation = conv else  {
                        
                        XCTFail("\(error!)")
                        
                        return
                    }
                    
                    XCTAssertNil(error)
                    
                    XCTAssertNotNil(conv.conversationId)
                    
                    if i == 0 {
                        
                        uniqueId = conv.conversationId
                    }
                    
                    if i == 1 {
                        
                        XCTAssertTrue(uniqueId == conv.conversationId)
                    }
                    
                    XCTAssertNotNil(conv.createAt)
                    
                    XCTAssertFalse(conv.transient)
                    XCTAssertFalse(conv.system)
                    XCTAssertFalse(conv.temporary)
                }
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
}
