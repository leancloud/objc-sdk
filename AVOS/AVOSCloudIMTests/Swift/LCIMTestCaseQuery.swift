//
//  LCIMTestCaseQuery.swift
//  AVOS
//
//  Created by zapcannon87 on 25/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

class LCIMTestCaseQuery: LCIMTestBase {
    
    func testFindTemporaryConversation() {
        
        guard let client: AVIMClient = LCIMTestBase.baseGlobalClient else {
            
            XCTFail()
            
            return
        }
        
        var tempConvId: String? = nil
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            semaphore.increment()
            
            client.createTemporaryConversation(
                withClientIds: [],
                timeToLive: 0
            ) { (tempConv, error) in
                
                semaphore.decrement()
                
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
            
            semaphore.increment()
            
            query.findTemporaryConversations(with: [_temoConvId]) { (array, error) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
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
