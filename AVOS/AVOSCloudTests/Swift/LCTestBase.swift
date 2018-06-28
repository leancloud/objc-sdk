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
            return (id: "S5vDI3IeCk1NLLiM1aFg3262-gzGzoHsz",
                    key: "7g5pPsI55piz2PRLPWK5MPz0")
        case .CN_East:
            return (id: "uwWkfssEBRtrxVpQWEnFtqfr-9Nh9j0Va",
                    key: "9OaLpoW21lIQtRYzJya4WHUR")
        case .US:
            return (id: "kknqydxqd9wdq4cboy1dvvug5ha0ce3i2mrerrdrmr6pla1p",
                    key: "fate582pwsfh97s9o99nw91a152i7ndm9tsy866e6wpezth4")
        }
    }
}

class LCTestBase: XCTestCase {
    
    override class func setUp() {
        
        super.setUp()
        
        let region: TestRegion = .CN_North
        
        let appInfo: (id: String, key: String) = region.appInfo
        
        if region == .US {
            
            AVOSCloud.setServiceRegion(.US)
            
        } else {
            
            AVOSCloud.setServiceRegion(.CN)
        }
        
        LCRouter.sharedInstance().cleanCache(forKey: "LCAppRouterCacheKey")
        LCRouter.sharedInstance().cleanCache(forKey: "LCRTMRouterCacheKey")
        
        AVOSCloud.setApplicationId(appInfo.id, clientKey: appInfo.key)
        
        AVOSCloud.setAllLogsEnabled(true)
    }
    
    override class func tearDown() {
        
        super.tearDown()
    }
    
    // MARK: - async testing utilities
    
    func runloopTestingAsync(
        timeout: TimeInterval = 30,
        async: (RunLoopSemaphore) -> Void,
        failure: (() -> Void)? = nil)
    {
        XCTAssertTrue(timeout > 0)
        
        let semaphore: RunLoopSemaphore = RunLoopSemaphore()
        async(semaphore)
        
        let startTimestamp: TimeInterval = Date().timeIntervalSince1970
        while semaphore.waiting() {
            let date: Date = Date(timeIntervalSinceNow: 1.0)
            XCTAssertTrue(RunLoop.current.run(mode: .defaultRunLoopMode, before: date))
            if date.timeIntervalSince1970 - startTimestamp > timeout {
                failure?()
                return
            }
        }
        
        XCTAssertTrue(RunLoop.current.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow: 1.0)))
    }
    
    static func runloopTestingAsync(
        timeout: TimeInterval = 30,
        async: (RunLoopSemaphore) -> Void,
        failure: (() -> Void)? = nil)
    {
        XCTAssertTrue(timeout > 0)
        
        let semaphore: RunLoopSemaphore = RunLoopSemaphore()
        async(semaphore)
        
        let startTimestamp: TimeInterval = Date().timeIntervalSince1970
        while semaphore.waiting() {
            let date: Date = Date(timeIntervalSinceNow: 1.0)
            XCTAssertTrue(RunLoop.current.run(mode: .defaultRunLoopMode, before: date))
            if date.timeIntervalSince1970 - startTimestamp > timeout {
                failure?()
                return
            }
        }
        
        XCTAssertTrue(RunLoop.current.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow: 1.0)))
    }
    
}

class RunLoopSemaphore {
    
    private var lock: NSLock = NSLock()
    var semaphoreValue: Int = 0
    
    func increment(_ number: Int = 1) {
        assert(number > 0)
        self.lock.lock()
        self.semaphoreValue += number
        self.lock.unlock()
    }
    
    func decrement(_ number: Int = 1) {
        assert(number > 0)
        self.lock.lock()
        self.semaphoreValue -= number
        self.lock.unlock()
    }
    
    fileprivate func waiting() -> Bool {
        return (self.semaphoreValue > 0) ? true : false
    }
    
}
