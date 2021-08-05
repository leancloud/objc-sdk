//
//  LCQueryTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2021/08/05.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

class LCQueryTestCase: BaseTestCase {
    
    func testOrQuery() {
        let object1 = LCObject()
        let object2 = LCObject()
        
        XCTAssertTrue(LCObject.saveAll([object1, object2]))
        
        guard let object1id = object1.objectId,
              let object2id = object2.objectId else {
            return
        }
        
        let query1 = LCQuery(className: object1.className)
        query1.whereKey("objectId", equalTo: object1id)
        let query2 = LCQuery(className: object2.className)
        query2.whereKey("objectId", equalTo: object2id)
        
        XCTAssertEqual(LCQuery.orQuery(withSubqueries: [query1, query2])?.findObjects()?.count, 2)
        XCTAssertEqual(LCQuery.orQuery(withSubqueries: [query1])?.findObjects()?.count, 1)
        XCTAssertEqual(LCQuery.orQuery(withSubqueries: [])?.findObjects()?.count, nil)
        XCTAssertEqual(LCQuery.orQuery(withSubqueries: [LCQuery(className: object1.className)])?.findObjects()?.count, nil)
    }
    
    func testAndQuery() {
        let andKeySame = "andKeySame"
        let andKeyDiff = "andKeyDiff"
        let sameValue = uuid
        let diffValue1 = uuid
        let diffValue2 = uuid
        let object1 = LCObject()
        object1[andKeySame] = sameValue
        object1[andKeyDiff] = diffValue1
        let object2 = LCObject()
        object2[andKeySame] = sameValue
        object2[andKeyDiff] = diffValue2
        
        XCTAssertTrue(LCObject.saveAll([object1, object2]))
        
        guard let _ = object1.objectId,
              let _ = object2.objectId else {
            return
        }
        
        let query1 = LCQuery(className: object1.className)
        query1.whereKey(andKeySame, equalTo: sameValue)
        let query2 = LCQuery(className: object2.className)
        query2.whereKey(andKeyDiff, equalTo: diffValue2)
        
        XCTAssertEqual(LCQuery.andQuery(withSubqueries: [query1, query2])?.findObjects()?.count, 1)
        XCTAssertEqual(LCQuery.andQuery(withSubqueries: [query1])?.findObjects()?.count, 2)
        XCTAssertEqual(LCQuery.andQuery(withSubqueries: [])?.findObjects()?.count, nil)
        XCTAssertEqual(LCQuery.andQuery(withSubqueries: [LCQuery(className: object1.className)])?.findObjects()?.count, nil)
    }
}
