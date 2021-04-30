//
//  LCLiveQueryTestBase.swift
//  AVOSCloudLiveQuery-iOSTests
//
//  Created by zapcannon87 on 2018/7/16.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class LCLiveQueryTestBase: LCTestBase {
    
    override class func setUp() {
        super.setUp()
        if let RTMServerURL: String = LCTestEnvironment.sharedInstance().url_RTMServer {
            AVOSCloudIM.defaultOptions().rtmServer = RTMServerURL
        }
    }
    
    override func setUp() {
        super.setUp()
    }
    
    override class func tearDown() {
        super.tearDown()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testc_live_query() {
        
        if self.isServerTesting {
            return
        }
        
        let query: LCQuery = LCQuery(className: "Todo")
        query.whereKeyExists("objectId")
        
        let liveQuery: LCLiveQuery = LCLiveQuery(query: query)
        let liveQueryDelegate: LCLiveQueryDelegateWrapper = LCLiveQueryDelegateWrapper()
        liveQuery.delegate = liveQueryDelegate
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            liveQuery.subscribe(callback: { (succeeded: Bool, error: Error?) in
                XCTAssertTrue(Thread.isMainThread)
                semaphore.decrement()
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            let todo: LCObject = LCObject(className: "Todo")
            semaphore.increment(2)
            liveQueryDelegate.objectDidCreateClosure = { (liveQuery: LCLiveQuery, object: Any) in
                XCTAssertTrue(Thread.isMainThread)
                semaphore.decrement()
                XCTAssertEqual(todo.objectId, (object as? LCObject)?.objectId)
            }
            todo.saveInBackground({ (succeeded: Bool, error: Error?) in
                XCTAssertTrue(Thread.isMainThread)
                semaphore.decrement()
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
    }
    
}

class LCLiveQueryDelegateWrapper: NSObject, LCLiveQueryDelegate {
    
    var userDidLoginClosure: ((LCLiveQuery, LCUser) -> Void)?
    func liveQuery(_ liveQuery: LCLiveQuery, userDidLogin user: LCUser) {
        self.userDidLoginClosure?(liveQuery, user)
    }
    
    var objectDidCreateClosure: ((LCLiveQuery, Any) -> Void)?
    func liveQuery(_ liveQuery: LCLiveQuery, objectDidCreate object: Any) {
        self.objectDidCreateClosure?(liveQuery, object)
    }
    
    var objectDidDeleteClosure: ((LCLiveQuery, Any) -> Void)?
    func liveQuery(_ liveQuery: LCLiveQuery, objectDidDelete object: Any) {
        self.objectDidDeleteClosure?(liveQuery, object)
    }
    
    var objectDidEnterWithUpdatedKeysClosure: ((LCLiveQuery, Any, [String]) -> Void)?
    func liveQuery(_ liveQuery: LCLiveQuery, objectDidEnter object: Any, updatedKeys: [String]) {
        self.objectDidEnterWithUpdatedKeysClosure?(liveQuery, object, updatedKeys)
    }
    
    var objectDidLeaveWithUpdatedKeysClosure: ((LCLiveQuery, Any, [String]) -> Void)?
    func liveQuery(_ liveQuery: LCLiveQuery, objectDidLeave object: Any, updatedKeys: [String]) {
        self.objectDidLeaveWithUpdatedKeysClosure?(liveQuery, object, updatedKeys)
    }
    
    var objectDidUpdateWithUpdatedKeysClosure: ((LCLiveQuery, Any, [String]) -> Void)?
    func liveQuery(_ liveQuery: LCLiveQuery, objectDidUpdate object: Any, updatedKeys: [String]) {
        self.objectDidUpdateWithUpdatedKeysClosure?(liveQuery, object, updatedKeys)
    }
    
}
