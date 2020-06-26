//
//  RTMConnectionTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2020/06/26.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

class RTMConnectionTestCase: RTMBaseTestCase {
    
    func testDuplicatedRegisterAndDealloc() {
        weak var wConnection: LCRTMConnection?
        expecting { (exp) in
            let peerID = uuid
            let consumer = LCRTMServiceConsumer(
                application: .default(),
                service: .instantMessaging,
                protocol: .protocol3,
                peerID: peerID)
            DispatchQueue.global().async {
                var sConnection: LCRTMConnection?
                do {
                    sConnection = try LCRTMConnectionManager.shared().register(with: consumer)
                    wConnection = sConnection
                    XCTAssertNotNil(wConnection)
                    XCTAssertEqual(LCRTMConnectionManager.shared().imProtobuf3Registry.count, 1)
                    XCTAssertEqual(LCRTMConnectionManager.shared().imProtobuf1Registry.count, 0)
                    XCTAssertEqual(LCRTMConnectionManager.shared().liveQueryRegistry.count, 0)
                } catch {
                    XCTFail()
                }
                do {
                    try LCRTMConnectionManager.shared().register(with: consumer)
                    XCTFail()
                } catch {
                    XCTAssertEqual((error as NSError).domain, kLeanCloudErrorDomain)
                }
                LCRTMConnectionManager.shared().unregister(with: consumer)
                XCTAssertEqual(LCRTMConnectionManager.shared().imProtobuf3Registry.count, 0)
                XCTAssertEqual(LCRTMConnectionManager.shared().imProtobuf1Registry.count, 0)
                XCTAssertEqual(LCRTMConnectionManager.shared().liveQueryRegistry.count, 0)
                sConnection = nil
                exp.fulfill()
            }
        }
        delay()
        XCTAssertNil(wConnection)
    }
    
    func testConnectingDelayAndStop() {
        AVOSCloudIM.defaultOptions().rtmServer = RTMBaseTestCase.testableRTMServer + "n"
        defer {
            AVOSCloudIM.defaultOptions().rtmServer = nil
        }
        let peerID = uuid
        let consumer = LCRTMServiceConsumer(
            application: .default(),
            service: .instantMessaging,
            protocol: .protocol3,
            peerID: peerID)
        let connection = try! LCRTMConnectionManager.shared().register(with: consumer)
        let delegator = RTMConnectionDelegator()
        var connectingCount = 0
        let maxCount = 10
        var timeout: TimeInterval = 0.0
        for i in 0..<maxCount {
            if i > 1 {
                if i > 6 {
                    timeout += 30
                } else {
                    timeout += pow(Double(2), Double(i - 2))
                }
            }
        }
        let start = Date()
        expecting(
            description: "Connecting Delay",
            count: maxCount * 2,
            timeout: timeout + 5)
        { (exp) in
            let rtmDelegator = LCRTMConnectionDelegator(
                peerID: peerID,
                delegate: delegator,
                queue: .main)
            delegator.inConnecting = { connection in
                connectingCount += 1
                exp.fulfill()
            }
            delegator.didDisconnect = { connection, error in
                if let error = error as NSError? {
                    XCTAssertEqual(error.domain, kLeanCloudErrorDomain)
                    XCTAssertEqual(error.code, AVErrorInternalErrorCode.underlyingError.rawValue)
                } else {
                    XCTFail()
                }
                if connectingCount == maxCount {
                    delegator.reset()
                }
                exp.fulfill()
            }
            connection.connect(
                with: consumer,
                delegator: rtmDelegator)
        }
        let duration = Date().timeIntervalSince1970 - start.timeIntervalSince1970
        XCTAssertTrue(duration > timeout)
        XCTAssertTrue(duration < timeout + 10)
        connection.removeDelegator(with: consumer)
        delay()
        expecting(
            timeout: 30)
        { () -> XCTestExpectation in
            let exp = self.expectation(description: "NOT Connecting")
            exp.isInverted = true
            return exp
        } testcase: { (exp) in
            delegator.inConnecting = { connection in
                exp.fulfill()
            }
            delegator.didConnect = { connection in
                exp.fulfill()
            }
        }
        XCTAssertNil(connection.socket)
        XCTAssertNil(connection.timer)
        LCRTMConnectionManager.shared().unregister(with: consumer)
    }
    
    func testLoginTimeout() {
        let peerID = uuid
        let consumer = LCRTMServiceConsumer(
            application: .default(),
            service: .instantMessaging,
            protocol: .protocol3,
            peerID: peerID)
        let connection = try! LCRTMConnectionManager.shared().register(with: consumer)
        let delegator = RTMConnectionDelegator()
        
        expecting(
            description: "Login Timeout",
            count: 3,
            timeout: 90)
        { (exp) in
            delegator.inConnecting = { connection in
                XCTAssertTrue(Thread.isMainThread)
                exp.fulfill()
            }
            delegator.didConnect = { connection in
                XCTAssertTrue(Thread.isMainThread)
                exp.fulfill()
            }
            delegator.didDisconnect = { connection, error in
                XCTAssertTrue(Thread.isMainThread)
                if let error = error as NSError? {
                    XCTAssertEqual(error.domain, kLeanCloudErrorDomain)
                    XCTAssertEqual(error.code, 4108)
                } else {
                    XCTFail()
                }
                delegator.reset()
                exp.fulfill()
            }
            connection.connect(
                with: consumer,
                delegator: .init(
                    peerID: peerID,
                    delegate: delegator,
                    queue: .main))
        }
        
        connection.removeDelegator(with: consumer)
        LCRTMConnectionManager.shared().unregister(with: consumer)
    }
}

class RTMConnectionDelegator: NSObject, LCRTMConnectionDelegate {
    
    func reset() {
        inConnecting = nil
        didConnect = nil
        didDisconnect = nil
        didReceive = nil
    }
    
    var inConnecting: ((LCRTMConnection) -> Void)?
    func lcrtmConnection(inConnecting connection: LCRTMConnection) {
        inConnecting?(connection)
    }
    
    var didConnect: ((LCRTMConnection) -> Void)?
    func lcrtmConnectionDidConnect(_ connection: LCRTMConnection) {
        didConnect?(connection)
    }
    
    var didDisconnect: ((LCRTMConnection, Error?) -> Void)?
    func lcrtmConnection(_ connection: LCRTMConnection, didDisconnectWithError error: Error?) {
        didDisconnect?(connection, error)
    }
    
    var didReceive: ((LCRTMConnection, AVIMGenericCommand) -> Void)?
    func lcrtmConnection(_ connection: LCRTMConnection, didReceive inCommand: AVIMGenericCommand) {
        didReceive?(connection, inCommand)
    }
}
