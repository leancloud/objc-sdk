//
//  LCIMTestBase.swift
//  AVOS
//
//  Created by zapcannon87 on 19/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import Foundation
import XCTest

class LCIMTestBase: LCTestBase {

    /* For Internal Test */
    static let customTestRTMServer: String = "wss://rtm51.leancloud.cn";
    static let isUseCustomTestRTMServer: Bool = true;
    
    static var baseGlobalClient: AVIMClient?
    
    override class func setUp() {
        
        super.setUp()
        
        if self.isUseCustomTestRTMServer {
            
            AVOSCloudIM.defaultOptions().rtmServer = self.customTestRTMServer;
        }
        
        let client: AVIMClient = AVIMClient(clientId: "LCIMTestBase.baseGlobalClient")
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            semaphore.increment()
            
            client.open(callback: { (success, error) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
                XCTAssertEqual(client.status, .opened)
                
                self.baseGlobalClient = success ? client : nil;
            })
            
        }) {
            
            XCTFail("timeout")
        }
    }
    
    override class func tearDown() {
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            semaphore.increment()
            
            self.baseGlobalClient?.close(callback: { (success, error) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
                XCTAssertEqual(self.baseGlobalClient?.status, .closed)
            })
            
        }) {
            
            XCTFail("timeout")
        }
        
        self.baseGlobalClient = nil;
        
        super.tearDown()
    }
    
}
