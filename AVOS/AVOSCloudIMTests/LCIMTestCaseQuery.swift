//
//  LCIMTestCaseQuery.swift
//  AVOS
//
//  Created by zapcannon87 on 25/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

class LCIMTestCaseQuery: LCIMTestBase {
    
    var globalClient: AVIMClient?
    
    override func setUp() {
        
        super.setUp()
        
        var client: AVIMClient? = AVIMClient(clientId: "LCIMTestCaseQuery.globalClient")
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            client!.open(callback: { (success, error) in
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
                XCTAssertEqual(client!.status, .opened)
                
                semaphore.breakWaiting = true
            })
            
        }) {
            
            XCTFail("timeout")
            
            client = nil
        }
        
        self.globalClient = client
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
