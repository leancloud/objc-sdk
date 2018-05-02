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
        
        guard AVOSCloud.getApplicationId() == TestRegion.WebEngine.appInfo.id else {
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
