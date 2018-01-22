//
//  LCTestBase.swift
//  AVOS
//
//  Created by ZapCannon87 on 11/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

enum TestRegion {
    
    case CN_North
    case CN_East
    case US
    
    var appInfo: (id: String, key: String) {
        
        switch self {
            
        case .CN_North:
            
            return (
                id: "nq0awk3lh1dpmbkziz54377mryii8ny4xvp6njoygle5nlyg",
                key: "6vdnmdkdi4fva9i06lt50s4mcsfhppjpzm3zf5zjc9ty4pdz"
            )
            
        case .CN_East:
            
            return (
                id: "uwWkfssEBRtrxVpQWEnFtqfr-9Nh9j0Va",
                key: "9OaLpoW21lIQtRYzJya4WHUR"
            )
            
        case .US:
            
            return (
                id: "kknqydxqd9wdq4cboy1dvvug5ha0ce3i2mrerrdrmr6pla1p",
                key: "fate582pwsfh97s9o99nw91a152i7ndm9tsy866e6wpezth4"
            )
        }
        
    }
}

class LCTestBase: XCTestCase {
    
    override class func setUp() {
        
        super.setUp()
        
        let region: TestRegion = .CN_East
        
        let appInfo: (id: String, key: String) = region.appInfo
        
        AVOSCloud.setApplicationId(appInfo.id, clientKey: appInfo.key)
        
        AVOSCloud.setAllLogsEnabled(true)
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
        
        while semaphore.waiting() {
            
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
        
        while semaphore.waiting() {
            
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
    
    var semaphoreValue = 0
    
    func increment() {
        
        self.semaphoreValue += 1
    }
    
    func decrement() {
        
        self.semaphoreValue -= 1
    }
    
    func waiting() -> Bool {
        
        return (self.semaphoreValue > 0)
    }
    
}
