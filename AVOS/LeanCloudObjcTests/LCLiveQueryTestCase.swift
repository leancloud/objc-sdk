//
//  LCLiveQueryTestCase.swift
//  LeanCloudObjcTests
//
//  Created by 黄驿峰 on 2021/12/7.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc


// MARK: Test case initialization
extension LCLiveQueryTestCase {
    
    static let QueryName = "LiveQueryObject"
    static var queryObject: LCObject!
    
    override class func setUp() {
        super.setUp()
        deleteAllObjects()
        generateTestObjects()
    }
    
    static func deleteAllObjects() {
        let query = LCQuery.init(className: QueryName)
        let objects = query.findObjects()
        guard let objects = objects as? [LCObject] else {
            return
        }
        XCTAssert(LCObject.deleteAll(objects))
    }
    
    static func generateTestObjects() {
        queryObject = createLCObject(fields: [
            .integer: 1,
            .string: "123",
            .array: [7, 8, 9, 10]
        ], save: true, className: QueryName)
        

    }
    
    
}

class LCLiveQueryTestCase: BaseTestCase, LCLiveQueryDelegate {
    
    var liveQuery: LCLiveQuery!
    
    override func setUp() {
        super.setUp()
        let query = LCQuery.init(className: LCLiveQueryTestCase.QueryName)
        query.whereKeyExists(LCLiveQueryTestCase.TestField.string.rawValue)
        liveQuery = LCLiveQuery.init(query: query)
        liveQuery.delegate = self;
        expecting { exp in
            liveQuery.subscribe { ret, error in
                XCTAssertTrue(ret)
                exp.fulfill()
            }
        }
    }
    
    
    func testObjectDidCreate() {
        let object = LCLiveQueryTestCase.createLCObject(fields: [
            .integer: 1,
            .string: "1234",
            .array: [7, 8, 9, 10]
        ], save: false, className: LCLiveQueryTestCase.QueryName)
        
        expecting { exp in
            objectDidCreate = { [weak self]
                liveQuery, obj in
                self?.objectDidCreate = nil;
                if let obj = obj as? LCObject {
                    XCTAssertEqual(object.objectId, obj.objectId)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
            XCTAssertTrue(object.save())
        }
        
    }
    
    func testObjectDidDelete() {
        let object = LCLiveQueryTestCase.createLCObject(fields: [
            .integer: 1,
            .string: "12345",
            .array: [7, 8, 9, 10]
        ], save: true, className: LCLiveQueryTestCase.QueryName)
        
        expecting { exp in
            objectDidDelete = { [weak self]
                liveQuery, obj in
                self?.objectDidDelete = nil;
                if let obj = obj as? LCObject {
                    XCTAssertEqual(object.objectId, obj.objectId)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
            XCTAssertTrue(object.delete())
        }
    }
    
    func testObjectDidEnter() {
        let object = LCLiveQueryTestCase.createLCObject(fields: [
            .integer: 1,
            .array: [7, 8, 9, 10]
        ], save: true, className: LCLiveQueryTestCase.QueryName)
        
        let fieldKey = TestField.string
        
        expecting { exp in
            objectDidEnter = { [weak self]
                liveQuery, obj, updatedKeys in
                self?.objectDidEnter = nil;
                
                if let obj = obj as? LCObject {
                    XCTAssertEqual(object.objectId, obj.objectId)
                    XCTAssertEqual(fieldKey.rawValue, updatedKeys.first!)
                } else {
                    XCTFail()
                }
                
                exp.fulfill()
            }
            object.set(fields: [
                fieldKey: "123456"
            ])
            XCTAssertTrue(object.save())
        }
    }
    
    func testObjectDidLeave() {
        let object = LCLiveQueryTestCase.createLCObject(fields: [
            .integer: 1,
            .string: "1234",
            .array: [7, 8, 9, 10]
        ], save: true, className: LCLiveQueryTestCase.QueryName)
        
        let fieldKey = TestField.string
        
        expecting { exp in
            objectDidLeave = { [weak self]
                liveQuery, obj, updatedKeys in
                self?.objectDidLeave = nil;
                
                if let obj = obj as? LCObject {
                    XCTAssertEqual(object.objectId, obj.objectId)
                    XCTAssertEqual(fieldKey.rawValue, updatedKeys.first!)
                } else {
                    XCTFail()
                }
                
                exp.fulfill()
            }
            object.setObject(nil, forKey: fieldKey.rawValue)
            XCTAssertTrue(object.save())
        }
    }
    
    func testObjectDidUpdate() {
        let object = LCLiveQueryTestCase.createLCObject(fields: [
            .integer: 1,
            .string: "1234",
            .array: [7, 8, 9, 10]
        ], save: true, className: LCLiveQueryTestCase.QueryName)
        
        let fieldKey = TestField.string
        
        expecting { exp in
            objectDidUpdate = { [weak self]
                liveQuery, obj, updatedKeys in
                self?.objectDidUpdate = nil;
                
                if let obj = obj as? LCObject {
                    XCTAssertEqual(object.objectId, obj.objectId)
                    XCTAssertEqual(fieldKey.rawValue, updatedKeys.first!)
                } else {
                    XCTFail()
                }
                
                exp.fulfill()
            }
            object.setObject("111", forKey: fieldKey.rawValue)
            XCTAssertTrue(object.save())
        }
    }
    
    
    
    var objectDidCreate: ((_ liveQuery: LCLiveQuery, _ object: Any) -> ())?
    var objectDidDelete: ((_ liveQuery: LCLiveQuery, _ object: Any) -> ())?
    var userDidLogin: ((_ liveQuery: LCLiveQuery, _ user: LCUser) -> ())?
    var objectDidEnter: ((_ liveQuery: LCLiveQuery, _ object: Any, _ updatedKeys: [String]) -> ())?
    var objectDidLeave: ((_ liveQuery: LCLiveQuery, _ object: Any, _ updatedKeys: [String]) -> ())?
    var objectDidUpdate: ((_ liveQuery: LCLiveQuery, _ object: Any, _ updatedKeys: [String]) -> ())?
    
    func liveQuery(_ liveQuery: LCLiveQuery, objectDidCreate object: Any) {
        guard let objectDidCreate = objectDidCreate else {
            return
        }
        objectDidCreate(liveQuery, object)
    }
    
    func liveQuery(_ liveQuery: LCLiveQuery, objectDidDelete object: Any) {
        guard let objectDidDelete = objectDidDelete else {
            return
        }
        objectDidDelete(liveQuery, object)
    }
    
    func liveQuery(_ liveQuery: LCLiveQuery, userDidLogin user: LCUser) {
        guard let userDidLogin = userDidLogin else {
            return
        }
        userDidLogin(liveQuery, user)
    }
    
    func liveQuery(_ liveQuery: LCLiveQuery, objectDidEnter object: Any, updatedKeys: [String]) {
        guard let objectDidEnter = objectDidEnter else {
            return
        }
        objectDidEnter(liveQuery, object, updatedKeys)
    }
    
    func liveQuery(_ liveQuery: LCLiveQuery, objectDidLeave object: Any, updatedKeys: [String]) {
        guard let objectDidLeave = objectDidLeave else {
            return
        }
        objectDidLeave(liveQuery, object, updatedKeys)
    }
    
    func liveQuery(_ liveQuery: LCLiveQuery, objectDidUpdate object: Any, updatedKeys: [String]) {
        guard let objectDidUpdate = objectDidUpdate else {
            return
        }
        objectDidUpdate(liveQuery, object, updatedKeys)
    }
    

}
