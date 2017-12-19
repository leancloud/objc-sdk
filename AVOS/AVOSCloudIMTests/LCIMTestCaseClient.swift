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
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        let globalClient: AVIMClient = AVIMClient(clientId: "LCIMTestCaseClient.globalClient");
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            globalClient.open(callback: { (success, error) in
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
                XCTAssertEqual(globalClient.status, .opened)
                
                semaphore.breakWaiting = true;
            })
            
        }) {
            
            XCTFail("timeout")
        }
        
        self.globalClient = globalClient;
    }
    
    override func tearDown() {
        
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        super.tearDown()
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            self.globalClient?.close(callback: { (success, error) in
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
                XCTAssertEqual(self.globalClient?.status, .closed)
                
                semaphore.breakWaiting = true;
            })
            
        }) {
            
            XCTFail("timeout")
        }
    }
    
    func testClientOpenClose() {
        
        let openCloseClient: AVIMClient = AVIMClient(clientId: "LCIMTestCaseClient.testClientOpenClose")
        
        for _ in 0..<100 {
            
            if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
                
                openCloseClient.open(callback: { (success, error) in
                    
                    XCTAssertTrue(success)
                    XCTAssertNil(error)
                    XCTAssertEqual(openCloseClient.status, .opened)
                    
                    semaphore.breakWaiting = true;
                })
                
            }) {
                
                XCTFail("timeout")
            }
            
            if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
                
                openCloseClient.close(callback: { (success, error) in
                    
                    XCTAssertTrue(success)
                    XCTAssertNil(error)
                    XCTAssertEqual(openCloseClient.status, .closed)
                    
                    semaphore.breakWaiting = true;
                })
                
            }) {
                
                XCTFail("timeout")
            }
        }
    }
    
}
