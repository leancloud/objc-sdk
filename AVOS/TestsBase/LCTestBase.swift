//
//  LCTestBase.swift
//  AVOS
//
//  Created by ZapCannon87 on 11/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

class LCTestBase: XCTestCase {
    
    override class func setUp() {
        super.setUp()
        
        let env: LCTestEnvironment = LCTestEnvironment.sharedInstance()
        
        /// custom url for API
        if let APIURL: String = env.url_API {
            AVOSCloud.setServerURLString(APIURL, for: .API)
            AVOSCloud.setServerURLString(APIURL, for: .push)
            AVOSCloud.setServerURLString(APIURL, for: .statistics)
            AVOSCloud.setServerURLString(APIURL, for: .engine)
        }
        
        /// custom url for RTM router
        if let RTMRouterURL: String = env.url_RTMRouter {
            AVOSCloud.setServerURLString(RTMRouterURL, for: .RTM)
        }
        
        /// custom app id & key
        if let appId: String = env.app_ID, let appKey: String = env.app_KEY {
            AVOSCloud.setApplicationId(appId, clientKey: appKey)
        } else {
            let testApp: TestApp = .ChinaNorth
            AVOSCloud.setApplicationId(testApp.appInfo.id, clientKey: testApp.appInfo.key)
        }
        
        AVOSCloud.setAllLogsEnabled(true)
    }
    
    override class func tearDown() {
        super.tearDown()
    }
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
}

extension LCTestBase {
    
    var isServerTesting: Bool {
        return LCTestEnvironment.sharedInstance().isServerTesting
    }
    
    enum TestApp {
        case ChinaNorth
        case ChinaEast
        case US
        var appInfo: (id: String, key: String) {
            switch self {
            case .ChinaNorth: return (id: "S5vDI3IeCk1NLLiM1aFg3262-gzGzoHsz", key: "7g5pPsI55piz2PRLPWK5MPz0")
            case .ChinaEast: return (id: "uwWkfssEBRtrxVpQWEnFtqfr-9Nh9j0Va", key: "9OaLpoW21lIQtRYzJya4WHUR")
            case .US: return (id: "eX7urCufwLd6X5mHxt7V12nL-MdYXbMMI", key: "PrmzHPnRXjXezS54KryuHMG6")
            }
        }
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
    
    private func running() -> Bool {
        return (self.semaphoreValue > 0) ? true : false
    }
    
    static func wait(timeout: TimeInterval = 30, async: (RunLoopSemaphore) -> Void, failure: (() -> Void)? = nil) {
        XCTAssertTrue(timeout >= 0)
        defer {
            XCTAssertTrue(RunLoop.current.run(mode: RunLoop.Mode.default, before: Date(timeIntervalSinceNow: 1.0)))
        }
        let semaphore: RunLoopSemaphore = RunLoopSemaphore()
        async(semaphore)
        let startTimestamp: TimeInterval = Date().timeIntervalSince1970
        while semaphore.running() {
            let date: Date = Date(timeIntervalSinceNow: 1.0)
            XCTAssertTrue(RunLoop.current.run(mode: RunLoop.Mode.default, before: date))
            if date.timeIntervalSince1970 - startTimestamp > timeout {
                failure?()
                return
            }
        }
    }
    
}
