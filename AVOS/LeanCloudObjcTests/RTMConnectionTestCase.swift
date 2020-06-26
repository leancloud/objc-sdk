//
//  RTMConnectionTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2020/06/26.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

class RTMConnectionTestCase: BaseTestCase {
    
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
                    exp.fulfill()
                    delegator.reset()
                }
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
