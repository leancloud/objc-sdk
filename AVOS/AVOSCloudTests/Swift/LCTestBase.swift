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
    
    override class func setUp() {
        
        super.setUp()
        
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
    
    override class func tearDown() {
        
        super.tearDown()
    }
    
    // MARK: - async testing utilities
    
    func runloopTestAsync(
        timeout: TimeInterval = 30,
        closure: (RunLoopSemaphore) -> (Void)
        ) -> Bool
    {
        XCTAssertTrue(timeout > 0)
        
        let currentTimestamp: TimeInterval = Date().timeIntervalSince1970
        
        let semaphore: RunLoopSemaphore = RunLoopSemaphore()
        
        closure(semaphore)
        
        while semaphore.breakWaiting == false {
            
            let date: Date = Date.init(timeIntervalSinceNow: 1.0)
            
            XCTAssertTrue(RunLoop.current.run(mode: .defaultRunLoopMode, before: date))
            
            if date.timeIntervalSince1970 - currentTimestamp > timeout {
                
                let isTimeout: Bool = true
                
                return isTimeout
            }
        }
        
        let isTimeout: Bool = false
        
        return isTimeout
    }
    
    static func runloopTestAsync(
        timeout: TimeInterval = 30,
        closure: (RunLoopSemaphore) -> (Void)
        ) -> Bool
    {
        XCTAssertTrue(timeout > 0)
        
        let currentTimestamp: TimeInterval = Date().timeIntervalSince1970
        
        let semaphore: RunLoopSemaphore = RunLoopSemaphore()
        
        closure(semaphore)
        
        while semaphore.breakWaiting == false {
            
            let date: Date = Date.init(timeIntervalSinceNow: 1.0)
            
            XCTAssertTrue(RunLoop.current.run(mode: .defaultRunLoopMode, before: date))
            
            if date.timeIntervalSince1970 - currentTimestamp > timeout {
                
                let isTimeout: Bool = true
                
                return isTimeout
            }
        }
        
        let isTimeout: Bool = false
        
        return isTimeout
    }
    
}

class RunLoopSemaphore {
    
    var breakWaiting: Bool = false
    
}
