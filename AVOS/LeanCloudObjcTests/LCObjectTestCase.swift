//
//  LCObjectTestCase.swift
//  LeanCloudObjcTests
//
//  Created by 黄驿峰 on 2021/10/25.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

//        var error: NSError?
//        let result = testObject.save(&error)
//        if let error = error {
//            XCTFail(error.localizedDescription)
//        }
//        XCTAssert(result)

class LCObjectTestCase: BaseTestCase {

    
    func testDeinit() {
        var object: LCObject! = LCObject()
        weak var wObject: LCObject? = object
        XCTAssertNotNil(wObject)
        object = nil
        XCTAssertNil(wObject)
    }
    
    func testSaveObjectWithOption() {
        let object = LCTestObject(className: "\(LCTestObject.self)")
        object.numberField = 0
        var option = LCSaveOption.init()
        option.fetchWhenSave = true
        do {
            try object.save(with: option)
        } catch  {
            XCTFail(error.localizedDescription)
        }
        
        if let objectId = object.objectId {
            object.numberField = 1
            
            let noResultQuery = LCQuery(className: "\(LCTestObject.self)")
            noResultQuery.whereKey("objectId", equalTo: UUID().uuidString)
            option = LCSaveOption.init()
            option.query = noResultQuery
            do {
                try object.save(with: option)
                XCTFail()
            } catch let error as NSError  {
                XCTAssertEqual(error.code, 305)
            }
            
            let hasResultQuery = LCQuery(className: "\(LCTestObject.self)")
            hasResultQuery.whereKey("objectId", equalTo: objectId)
            option = LCSaveOption.init()
            option.query = hasResultQuery
            do {
                try object.save(with: option)
            } catch let error as NSError  {
                XCTFail(error.localizedDescription)
            }
        } else {
            XCTFail("no objectId")
        }
    }
    
    
    
    
    func testSaveBasicTypeData() {
        let testObject = LCObject.init(className: LCObjectTestCase.className)
        
        let testInteger = 2021
        testObject.setObject(testInteger, forKey: TestField.integer.rawValue)
        let testDouble = 3.14
        testObject.setObject(testDouble, forKey: TestField.double.rawValue)
        let testBoolean = true
        testObject.setObject(testBoolean, forKey: TestField.boolean.rawValue)
        let testString = "流行音乐榜单"
        testObject.setObject(testString, forKey: TestField.string.rawValue)
        let testArray = [testString]
        testObject.setObject(testArray, forKey: TestField.array.rawValue)
        let testDictionary = ["流行音乐": 2014, "榜单": 2018]
        testObject.setObject(testDictionary, forKey: TestField.dict.rawValue)
        let testDate = Date.init()
        testObject.setObject(testDate, forKey: TestField.date.rawValue)
        let testData = testString.data(using: .utf8)!
        testObject.setObject(testData, forKey: TestField.data.rawValue)
        
        
        expecting { exp in
            testObject.saveInBackground { result, error in
                XCTAssertTrue(result)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        XCTAssertNotNil(testObject.objectId)
        
        LCObjectTestCase.verifyLCObjectValues(objectID: testObject.objectId!, needVerifyFields: [
            .integer: testInteger,
            .double: testDouble,
            .boolean: testBoolean,
            .string: testString,
            .array: testArray,
            .dict: testDictionary,
            .date: testDate,
            .data: testData,
        ])
        
    }
    
    
    func testSynchronizeObject() {
        
        let testInteger = 2021
        let testDouble = 3.14
        let testBoolean = true
        let testString = "流行音乐榜单"
        
        let object = LCObjectTestCase.createLCObject(fields: [
            .integer: testInteger,
            .double: testDouble,
            .boolean: testBoolean,
            .string: testString,
        ])
        
        var newObject = LCObject.init(className: LCObjectTestCase.className, objectId: object.objectId!)
        expecting { exp in
            newObject.fetchInBackground { object, error in
                XCTAssertNotNil(object)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        LCObjectTestCase.verifyLCObjectValues(objectID: object.objectId!, needVerifyFields: [
            .integer: testInteger,
            .double: testDouble,
            .boolean: testBoolean,
            .string: testString,
        ])
        
        
        newObject = LCObject.init(className: LCObjectTestCase.className, objectId: object.objectId!)
        newObject.setObject(1888, forKey: TestField.integer.rawValue)
        newObject.setObject(false, forKey: TestField.boolean.rawValue)
        expecting { exp in
            newObject.fetchInBackground(withKeys: [TestField.double.rawValue, TestField.string.rawValue]) { object, error in
                XCTAssertNotNil(object)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        LCObjectTestCase.verifyLCObjectValues(objectID: object.objectId!, needVerifyFields: [
            .double: testDouble,
            .string: testString,
        ])
        
        XCTAssertNil(newObject.object(forKey:TestField.integer.rawValue))
        XCTAssertNil(newObject.object(forKey:TestField.boolean.rawValue))
        
    }
    
    func testUpdateObject() {
        
        let testInteger = 2021
        let testDouble = 3.14
        let testBoolean = true
        let testString = "流行音乐榜单"
        
        // To generate the object
        let object = LCObjectTestCase.createLCObject(fields: [
            .integer: testInteger,
            .double: testDouble,
            .boolean: testBoolean,
            .string: testString,
        ])
        
        // To update the object
        let newString = "古典音乐榜单"
        LCObjectTestCase.updateLCObject(objectID: object.objectId!) {
            $0.setObject(newString, forKey: TestField.string.rawValue)
        }
        
        // To test the object
        LCObjectTestCase.verifyLCObjectValues(objectID: object.objectId!, needVerifyFields: [
            TestField.integer: testInteger,
            TestField.double: testDouble,
            TestField.boolean: testBoolean,
            TestField.string: newString,
        ])
        
        
    }
    
    func testConditionalUpdateObject() {
        
        let testInteger = 2021
        let testDouble = 3.14
        
        // To generate the object
        let object = LCObjectTestCase.createLCObject(fields: [
            .integer: testInteger,
            .double: testDouble,
        ])
        
        
        var newObject = LCObject.init(className: LCObjectTestCase.className, objectId: object.objectId!)
        var change = testInteger
        newObject.incrementKey(TestField.integer.rawValue, byAmount: NSNumber.init(value: -change))
        
        var query = LCQuery.init()
        query.whereKey(TestField.integer.rawValue, greaterThan: change)
        var option = LCSaveOption.init()
        option.query = query
        expecting { exp in
            newObject.saveInBackground(with: option) { result, error in
                XCTAssertFalse(result)
                if let error = error {
                    XCTAssertEqual((error as NSError).code, 305)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }
        
        // To test the object
        LCObjectTestCase.verifyLCObjectValues(objectID: object.objectId!, needVerifyFields: [
            .integer: testInteger,
            .double: testDouble,
        ])

         
        newObject = LCObject.init(className: LCObjectTestCase.className, objectId: object.objectId!)
        change = testInteger - 1
        newObject.incrementKey(TestField.integer.rawValue, byAmount: NSNumber.init(value: -change))
        
        query = LCQuery.init()
        query.whereKey(TestField.integer.rawValue, greaterThan: change)
        option = LCSaveOption.init()
        option.query = query
        expecting { exp in
            newObject.saveInBackground(with: option) { result, error in
                XCTAssert(result)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        // To test the object
        LCObjectTestCase.verifyLCObjectValues(objectID: object.objectId!, needVerifyFields: [
            TestField.integer: 1,
            TestField.double: testDouble,
        ])
        
    }
    
    
    
    func testUpdateCounter() {
        
        let testInteger = 2021
        let testDouble = 3.14
        
        // To generate the object
        let object = LCObjectTestCase.createLCObject(fields: [
            .integer: testInteger,
            .double: testDouble,
        ])
        
        let changeInteger = 66
        let changeDouble = 6.66
        LCObjectTestCase.updateLCObject(objectID: object.objectId!) {
            $0.incrementKey(TestField.integer.rawValue, byAmount: NSNumber.init(value: changeInteger))
            $0.incrementKey(TestField.double.rawValue, byAmount: NSNumber.init(value: changeDouble))
        }
        
        // To test the object
        LCObjectTestCase.verifyLCObjectValues(objectID: object.objectId!, needVerifyFields: [
            .integer: testInteger + changeInteger,
            .double: testDouble + changeDouble,
        ])
  
    }
    
    func testUpdateArray () {
        
        let string1 = "流行"
        let string2 = "古典"
        let string3 = "摇滚"
        
        // To generate the object
        let object = LCObjectTestCase.createLCObject(fields: [
            .array: [string1],
        ])
        
        let objectID = object.objectId!
        
        // 测试：addObject:forKey: 将指定对象附加到数组末尾。
        LCObjectTestCase.updateLCObject(objectID: objectID) {
            $0.add(string2, forKey: TestField.array.rawValue)
            $0.add(string2, forKey: TestField.array.rawValue)
        }
        LCObjectTestCase.verifyLCObjectValues(objectID: object.objectId!, needVerifyFields: [TestField.array: [string1, string2, string2]])
        
        // 测试：removeObject:forKey: 从数组字段中删除指定对象的所有实例。
        LCObjectTestCase.updateLCObject(objectID: objectID) {
            $0.remove(string2, forKey: TestField.array.rawValue)
        }
        LCObjectTestCase.verifyLCObjectValues(objectID: object.objectId!, needVerifyFields: [TestField.array: [string1]])
        
        // 测试：addObjectsFromArray:forKey: 将指定对象数组附加到数组末尾。
        LCObjectTestCase.updateLCObject(objectID: objectID) {
            $0.addObjects(from: [string2, string3], forKey: TestField.array.rawValue)
        }
        LCObjectTestCase.verifyLCObjectValues(objectID: object.objectId!, needVerifyFields: [TestField.array: [string1, string2, string3]])
        
        // 测试：addObjectsFromArray:forKey: 将指定对象数组附加到数组末尾。
        LCObjectTestCase.updateLCObject(objectID: objectID) {
            $0.removeObjects(in: [string3, string1], forKey: TestField.array.rawValue)
        }
        LCObjectTestCase.verifyLCObjectValues(objectID: object.objectId!, needVerifyFields: [TestField.array: [string2]])
        
        // 测试：addUniqueObject:forKey: 将指定对象附加到数组末尾，确保对象唯一。
        LCObjectTestCase.updateLCObject(objectID: objectID) {
            $0.addUniqueObject(string2, forKey: TestField.array.rawValue)
        }
        LCObjectTestCase.verifyLCObjectValues(objectID: object.objectId!, needVerifyFields: [TestField.array: [string2]])
        
        // addUniqueObjectsFromArray:forKey: 将指定对象数组附加到数组末尾，确保对象唯一。
        LCObjectTestCase.updateLCObject(objectID: objectID) {
            $0.addUniqueObjects(from: [string2, string1, string3], forKey: TestField.array.rawValue)
        }
        LCObjectTestCase.verifyLCObjectValues(objectID: object.objectId!, needVerifyFields: [TestField.array: [string2, string1, string3]])

    }
    
    func testDeleteObject () {
        // To generate the object
        let object = LCObjectTestCase.createLCObject(fields: [:])
        
        var newObject = LCObject.init(className: LCObjectTestCase.className, objectId: object.objectId!)
        expecting { exp in
            newObject.deleteInBackground { result, error in
                XCTAssert(result)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }

        newObject = LCObject.init(className: LCObjectTestCase.className, objectId: object.objectId!)
        XCTAssertFalse(newObject.fetch())

    }
    
    func testBatchOperation () {
        let testInteger = 2021
        let testDouble = 3.14
        let fields: [TestField: Any] = [
            .integer: testInteger,
            .double: testDouble,
        ]
        
        let object1 = LCObjectTestCase.createLCObject(fields: fields, save: false)
        let object2 = LCObjectTestCase.createLCObject(fields: fields, save: false)
        let objects = [object1, object2]
        
        // 批量保存
        expecting { exp in
            LCObject.saveAll(inBackground: objects) { result, error in
                XCTAssert(result)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        objects.forEach {
            XCTAssertNotNil($0.objectId)
        }
        let objectIDs = objects.map { $0.objectId! }
        
        objectIDs.forEach {
            LCObjectTestCase.verifyLCObjectValues(objectID: $0, needVerifyFields: fields)
        }
        
        // 批量同步
        let newObjects = objectIDs.map {
            LCObject.init(className: BaseTestCase.className, objectId: $0)
        }
        expecting { exp in
            LCObject.fetchAll(inBackground: newObjects) { result, error in
                XCTAssert(result != nil)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        newObjects.forEach {
            LCObjectTestCase.verifyLCObjectValues(object: $0, needVerifyFields: fields)
        }
        
        // 批量删除
        expecting { exp in
            LCObject.deleteAll(inBackground: objects) { result, error in
                XCTAssert(result)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        objectIDs.forEach {
            let temp = LCObject.init(className: LCObjectTestCase.className, objectId: $0)
            XCTAssertFalse(temp.fetch())
            temp.saveEventually()
        }

    }
    
    func testSerialization () {
        let testInteger = 2021
        let testDouble = 3.14
        let testBoolean = true
        let testString = "流行音乐榜单"
        let testArray = [testString]
        let testDictionary = ["流行音乐": 2014, "榜单": 2018]
        let testDate = Date.init()
        let testData = testString.data(using: .utf8)!
        let testObject = LCObjectTestCase.createLCObject(fields: [
            .integer: testInteger,
            .double: testDouble,
            .boolean: testBoolean,
            .string: testString,
        ])
        
        let fields: [TestField: Any] = [
            .integer: testInteger,
            .double: testDouble,
            .boolean: testBoolean,
            .string: testString,
            .array: testArray,
            .dict: testDictionary,
            .date: testDate,
            .data: testData,
            .object: testObject,
        ]
        
        let object = LCObjectTestCase.createLCObject(fields: fields, save: false)
        
        let serializedJSONDictionary = object.dictionaryForObject()
        
        do {
            let data = try JSONSerialization.data(withJSONObject: serializedJSONDictionary, options: [])
            print(String.init(data: data, encoding: .utf8)!)
        }  catch {
            XCTFail("\(error)")
        }
        
        let newObject = LCObject.init(dictionary: serializedJSONDictionary as! [AnyHashable : Any])
        XCTAssertNotNil(newObject)
        LCObjectTestCase.verifyLCObjectValues(object: newObject!, needVerifyFields: fields)
        
    }
    
    
}




