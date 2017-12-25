//
//  LCIMTestCaseClient.swift
//  AVOS
//
//  Created by zapcannon87 on 19/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

class LCIMTestCaseClient: LCIMTestBase {
    
    var globalClient: AVIMClient?
    
    override func setUp() {
        
        super.setUp()
        
        var _globalClient: AVIMClient? = AVIMClient(clientId: "LCIMTestCaseClient.globalClient")
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            _globalClient!.open(callback: { (success, error) in
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
                XCTAssertEqual(_globalClient!.status, .opened)
                
                semaphore.breakWaiting = true
            })
            
        }) {
            
            XCTFail("timeout")
            
            _globalClient = nil
        }
        
        self.globalClient = _globalClient
    }
    
    override func tearDown() {
        
        super.tearDown()
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            self.globalClient?.close(callback: { (success, error) in
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
                XCTAssertEqual(self.globalClient?.status, .closed)
                
                semaphore.breakWaiting = true
            })
            
        }) {
            
            XCTFail("timeout")
        }
    }
    
    func testClientOpenClose() {
        
        let openCloseClient: AVIMClient = AVIMClient(clientId: "LCIMTestCaseClient.testClientOpenClose")
        
        for _ in 0..<5 {
            
            if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
                
                openCloseClient.open(callback: { (success, error) in
                    
                    XCTAssertTrue(success)
                    XCTAssertNil(error)
                    XCTAssertEqual(openCloseClient.status, .opened)
                    
                    semaphore.breakWaiting = true
                })
                
            }) {
                
                XCTFail("timeout")
            }
            
            if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
                
                openCloseClient.close(callback: { (success, error) in
                    
                    XCTAssertTrue(success)
                    XCTAssertNil(error)
                    XCTAssertEqual(openCloseClient.status, .closed)
                    
                    semaphore.breakWaiting = true
                })
                
            }) {
                
                XCTFail("timeout")
            }
        }
    }
    
    func testClientCreateConversation() {
        
        guard let client: AVIMClient = self.globalClient else {
            
            XCTFail()
            
            return
        }
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            client.createConversation(
                withName: "LCIMTestCaseClient.testClientCreateConversation.1",
                clientIds: []
            ) { (conv, error) in
                
                semaphore.breakWaiting = true
                
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
            
        }) {
            
            XCTFail("timeout")
        }
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            client.createChatRoom(
                withName: "LCIMTestCaseClient.testClientCreateConversation.2",
                attributes: ["test" : "test"]
            ) { (chatRoom, error) in
                
                semaphore.breakWaiting = true
                
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
            
        }) {
            
            XCTFail("timeout")
        }
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            client.createTemporaryConversation(
                withClientIds: [],
                timeToLive: 0
            ) { (tempConv, error) in
                
                semaphore.breakWaiting = true
                
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
            
        }) {
            
            XCTFail("timeout")
        }
    }
    
    func testFindTemporaryConversation() {
        
        guard let client: AVIMClient = self.globalClient else {
            
            XCTFail()
            
            return
        }
        
        var tempConvId: String? = nil
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            client.createTemporaryConversation(
                withClientIds: [],
                timeToLive: 0
            ) { (tempConv, error) in
                
                semaphore.breakWaiting = true
                
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
                
                tempConvId = convId
            }
            
        }) {
            
            XCTFail("timeout")
        }
        
        guard let _temoConvId: String = tempConvId else {
            
            XCTFail()
            
            return
        }
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            let query: AVIMConversationQuery = client.conversationQuery()
            
            query.cachePolicy = .networkOnly
            
            query.findTemporaryConversations(with: [_temoConvId]) { (array, error) in
                
                semaphore.breakWaiting = true
                
                guard let tempConv: AVIMTemporaryConversation = array?.first as? AVIMTemporaryConversation else {
                    
                    XCTFail("\(error!)")
                    
                    return
                }
                
                XCTAssertNil(error)
                
                let convId: String? = tempConv.conversationId
                
                XCTAssertNotNil(convId)
                XCTAssertTrue(convId == _temoConvId)
                XCTAssertTrue(convId!.hasPrefix(kTempConvIdPrefix))
                XCTAssertNotNil(tempConv.createAt)
                
                XCTAssertFalse(tempConv.transient)
                XCTAssertFalse(tempConv.system)
                XCTAssertTrue(tempConv.temporary)
                XCTAssertTrue(tempConv.temporaryTTL > 0)
            }
            
            
        }) {
            
            XCTFail("timeout")
        }
    }
    
}
