//
//  LCTestBase.swift
//  AVOS
//
//  Created by ZapCannon87 on 11/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

let kLCTestBase_IsSelectRegion_US: Bool = false

// US
let kLCTestBase_AppId_US: String = "kknqydxqd9wdq4cboy1dvvug5ha0ce3i2mrerrdrmr6pla1p"
let kLCTestBase_AppKey_US: String = "fate582pwsfh97s9o99nw91a152i7ndm9tsy866e6wpezth4"
// CN
let kLCTestBase_AppId_CN: String = "nq0awk3lh1dpmbkziz54377mryii8ny4xvp6njoygle5nlyg"
let kLCTestBase_AppKey_CN: String = "6vdnmdkdi4fva9i06lt50s4mcsfhppjpzm3zf5zjc9ty4pdz"

class LCTestBase: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        let appId: String
        let appKey: String
        
        if kLCTestBase_IsSelectRegion_US {
            
            appId = kLCTestBase_AppId_US
            appKey = kLCTestBase_AppKey_US
            
        } else {
            
            appId = kLCTestBase_AppId_CN
            appKey = kLCTestBase_AppKey_CN
        }
        
        AVOSCloud.setApplicationId(appId, clientKey: appKey)
        AVOSCloud.setAllLogsEnabled(false)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: - async testing utilities
    
    func runloopTestAsync(
        timeout: TimeInterval = 30,
        closure: (RunLoopSemaphore) -> (Void)
        ) -> Bool
    {
        XCTAssertTrue(timeout > 0)
        
        var timer: TimeInterval = 0
        let frequency: TimeInterval = 1.0
        
        var isTimeout: Bool
        
        let semaphore: RunLoopSemaphore = RunLoopSemaphore()
        
        closure(semaphore)
        
        while semaphore.breakWaiting == false {
            
            let date: Date = Date.init(timeIntervalSinceNow: frequency)
            
            XCTAssertTrue(RunLoop.current.run(mode: .defaultRunLoopMode, before: date))
            
            timer += frequency
            
            if timer > timeout {
                
                isTimeout = true
                
                return isTimeout
            }
        }
        
        isTimeout = false
        
        return isTimeout
    }
    
}

class RunLoopSemaphore {
    
    var breakWaiting: Bool = false
    
}
