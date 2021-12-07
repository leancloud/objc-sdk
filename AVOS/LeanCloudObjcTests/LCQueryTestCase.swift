//
//  LCQueryTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2021/08/05.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

// MARK: Test case initialization
extension LCQueryTestCase {
    
    static let QueryName = "QueryObject"
    static var queryObjects = [LCObject]()
    
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
        let object = createLCObject(fields: [
            .integer: 1,
            .array: [7, 8, 9, 10]
        ], save: false, className: QueryName)
        queryObjects.append(object)
        
        let object1 = createLCObject(fields: [
            .string: "Jack",
        ], save: false, className: QueryName)
        queryObjects.append(object1)
        
        let object2 = createLCObject(fields: [
            .string: "Jac",
        ], save: false, className: QueryName)
        queryObjects.append(object2)
        
        let object3 = createLCObject(fields: [
            .string: "ack",
        ], save: false, className: QueryName)
        queryObjects.append(object3)
        
        for i in 0..<20 {
            let total = Double(i) * Double(i + 1)/2
            let object = createLCObject(fields: [
                .integer: i,
                .array: Array(0..<i),
                .point: LCGeoPoint.init(latitude: total * 0.1 , longitude: total * 0.1)
            ], save: false, className: QueryName)
            queryObjects.append(object)
        }
        
        XCTAssert(LCObject.saveAll(queryObjects))
        
        XCTAssertNotNil(object.objectId)
        XCTAssertNotNil(object1.objectId)
        XCTAssertNotNil(object2.objectId)
        XCTAssertNotNil(object3.objectId)
        object1[TestField.object.rawValue] = object
        object2[TestField.object.rawValue] = object1
        object3[TestField.object.rawValue] = object2
        XCTAssert(LCObject.saveAll([object1, object2, object3]))
        

    }
    
    func createQuery() -> LCQuery {
        return LCQuery.init(className: LCQueryTestCase.QueryName)
    }
    
    func queryTest(query: LCQuery, filterCondition: ((LCObject) -> Bool)) {
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
    
    func queryTest(queryCondition: ((LCQuery) -> ()), filterCondition: ((LCObject) -> Bool)) {
        
        let query = createQuery()
        queryCondition(query)
        queryTest(query: query, filterCondition: filterCondition)
    }
}

