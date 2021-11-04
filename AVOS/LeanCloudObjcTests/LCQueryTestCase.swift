//
//  LCQueryTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2021/08/05.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

// MARK: 测试用例初始化
extension LCQueryTestCase {
    
    static let QueryName = "QueryObject"
    static var queryObjects = [LCObject]()
    
    override class func setUp() {
        super.setUp()
        deleteAllObjects()
        
        let object = createLCObject(fields: [
            .integer: 1,
//            .double: testDouble,
//            .boolean: testBoolean,
//            .string: testString,
//            .array: testArray,
//            .dict: testDictionary,
//            .date: testDate,
//            .data: testData,
        ], save: false, className: QueryName)
        queryObjects.append(object)
        
        
        let object1 = createLCObject(fields: [
            .string: "Jack",
        ], save: false, className: QueryName)
        queryObjects.append(object1)
        
        
        for i in 0..<20 {
            let object = createLCObject(fields: [
                .integer: i,
            ], save: false, className: QueryName)
            queryObjects.append(object)
        }
        
        XCTAssert(LCObject.saveAll(queryObjects))
        
    }
    
//    override class func tearDown() {
//        super.tearDown()
//        deleteAllObjects()
//    }
    
    static func deleteAllObjects() {
        let query = LCQuery.init(className: QueryName)
        let objects = query.findObjects()
        guard let objects = objects as? [LCObject] else {
            return
        }
        XCTAssert(LCObject.deleteAll(objects))
    }
    
    func createQuery() -> LCQuery {
        return LCQuery.init(className: LCQueryTestCase.QueryName)
    }
    
    func queryTest(queryCondition: ((LCQuery) -> ()), filterCondition: ((LCObject) -> Bool)) {
        let query = createQuery()
        queryCondition(query)
        let queryResults = query.findObjects()
        guard let queryResults = queryResults as? [LCObject] else {
            XCTFail()
            return
        }
        let filterResults = LCQueryTestCase.queryObjects.filter(filterCondition)
        print("""
              -------------------------------
                      queryResults.count = \(queryResults.count)
                      filterResults.count = \(filterResults.count)
              -------------------------------
              """)
        XCTAssert(queryResults.count == filterResults.count)
    }
}

// MARK: 查询的单元测试
class LCQueryTestCase: BaseTestCase {
    
    func testKeyExists() {
        let integerKey = TestField.integer.rawValue
        queryTest {
            $0.whereKeyExists(integerKey)
        } filterCondition: {
            if $0.object(forKey: integerKey) != nil {
                return true
            }
            return false
        }
    }
    
    func testKeyNotExists() {
        let integerKey = TestField.integer.rawValue
        queryTest {
            $0.whereKeyDoesNotExist(integerKey)
        } filterCondition: {
            if $0.object(forKey: integerKey) == nil {
                return true
            }
            return false
        }
    }
    
    func testEqual() {
        let integerKey = TestField.integer.rawValue
        let value = 1
        queryTest {
            $0.whereKey(integerKey, equalTo: value)
        } filterCondition: {
            if let result = $0.object(forKey: integerKey) as? Int {
                return result == value
            }
            return false
        }
    }
    
    func testNotEqual() {
        let integerKey = TestField.integer.rawValue
        let value = 1
        queryTest {
            $0.whereKey(integerKey, notEqualTo: value)
        } filterCondition: {
            if let result = $0.object(forKey: integerKey) as? Int {
                return result != value
            }
            return true
        }
    }
    
    func testLessThan() {
        let integerKey = TestField.integer.rawValue
        let value = 10
        queryTest {
            $0.whereKey(integerKey, lessThan: value)
        } filterCondition: {
            if let result = $0.object(forKey: integerKey) as? Int {
                return result < value
            }
            return false
        }
    }
    
    func testLessThanOrEqual() {
        let integerKey = TestField.integer.rawValue
        let value = 10
        queryTest {
            $0.whereKey(integerKey, lessThanOrEqualTo: value)
        } filterCondition: {
            if let result = $0.object(forKey: integerKey) as? Int {
                return result <= value
            }
            return false
        }
    }
    
    func testGreaterThan() {
        let integerKey = TestField.integer.rawValue
        let value = 10
        queryTest {
            $0.whereKey(integerKey, greaterThan: value)
        } filterCondition: {
            if let result = $0.object(forKey: integerKey) as? Int {
                return result > value
            }
            return false
        }
    }
    
    func testGreaterThanOrEqual() {
        let integerKey = TestField.integer.rawValue
        let value = 10
        queryTest {
            $0.whereKey(integerKey, greaterThanOrEqualTo: value)
        } filterCondition: {
            if let result = $0.object(forKey: integerKey) as? Int {
                return result >= value
            }
            return false
        }
    }
    
//    - (void)whereKey:(NSString *)key containedIn:(NSArray *)array;
//
//
//    - (void)whereKey:(NSString *)key notContainedIn:(NSArray *)array;
//
//
//    - (void)whereKey:(NSString *)key containsAllObjectsInArray:(NSArray *)array;
    

    
    
    func testOrQuery() {
        let object1 = LCObject()
        let object2 = LCObject()
        
        XCTAssertTrue(LCObject.saveAll([object1, object2]))
        XCTAssertNotNil(object1.objectId)
        XCTAssertNotNil(object2.objectId)
        
        let object1id = object1.objectId!
        let object2id = object2.objectId!

        
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
        XCTAssertNotNil(object1.objectId)
        XCTAssertNotNil(object2.objectId)
        
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
