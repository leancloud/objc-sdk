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
    static let isUseCustomTestRTMServer: Bool = false;
    
    static var baseGlobalClient: AVIMClient?
    
    override class func setUp() {
        
        super.setUp()
        
        if self.isUseCustomTestRTMServer {
            
            AVOSCloudIM.defaultOptions().rtmServer = self.customTestRTMServer;
        }
        
        let client: AVIMClient = AVIMClient(clientId: "LCIMTestBase.baseGlobalClient")
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.open(callback: { (success, error) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
                XCTAssertEqual(client.status, .opened)
                
                self.baseGlobalClient = success ? client : nil;
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
}
