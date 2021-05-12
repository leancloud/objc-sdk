//
//  IMClientTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2020/06/28.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

class IMClientTestCase: RTMBaseTestCase {
    
    func testInitAndDealloc() {
        let peerID = uuid
        var client: LCIMClient? = try! LCIMClient(clientId: peerID)
        do {
            _ = try LCIMClient(clientId: peerID)
            XCTFail()
        } catch {
            XCTAssertEqual((error as NSError).domain, kLeanCloudErrorDomain)
        }
        client = nil
        client = try! LCIMClient(clientId: peerID)
        XCTAssertNotNil(client)
    }
    
    func testSessionConflict() {
        let peerID = uuid
        let tag = "SessionConflict"
        let client1 = try! LCIMClient(clientId: peerID, tag: tag)
        let delegator1 = LCIMClientDelegator()
        client1.delegate = delegator1
        client1.currentDeviceToken = uuid
        expecting { (exp) in
            client1.open { (success, error) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(success)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        purgeConnectionRegistry()
        let client2 = try! LCIMClient(clientId: peerID, tag: tag)
        let delegator2 = LCIMClientDelegator()
        client2.delegate = delegator2
        client2.currentDeviceToken = uuid
        expecting(
            description: "Session Conflict",
            count: 3)
        { (exp) in
            delegator1.closed = { client, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(error)
                XCTAssertEqual((error as NSError?)?.code, LCIMErrorCode.sessionConflict.rawValue)
                exp.fulfill()
            }
            delegator1.offline = { client, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(error)
                XCTAssertEqual((error as NSError?)?.code, LCIMErrorCode.sessionConflict.rawValue)
                exp.fulfill()
            }
            client2.open { (success, error) in
                XCTAssertTrue(success)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        delegator1.reset()
        expecting(
            description: "Reopen",
            count: 2)
        { (exp) in
            delegator1.offline = { client, error in
                XCTAssertNotNil(error)
                XCTAssertEqual((error as NSError?)?.code, LCIMErrorCode.sessionConflict.rawValue)
                exp.fulfill()
            }
            client1.open(with: .reopen) { (success, error) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertFalse(success)
                XCTAssertNotNil(error)
                XCTAssertEqual((error as NSError?)?.code, LCIMErrorCode.sessionConflict.rawValue)
                exp.fulfill()
            }
        }
        expecting(
            description: "Force Open",
            count: 3)
        { (exp) in
            delegator2.closed = { client, error in
                XCTAssertNotNil(error)
                XCTAssertEqual((error as NSError?)?.code, LCIMErrorCode.sessionConflict.rawValue)
                exp.fulfill()
            }
            delegator2.offline = { client, error in
                XCTAssertNotNil(error)
                XCTAssertEqual((error as NSError?)?.code, LCIMErrorCode.sessionConflict.rawValue)
                exp.fulfill()
            }
            client1.open(with: .forceOpen) { (success, error) in
                XCTAssertTrue(success)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testSessionTokenExpired() {
        let client = try! LCIMClient(clientId: uuid)
        let delegator = LCIMClientDelegator()
        client.delegate = delegator
        expecting { (exp) in
            client.open { (success, error) in
                XCTAssertTrue(success)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        XCTAssertNotNil(client.sessionToken)
        client.sessionToken = uuid
        expecting { (exp) in
            delegator.resumed = { client in
                XCTAssertTrue(Thread.isMainThread)
                exp.fulfill()
            }
            client.connection.serialQueue.async {
                let inCommand = AVIMGenericCommand()
                inCommand.cmd = .goaway
                let message = LCRTMWebSocketMessage(
                    data: inCommand.data()!)
                client.connection.socket.delegate?.lcrtmWebSocket(
                    client.connection.socket,
                    didReceive: message)
            }
        }
    }
    
    func testReportDeviceToken() {
        let installation = LCInstallation.default()
        let client = try! LCIMClient(clientId: uuid)
        XCTAssertTrue(installation === client.installation)
        expecting { (exp) in
            client.open { (success, error) in
                XCTAssertTrue(success)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        let deviceToken = uuid
        var observer: NSObjectProtocol?
        expecting { (exp) in
            observer = NotificationCenter.default.addObserver(
                forName: NSNotification.Name(rawValue: "Test.LCIMClient.reportDeviceToken"),
                object: nil,
                queue: .main)
            { (notification) in
                XCTAssertNil(notification.userInfo?["error"])
                exp.fulfill()
            }
            installation.setDeviceTokenHexString(deviceToken, teamId: "LeanCloud")
        }
        XCTAssertEqual(client.currentDeviceToken, deviceToken)
        XCTAssertNotNil(observer)
    }
}

class LCIMClientDelegator: NSObject, LCIMClientDelegate {
    
    func reset() {
        resuming = nil
        resumed = nil
        paused = nil
        closed = nil
        offline = nil
        didReceiveTypedMessage = nil
    }
    
    var resuming: ((LCIMClient) -> Void)?
    func imClientResuming(_ imClient: LCIMClient) {
        resuming?(imClient)
    }
    
    var resumed: ((LCIMClient) -> Void)?
    func imClientResumed(_ imClient: LCIMClient) {
        resumed?(imClient)
    }
    
    var paused: ((LCIMClient, Error?) -> Void)?
    func imClientPaused(_ imClient: LCIMClient, error: Error?) {
        paused?(imClient, error)
    }
    
    var closed: ((LCIMClient, Error?) -> Void)?
    func imClientClosed(_ imClient: LCIMClient, error: Error?) {
        closed?(imClient, error)
    }
    
    var offline: ((LCIMClient, Error?) -> Void)?
    func client(_ client: LCIMClient, didOfflineWithError error: Error?) {
        offline?(client, error)
    }
    
    var didReceiveTypedMessage: ((LCIMConversation, LCIMTypedMessage) -> Void)?
    func conversation(_ conversation: LCIMConversation, didReceive message: LCIMTypedMessage) {
        didReceiveTypedMessage?(conversation, message)
    }
}
