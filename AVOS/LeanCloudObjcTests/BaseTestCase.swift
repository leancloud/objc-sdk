//
//  BaseTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2020/06/22.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

class BaseTestCase: XCTestCase {
    
    static let timeout: TimeInterval = 60.0
    let timeout: TimeInterval = 60.0
    
    static var uuid: String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    var uuid: String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    struct AppInfo {
        let id: String
        let key: String
        let serverURL: String
        let masterKey: String
    }
    
    static let cnApp = AppInfo(
        id: "S5vDI3IeCk1NLLiM1aFg3262-gzGzoHsz",
        key: "7g5pPsI55piz2PRLPWK5MPz0",
        serverURL: "https://s5vdi3ie.lc-cn-n1-shared.com",
//        serverURL: "https://beta.leancloud.cn",
        masterKey: "Q26gTodbyi1Ki7lM9vtncF6U,master")
    
    static let ceApp = AppInfo(
        id: "skhiVsqIk7NLVdtHaUiWn0No-9Nh9j0Va",
        key: "T3TEAIcL8Ls5XGPsGz41B1bz",
        serverURL: "https://skhivsqi.lc-cn-e1-shared.com",
        masterKey: "FTPdEcG7vLKxNqKxYhTFdK4g,master")
    
    static let usApp = AppInfo(
        id: "jenSt9nvWtuJtmurdE28eg5M-MdYXbMMI",
        key: "8VLPsDlskJi8KsKppED4xKS0",
        serverURL: "",
        masterKey: "fasiJXz8jvSwn3G2B2QeraRe,master")
    
    static let appInfoTable = [
        cnApp.id : cnApp,
        ceApp.id : ceApp,
        usApp.id : usApp,
    ]
    
    override class func setUp() {
        super.setUp()
        let app = BaseTestCase.cnApp
        LCApplication.setAllLogsEnabled(true)
        if app.serverURL.isEmpty {
            LCApplication.setApplicationId(app.id, clientKey: app.key)
        } else {
            LCApplication.setApplicationId(app.id, clientKey: app.key, serverURLString: app.serverURL)
        }
    }
    
    override class func tearDown() {
        LCFile.clearAllPersistentCache()
        super.tearDown()
    }
    
    override func tearDown() {
        LCUser.logOut()
        super.tearDown()
    }
}

extension BaseTestCase {
    
    func expecting(
        description: String? = nil,
        count expectedFulfillmentCount: Int = 1,
        timeout: TimeInterval = BaseTestCase.timeout,
        testcase: (XCTestExpectation) -> Void)
    {
        let exp = self.expectation(description: description ?? "default expectation")
        exp.expectedFulfillmentCount = expectedFulfillmentCount
        self.expecting(
            timeout: timeout,
            expectation: { exp },
            testcase: testcase)
    }
    
    func expecting(
        timeout: TimeInterval = BaseTestCase.timeout,
        expectation: () -> XCTestExpectation,
        testcase: (XCTestExpectation) -> Void)
    {
        self.multiExpecting(
            timeout: timeout,
            expectations: { [expectation()] },
            testcase: { testcase($0[0]) })
    }
    
    func multiExpecting(
        timeout: TimeInterval = BaseTestCase.timeout,
        expectations: (() -> [XCTestExpectation]),
        testcase: ([XCTestExpectation]) -> Void)
    {
        let exps = expectations()
        testcase(exps)
        wait(for: exps, timeout: timeout)
    }
    
    func delay(seconds: TimeInterval = 3.0) {
        print("\n------\nwait \(seconds) seconds.\n------\n")
        let exp = expectation(description: "delay \(seconds) seconds.")
        exp.isInverted = true
        wait(for: [exp], timeout: seconds)
    }
}

extension BaseTestCase {
    
    func useMasterKey(_ application: LCApplication = .default()) {
        guard let appInfo = BaseTestCase.appInfoTable[application.identifier],
              !appInfo.masterKey.isEmpty else {
            return
        }
        application.setWithIdentifier(appInfo.id, key: appInfo.masterKey)
    }
    
    func useCommonKey(_ application: LCApplication = .default()) {
        guard let appInfo = BaseTestCase.appInfoTable[application.identifier],
              !appInfo.masterKey.isEmpty else {
            return
        }
        application.setWithIdentifier(appInfo.id, key: appInfo.key)
    }
}
