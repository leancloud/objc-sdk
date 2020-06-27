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
    
    func testLoginAndCommandTimeout() {
        let peerID = uuid
        let consumer = LCRTMServiceConsumer(
            application: .default(),
            service: .instantMessaging,
            protocol: .protocol3,
            peerID: peerID)
        let connection = try! LCRTMConnectionManager.shared().register(with: consumer)
        let delegator = RTMConnectionDelegator()
        expecting(
            description: "Login and Command Timeout",
            count: 4,
            timeout: 90)
        { (exp) in
            delegator.inConnecting = { connection in
                XCTAssertTrue(Thread.isMainThread)
                exp.fulfill()
            }
            delegator.didConnect = { connection in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(connection.timer)
                connection.serialQueue.async {
                    connection.timer.append(
                        .init(
                            peerID: self.uuid,
                            command: AVIMGenericCommand(),
                            calling: .main,
                            callback: { (_, error) in
                                XCTAssertTrue(Thread.isMainThread)
                                XCTAssertEqual((error as NSError?)?.code, AVIMErrorCode.commandTimeout.rawValue)
                                exp.fulfill()
                            }),
                        index: NSNumber(1))
                }
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
    
    func testThrottlingOutCommand() {
        let peerID = uuid
        let consumer = LCRTMServiceConsumer(
            application: .default(),
            service: .instantMessaging,
            protocol: .protocol3,
            peerID: peerID)
        let connection = try! LCRTMConnectionManager.shared().register(with: consumer)
        let delegator = RTMConnectionDelegator()
        expecting { (exp) in
            delegator.didConnect = { connection in
                exp.fulfill()
            }
            connection.connect(
                with: consumer,
                delegator: .init(
                    peerID: peerID,
                    delegate: delegator,
                    queue: .main))
        }
        expecting(
            description: "Throttling Out Command",
            count: 3)
        { (exp) in
            var uniqueCommand: AVIMGenericCommand!
            for _ in 0...2 {
                let outCommand = AVIMGenericCommand()
                outCommand.cmd = .session
                outCommand.op = .open
                outCommand.appId = AVApplication.default().identifier
                outCommand.peerId = peerID
                let sessionCommand = AVIMSessionCommand()
                sessionCommand.ua = USER_AGENT
                outCommand.sessionMessage = sessionCommand
                connection.send(
                    outCommand,
                    service: .instantMessaging,
                    peerID: peerID,
                    on: .main)
                { (inCommand, error) in
                    XCTAssertTrue(Thread.isMainThread)
                    if uniqueCommand == nil {
                        uniqueCommand = inCommand
                    }
                    XCTAssertNotNil(inCommand)
                    XCTAssertNil(error)
                    XCTAssertTrue(uniqueCommand === inCommand)
                    exp.fulfill()
                }
            }
        }
        var conversationID: String!
        expecting { (exp) in
            let outCommand = AVIMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .start
            let convCommand = AVIMConvCommand()
            convCommand.mArray = [peerID]
            outCommand.convMessage = convCommand
            connection.send(
                outCommand,
                service: .instantMessaging,
                peerID: peerID,
                on: .main)
            { (inCommand, error) in
                XCTAssertNotNil(inCommand)
                XCTAssertNil(error)
                conversationID = inCommand?.convMessage.cid
                exp.fulfill()
            }
        }
        if let conversationID = conversationID,
           !conversationID.isEmpty {
            var inCommandIndexSet = Set<Int32>()
            let count = 3
            expecting(
                description: "NOT Throttling Direct Command",
                count: count)
            { (exp) in
                for _ in 0..<count {
                    let outCommand = AVIMGenericCommand()
                    outCommand.cmd = .direct
                    let directCommand = AVIMDirectCommand()
                    directCommand.cid = conversationID
                    directCommand.msg = peerID
                    outCommand.directMessage = directCommand
                    connection.send(
                        outCommand,
                        service: .instantMessaging,
                        peerID: peerID,
                        on: .main)
                    { (inCommand, error) in
                        if let inCommand = inCommand {
                            inCommandIndexSet.insert(inCommand.i)
                        }
                        XCTAssertNotNil(inCommand)
                        XCTAssertNil(error)
                        exp.fulfill()
                    }
                }
            }
            XCTAssertEqual(inCommandIndexSet.count, count)
        } else {
            XCTFail()
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
