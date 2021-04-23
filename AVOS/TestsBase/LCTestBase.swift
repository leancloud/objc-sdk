//
//  LCTestBase.swift
//  AVOS
//
//  Created by ZapCannon87 on 11/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

class LCTestBase: XCTestCase {
    
    static let timeout: TimeInterval = 60
    
    var uuid: String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    static var uuid: String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    override class func setUp() {
        super.setUp()
        
        AVOSCloud.setAllLogsEnabled(true)
        
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
            switch testApp {
            case .ChinaNorth, .ChinaEast, .USOld:
                AVOSCloud.setApplicationId(
                    testApp.appInfo.id,
                    clientKey: testApp.appInfo.key,
                    serverURLString: testApp.appInfo.serverURL)
            case .US:
                AVOSCloud.setApplicationId(
                    testApp.appInfo.id,
                    clientKey: testApp.appInfo.key)
            }
        }
    }
    
    override class func tearDown() {
        LCFile.clearAllPersistentCache()
        super.tearDown()
    }
}

extension LCTestBase {
    
    func expecting(
        description: String? = nil,
        count expectedFulfillmentCount: Int = 1,
        testcase: (XCTestExpectation) -> Void)
    {
        let exp = self.expectation(description: description ?? "default expectation")
        exp.expectedFulfillmentCount = expectedFulfillmentCount
        self.expecting(
            timeout: LCTestBase.timeout,
            expectation: { exp },
            testcase: testcase)
    }
    
    func expecting(
        expectation: @escaping () -> XCTestExpectation,
        testcase: (XCTestExpectation) -> Void)
    {
        self.expecting(
            timeout: LCTestBase.timeout,
            expectation: expectation,
            testcase: testcase)
    }
    
    func expecting(
        timeout: TimeInterval,
        expectation: () -> XCTestExpectation,
        testcase: (XCTestExpectation) -> Void)
    {
        self.multiExpecting(
            timeout: timeout,
            expectations: { [expectation()] },
            testcase: { testcase($0[0]) })
    }
    
    func multiExpecting(
        timeout: TimeInterval = LCTestBase.timeout,
        expectations: (() -> [XCTestExpectation]),
        testcase: ([XCTestExpectation]) -> Void)
    {
        let exps = expectations()
        testcase(exps)
        wait(for: exps, timeout: timeout)
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
        case USOld
        var appInfo: (id: String, key: String, serverURL: String) {
            switch self {
            case .ChinaNorth:
                return (id: "S5vDI3IeCk1NLLiM1aFg3262-gzGzoHsz",
                        key: "7g5pPsI55piz2PRLPWK5MPz0",
                        serverURL: "https://s5vdi3ie.lc-cn-n1-shared.com")
            case .ChinaEast:
                return (id: "skhiVsqIk7NLVdtHaUiWn0No-9Nh9j0Va",
                        key: "T3TEAIcL8Ls5XGPsGz41B1bz",
                        serverURL: "https://skhivsqi.lc-cn-e1-shared.com")
            case .US:
                return (id: "jenSt9nvWtuJtmurdE28eg5M-MdYXbMMI",
                        key: "8VLPsDlskJi8KsKppED4xKS0",
                        serverURL: "")
            case .USOld:
                return (id: "kknqydxqd9wdq4cboy1dvvug5ha0ce3i2mrerrdrmr6pla1p",
                        key: "fate582pwsfh97s9o99nw91a152i7ndm9tsy866e6wpezth4",
                        serverURL: "https://beta-us.leancloud.cn")
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