// MARK: Unit tests of queries
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
    
    func testContainedIn() {
        let arrayKey = TestField.array.rawValue
        let value = [7, 8, 9]
        queryTest {
            $0.whereKey(arrayKey, containedIn: value)
        } filterCondition: {
            if let result = $0.object(forKey: arrayKey) as? [Int] {
                let resultSet = Set(result)
                let valueSet = Set(value)
                // Check whether the number of intersections is greater than 0
                return resultSet.intersection(valueSet).count > 0
            }
            return false
        }
    }
    
    func testNotContainedIn() {
        let arrayKey = TestField.array.rawValue
        let value = [8, 9]
        queryTest {
            $0.whereKey(arrayKey, notContainedIn: value)
        } filterCondition: {
            if let result = $0.object(forKey: arrayKey) as? [Int] {
                let resultSet = Set(result)
                let valueSet = Set(value)
                // Determine whether the number of intersections is equal to 0
                return resultSet.intersection(valueSet).count == 0
            }
            return true
        }
    }
    
    func testContainsAllObjectsIn() {
        let arrayKey = TestField.array.rawValue
        let value = [7, 8, 9, 10]
        queryTest {
            $0.whereKey(arrayKey, containsAllObjectsIn: value)
        } filterCondition: {
            if let result = $0.object(forKey: arrayKey) as? [Int] {
                let resultSet = Set(result)
                let valueSet = Set(value)
                // Check whether valueSet is a subset of resultSet
                return resultSet.isSuperset(of: valueSet)
            }
            return false
        }
    }
    
    
    func testSizeEqualTo() {
        let arrayKey = TestField.array.rawValue
        let value: UInt = 4
        queryTest {
            $0.whereKey(arrayKey, sizeEqualTo: value)
        } filterCondition: {
            if let result = $0.object(forKey: arrayKey) as? [Int] {
                return result.count == value
            }
            return false
        }
    }
    
    func testContainsString() {
        let stringKey = TestField.string.rawValue
        let value = "ac"
        queryTest {
            $0.whereKey(stringKey, contains: value)
        } filterCondition: {
            if let result = $0.object(forKey: stringKey) as? String {
                return result.contains(value)
            }
            return false
        }
    }

    func testHasPrefix() {
        let stringKey = TestField.string.rawValue
        let value = "Jac"
        queryTest {
            $0.whereKey(stringKey, hasPrefix: value)
        } filterCondition: {
            if let result = $0.object(forKey: stringKey) as? String {
                return result.hasPrefix(value)
            }
            return false
        }
    }
    
    func testHasSuffix() {
        let stringKey = TestField.string.rawValue
        let value = "ack"
        queryTest {
            $0.whereKey(stringKey, hasSuffix: value)
        } filterCondition: {
            if let result = $0.object(forKey: stringKey) as? String {
                return result.hasSuffix(value)
            }
            return false
        }
    }
    
    func testMatchesRegex() {
        let stringKey = TestField.string.rawValue
        let value = "Jack"
        queryTest {
            $0.whereKey(stringKey, matchesRegex: value)
        } filterCondition: {
            if let result = $0.object(forKey: stringKey) as? String {
                return NSPredicate(format: "SELF MATCHES %@", value).evaluate(with: result)
            }
            return false
        }
    }
    
    func testMatchesRegexAndModifiers() {
        let stringKey = TestField.string.rawValue
        let value = "jack"
        queryTest {
            //ignore case
            $0.whereKey(stringKey, matchesRegex: value, modifiers: "i")
        } filterCondition: {
            if let result = $0.object(forKey: stringKey) as? String {
                //ignore case
                return NSPredicate(format: "SELF MATCHES[c] %@", value).evaluate(with: result)
            }
            return false
        }
    }
    
    func testOrQuery() {
        
        let arrayKey = TestField.array.rawValue
        let value1 = 8
        let value2 = 9
        
        let query1 = createQuery()
        query1.whereKey(arrayKey, equalTo: value1)
        
        let query2 = createQuery()
        query2.whereKey(arrayKey, equalTo: value2)
        
        let query = LCQuery.orQuery(withSubqueries: [query1, query2])
        XCTAssertNotNil(query)
        
        queryTest(query: query!) {
            if let result = $0.object(forKey: arrayKey) as? [Int] {
                let resultSet = Set(result)
                return resultSet.contains(value1) || resultSet.contains(value2)
            }
            return false
        }
    }
    
    func testAndQuery() {
        let arrayKey = TestField.array.rawValue
        let value1 = 8
        let value2 = 9
        
        let query1 = createQuery()
        query1.whereKey(arrayKey, equalTo: value1)
        
        let query2 = createQuery()
        query2.whereKey(arrayKey, equalTo: value2)
        
        let query = LCQuery.andQuery(withSubqueries: [query1, query2])
        XCTAssertNotNil(query)
        
        queryTest(query: query!) {
            if let result = $0.object(forKey: arrayKey) as? [Int] {
                let resultSet = Set(result)
                return resultSet.contains(value1) && resultSet.contains(value2)
            }
            return false
        }
    }
    
    
    func testMultipleConditions() {
        let arrayKey = TestField.array.rawValue
        let value1 = 8
        let value2 = 9

        queryTest {
            $0.whereKey(arrayKey, equalTo: value1)
            $0.whereKey(arrayKey, equalTo: value2)
        } filterCondition: {
            if let result = $0.object(forKey: arrayKey) as? [Int] {
                let resultSet = Set(result)
                return resultSet.contains(value1) && resultSet.contains(value2)
            }
            return false
        }
    }
    
   
    func testNearGeoPoint () {
        let stringKey = TestField.point.rawValue
        let value = LCGeoPoint.init(latitude: 10, longitude: 10)
        queryTest {
            $0.whereKey(stringKey, nearGeoPoint: value)
        } filterCondition: {
            if let _ = $0.object(forKey: stringKey) as? LCGeoPoint {
                return true
            }
            return false
        }
    }
    
    func testNearGeoPointWithinMiles () {
        let stringKey = TestField.point.rawValue
        let value = LCGeoPoint.init(latitude: 10, longitude: 10)
        let miles = 500.0
        queryTest {
            $0.whereKey(stringKey, nearGeoPoint: value, withinMiles: miles)
        } filterCondition: {
            if let result = $0.object(forKey: stringKey) as? LCGeoPoint {
                return getDistance(point1: result, point2: value) <= miles * 1609
            }
            return false
        }
    }
    
    func testNearGeoPointWithinKilometers () {
        let stringKey = TestField.point.rawValue
        let value = LCGeoPoint.init(latitude: 10, longitude: 10)
        let kilometers = 500.0
        queryTest {
            $0.whereKey(stringKey, nearGeoPoint: value, withinKilometers: kilometers)
        } filterCondition: {
            if let result = $0.object(forKey: stringKey) as? LCGeoPoint {
                return getDistance(point1: result, point2: value) <= kilometers * 1000
            }
            return false
        }
    }
    
    func testNearGeoPointWithMinDistance () {
        let stringKey = TestField.point.rawValue
        let value = LCGeoPoint.init(latitude: 10, longitude: 10)
        let kilometers = 500.0
        queryTest {
            $0.whereKey(stringKey, nearGeoPoint: value, minDistance: kilometers, minDistanceUnit: .kilometer)
        } filterCondition: {
            if let result = $0.object(forKey: stringKey) as? LCGeoPoint {
                return getDistance(point1: result, point2: value) >= kilometers * 1000
            }
            return false
        }
    }
    
    func testNearGeoPointFromSouthwestToNortheast () {
        let stringKey = TestField.point.rawValue
        let Southwest = LCGeoPoint.init(latitude: 5, longitude: 10)
        let Northeast = LCGeoPoint.init(latitude: 10, longitude: 5)
        queryTest {
            $0.whereKey(stringKey, withinGeoBoxFromSouthwest: Southwest, toNortheast: Northeast)
        } filterCondition: {
            if let result = $0.object(forKey: stringKey) as? LCGeoPoint {
                if result.latitude >= Southwest.latitude,
                   result.latitude <= Northeast.latitude,
                   result.longitude >= Northeast.longitude,
                   result.longitude <= Southwest.longitude {
                    return true
                }
            }
            return false
        }
    }



    func testMatchesKeyInQuery() {
        let strKey = TestField.string.rawValue
        let value = "Jack"

        queryTest {
            let query = createQuery()
            query.whereKey(strKey, equalTo: value)
            $0.whereKey(strKey, matchesKey: strKey, in: query)
        } filterCondition: {
            if let str = $0.object(forKey: strKey) as? String{
                return str == value
            }
            return false
        }
    }
    
    func testNotMatchesKeyInQuery() {
        let strKey = TestField.string.rawValue
        let value = "Jack"

        queryTest {
            let query = createQuery()
            query.whereKey(strKey, equalTo: value)
            $0.whereKey(strKey, doesNotMatchKey: strKey, in: query)
        } filterCondition: {
            if let str = $0.object(forKey: strKey) as? String{
                return str != value
            }
            return true
        }
    }

    
    func testMatchesQuery() {
        let strKey = TestField.string.rawValue
        let objKey = TestField.object.rawValue
        let value = "Jack"

        queryTest {
            let query = createQuery()
            query.whereKey(strKey, equalTo: value)
            $0.whereKey(objKey, matchesQuery: query)
        } filterCondition: {
            if let result = $0.object(forKey: objKey) as? LCObject,
               let str = result.object(forKey: strKey) as? String{
                return str == value
            }
            return false
        }
    }

    func testNotMatchesQuery() {
        let strKey = TestField.string.rawValue
        let objKey = TestField.object.rawValue
        let value = "Jack"

        queryTest {
            let query = createQuery()
            query.whereKey(strKey, equalTo: value)
            $0.whereKey(objKey, doesNotMatch: query)
        } filterCondition: {
            if let result = $0.object(forKey: objKey) as? LCObject,
               let str = result.object(forKey: strKey) as? String{
                return str != value
            }
            return true
        }
    }
    
    func testLimit() {
        let integerKey = TestField.integer.rawValue
        let limit = 8
        var currentCount = 0
        queryTest {
            $0.whereKeyExists(integerKey)
            $0.limit = limit
        } filterCondition: {
            if $0.object(forKey: integerKey) != nil {
                if currentCount >= limit {
                    return false
                } else {
                    currentCount += 1
                    return true
                }
            }
            return false
        }
    }
    
    func testSkip() {
        let integerKey = TestField.integer.rawValue
        let skip = 8
        var currentCount = 0
        queryTest {
            $0.whereKeyExists(integerKey)
            $0.skip = skip
        } filterCondition: {
            if $0.object(forKey: integerKey) != nil {
                if currentCount >= skip {
                    return true
                } else {
                    currentCount += 1
                    return false
                }
            }
            return false
        }
    }
    
    func testOrderByAscending() {
        let integerKey = TestField.integer.rawValue
        let query = createQuery()
        query.whereKeyExists(integerKey)
        query.addAscendingOrder(integerKey)
        let queryResults = query.findObjects()
        guard let queryResults = queryResults as? [LCObject] else {
            XCTFail()
            return
        }
        var filterResults = LCQueryTestCase.queryObjects.filter {
            if $0.object(forKey: integerKey) != nil {
                return true
            }
            return false
        }
        XCTAssert(queryResults.count == filterResults.count)
        filterResults.sort {
            if let first = $0.object(forKey: integerKey) as? Int, let second = $1.object(forKey: integerKey) as? Int {
                return first < second
            }
            XCTFail()
            return false
        }
        for i in 0..<queryResults.count {
            if let first = queryResults[i].object(forKey: integerKey) as? Int,
                let second = filterResults[i].object(forKey: integerKey) as? Int {
                XCTAssert(first == second)
            } else {
                XCTFail()
            }
        }
    }
    
    func testOrderByDescending() {
        let integerKey = TestField.integer.rawValue
        let query = createQuery()
        query.whereKeyExists(integerKey)
        query.order(byDescending: integerKey)
        let queryResults = query.findObjects()
        guard let queryResults = queryResults as? [LCObject] else {
            XCTFail()
            return
        }
        var filterResults = LCQueryTestCase.queryObjects.filter {
            if $0.object(forKey: integerKey) != nil {
                return true
            }
            return false
        }
        XCTAssert(queryResults.count == filterResults.count)
        filterResults.sort {
            if let first = $0.object(forKey: integerKey) as? Int, let second = $1.object(forKey: integerKey) as? Int {
                return first > second
            }
            XCTFail()
            return false
        }
        for i in 0..<queryResults.count {
            if let first = queryResults[i].object(forKey: integerKey) as? Int,
                let second = filterResults[i].object(forKey: integerKey) as? Int {
                XCTAssert(first == second)
            } else {
                XCTFail()
            }
        }
    }
    
    func testSelectKeys() {
        let integerKey = TestField.integer.rawValue
        let stringKey = TestField.string.rawValue
        let query = createQuery()
        query.selectKeys([stringKey])
        let queryResults = query.findObjects()
        guard let queryResults = queryResults as? [LCObject] else {
            XCTFail()
            return
        }
        queryResults.forEach {
            if $0.object(forKey: integerKey) != nil {
                XCTFail()
            }
        }
    }

    func testIncludeKey() {
        let objectKey = TestField.object.rawValue
        let query = createQuery()
        query.includeKey(objectKey)
        let queryResults = query.findObjects()
        guard let queryResults = queryResults as? [LCObject] else {
            XCTFail()
            return
        }
        var hasObject = false;
        for object in queryResults {
            if let result = object.object(forKey: objectKey) as? LCObject,
               result.allKeys().count > 1 {
                hasObject = true
                break
            }
        }
        if hasObject == false {
            XCTFail()
        }
    }
    
    func testQueryCount() {
        let integerKey = TestField.integer.rawValue
        let query = createQuery()
        query.whereKeyExists(integerKey)
        expecting { exp in
            query.countObjectsInBackground { count, error in
                XCTAssertNil(error)
                let filterResults = LCQueryTestCase.queryObjects.filter {
                    if $0.object(forKey: integerKey) != nil {
                        return true
                    }
                    return false
                }
                XCTAssertEqual(filterResults.count, count)
                exp.fulfill()
            }
        }
        
    }
    
    
    func testQueryCache() {
        let integerKey = TestField.integer.rawValue
        let query = createQuery()
        query.whereKeyExists(integerKey)
        query.cachePolicy = .cacheElseNetwork
        query.maxCacheAge = 60 * 60 * 24
        let queryResults = query.findObjects()
        guard let _ = queryResults as? [LCObject] else {
            XCTFail()
            return
        }
        query.findObjects()
        var isInCache = query.hasCachedResult()
        XCTAssertTrue(isInCache)
        
        query.clearCachedResult()
        isInCache = query.hasCachedResult()
        XCTAssertFalse(isInCache)
        
        query.findObjects()
        query.findObjects()
        isInCache = query.hasCachedResult()
        XCTAssertTrue(isInCache)
        
        LCQuery.clearAllCachedResults()
        isInCache = query.hasCachedResult()
        XCTAssertFalse(isInCache)
        
        
    }
    
}
