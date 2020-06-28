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
    
    func testSessionConflict() {
        let peerID = uuid
        let tag = "SessionConflict"
        let client1 = try! AVIMClient(clientId: peerID, tag: tag, error: ())
        let delegator1 = AVIMClientDelegator()
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
        let client2 = try! AVIMClient(clientId: peerID, tag: tag, error: ())
        let delegator2 = AVIMClientDelegator()
        client2.delegate = delegator2
        client2.currentDeviceToken = uuid
        expecting(
            description: "Session Conflict",
            count: 3)
        { (exp) in
            delegator1.closed = { client, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(error)
                XCTAssertEqual((error as NSError?)?.code, AVIMErrorCode.sessionConflict.rawValue)
                exp.fulfill()
            }
            delegator1.offline = { client, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(error)
                XCTAssertEqual((error as NSError?)?.code, AVIMErrorCode.sessionConflict.rawValue)
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
                XCTAssertEqual((error as NSError?)?.code, AVIMErrorCode.sessionConflict.rawValue)
                exp.fulfill()
            }
            client1.open(with: .reopen) { (success, error) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertFalse(success)
                XCTAssertNotNil(error)
                XCTAssertEqual((error as NSError?)?.code, AVIMErrorCode.sessionConflict.rawValue)
                exp.fulfill()
            }
        }
        expecting(
            description: "Force Open",
            count: 3)
        { (exp) in
            delegator2.closed = { client, error in
                XCTAssertNotNil(error)
                XCTAssertEqual((error as NSError?)?.code, AVIMErrorCode.sessionConflict.rawValue)
                exp.fulfill()
            }
            delegator2.offline = { client, error in
                XCTAssertNotNil(error)
                XCTAssertEqual((error as NSError?)?.code, AVIMErrorCode.sessionConflict.rawValue)
                exp.fulfill()
            }
            client1.open(with: .forceOpen) { (success, error) in
                XCTAssertTrue(success)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
}

class AVIMClientDelegator: NSObject, AVIMClientDelegate {
    
    func reset() {
        resuming = nil
        resumed = nil
        paused = nil
        closed = nil
        offline = nil
    }
    
    var resuming: ((AVIMClient) -> Void)?
    func imClientResuming(_ imClient: AVIMClient) {
        resuming?(imClient)
    }
    
    var resumed: ((AVIMClient) -> Void)?
    func imClientResumed(_ imClient: AVIMClient) {
        resumed?(imClient)
    }
    
    var paused: ((AVIMClient, Error?) -> Void)?
    func imClientPaused(_ imClient: AVIMClient, error: Error?) {
        paused?(imClient, error)
    }
    
    var closed: ((AVIMClient, Error?) -> Void)?
    func imClientClosed(_ imClient: AVIMClient, error: Error?) {
        closed?(imClient, error)
    }
    
    var offline: ((AVIMClient, Error?) -> Void)?
    func client(_ client: AVIMClient, didOfflineWithError error: Error?) {
        offline?(client, error)
    }
}
