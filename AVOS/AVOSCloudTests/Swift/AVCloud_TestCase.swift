//
//  AVCloud_TestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 2018/4/4.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVCloud_TestCase: LCTestBase {
    
    func test_callFunction() {
        
        /*
         Test App for WebEngine, North China
         */
        
        let appId: String = "tiy1PsmEtJJ1QtHvHzVQLVod-gzGzoHsz"
        let _: String = "m6HkmlWP3tclhnbbeWurifNl" // appKey
        
        guard AVOSCloud.getApplicationId() == appId else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            AVCloud.callFunction(inBackground: "hello", withParameters: nil) { (object: Any?, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(object)
                XCTAssertNil(error)
            }
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
}
