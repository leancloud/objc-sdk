//
//  BaseTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2020/06/22.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

//extension LCGeoPoint: Equatable {
//
//}

class BaseTestCase: XCTestCase {
    
    static let timeout: TimeInterval = 30.0
    let timeout: TimeInterval = 30.0
    
    static let className = "TestObject"
    
    enum TestField: String {
        case integer = "testInteger"
        case double = "testDouble"
        case boolean = "testBoolean"
        case string = "testString"
        case array = "testArray"
        case dict = "testDictionary"
        case date = "testDate"
        case data = "testData"
        case object = "testObject"
        case point = "testPoint"
    }
    
    static var uuid: String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    var uuid: String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    struct AppInfo {
        let id: String
        let key: String
        let serverURL: String
        let masterKey: String
    }
    
    static let cnApp = AppInfo(
        id: "S5vDI3IeCk1NLLiM1aFg3262-gzGzoHsz",
        key: "7g5pPsI55piz2PRLPWK5MPz0",
        serverURL: "https://s5vdi3ie.lc-cn-n1-shared.com",
//        serverURL: "https://beta.leancloud.cn",
        masterKey: "Q26gTodbyi1Ki7lM9vtncF6U,master")
    
    static let ceApp = AppInfo(
        id: "skhiVsqIk7NLVdtHaUiWn0No-9Nh9j0Va",
        key: "T3TEAIcL8Ls5XGPsGz41B1bz",
        serverURL: "https://skhivsqi.lc-cn-e1-shared.com",
        masterKey: "FTPdEcG7vLKxNqKxYhTFdK4g,master")
    
    static let usApp = AppInfo(
        id: "jenSt9nvWtuJtmurdE28eg5M-MdYXbMMI",
        key: "8VLPsDlskJi8KsKppED4xKS0",
        serverURL: "",
        masterKey: "fasiJXz8jvSwn3G2B2QeraRe,master")
    
    static let appInfoTable = [
        cnApp.id : cnApp,
        ceApp.id : ceApp,
        usApp.id : usApp,
    ]
    
    override class func setUp() {
        super.setUp()
        let app = BaseTestCase.cnApp
        LCApplication.setAllLogsEnabled(true)
        if app.serverURL.isEmpty {
            LCApplication.setApplicationId(app.id, clientKey: app.key)
        } else {
            LCApplication.setApplicationId(app.id, clientKey: app.key, serverURLString: app.serverURL)
        }
    }
    
    override class func tearDown() {
        LCFile.clearAllPersistentCache()
        super.tearDown()
    }
    
    override func setUp() {
        super.setUp()
        LCUser.logOut()
    }
    
    override func tearDown() {
        LCUser.logOut()
        super.tearDown()
    }
}

extension BaseTestCase {
    
    func expecting(
        description: String? = nil,
        count expectedFulfillmentCount: Int = 1,
        timeout: TimeInterval = BaseTestCase.timeout,
        testcase: (XCTestExpectation) -> Void)
    {
        let exp = self.expectation(description: description ?? "default expectation")
        exp.expectedFulfillmentCount = expectedFulfillmentCount
        self.expecting(
            timeout: timeout,
            expectation: { exp },
            testcase: testcase)
    }
    
    func expecting(
        timeout: TimeInterval = BaseTestCase.timeout,
        expectation: () -> XCTestExpectation,
        testcase: (XCTestExpectation) -> Void)
    {
        self.multiExpecting(
            timeout: timeout,
            expectations: { [expectation()] },
            testcase: { testcase($0[0]) })
    }
    
    func multiExpecting(
        timeout: TimeInterval = BaseTestCase.timeout,
        expectations: (() -> [XCTestExpectation]),
        testcase: ([XCTestExpectation]) -> Void)
    {
        let exps = expectations()
        testcase(exps)
        wait(for: exps, timeout: timeout)
    }
    
    func delay(seconds: TimeInterval = 3.0) {
        print("\n------\nwait \(seconds) seconds.\n------\n")
        let exp = expectation(description: "delay \(seconds) seconds.")
        exp.isInverted = true
        wait(for: [exp], timeout: seconds)
    }
}

extension BaseTestCase {
    
    func useMasterKey(_ application: LCApplication = .default()) {
        guard let appInfo = BaseTestCase.appInfoTable[application.identifier],
              !appInfo.masterKey.isEmpty else {
            return
        }
        application.setWithIdentifier(appInfo.id, key: appInfo.masterKey)
    }
    
    func useCommonKey(_ application: LCApplication = .default()) {
        guard let appInfo = BaseTestCase.appInfoTable[application.identifier],
              !appInfo.masterKey.isEmpty else {
            return
        }
        application.setWithIdentifier(appInfo.id, key: appInfo.key)
    }
}



enum LCTestError: String, Error {

    case valueNotExist
    case typeNotMatch
}

extension LCTestError: LocalizedError {
    var errorDescription: String? {
        return self.rawValue
    }
}

extension BaseTestCase {
    
    static func valueIsEqual<T: Equatable> (first: T, second: T) -> Bool {
        return first == second
    }
    
    static func getValue<T>(from object: LCObject, key field: String) throws -> T {
        let value = object.object(forKey: field)
        guard let value = value else {
            throw LCTestError.valueNotExist
        }
        
        guard let value = value as? T else {
            throw LCTestError.typeNotMatch
        }
        return value
    }
    
    static func verifyLCObjectValues(object: LCObject, needVerifyFields: [TestField: Any]) {
        // 这里类型一致需要开发者自己控制，如果不一致不要调用该方法，自己手动校验
        for (field, value) in needVerifyFields {
            switch field {
            case .integer:
                verifyLCObjectFieldValue(object: object, fieldName: field.rawValue, value: value as! Int)
            case .double:
                verifyLCObjectFieldValue(object: object, fieldName: field.rawValue, value: value as! Double)
            case .boolean:
                verifyLCObjectFieldValue(object: object, fieldName: field.rawValue, value: value as! Bool)
            case .string:
                verifyLCObjectFieldValue(object: object, fieldName: field.rawValue, value: value as! String)
            case .array:
                verifyLCObjectFieldValue(object: object, fieldName: field.rawValue, value: value as! NSArray)
            case .dict:
                verifyLCObjectFieldValue(object: object, fieldName: field.rawValue, value: value as! NSDictionary)
            case .date:
                if let verifyValue = value as? Date,
                   let realValue: Date = try? getValue(from: object, key: field.rawValue) {
                    let interval = verifyValue.timeIntervalSince(realValue)
                    XCTAssert(fabs(interval) < 0.01, "字段\(field.rawValue)发生错误，需要校验的值为：\(verifyValue)，实际值却是：\(realValue)")
                } else {
                    XCTFail("字段\(field.rawValue)类型错误")
                }
            case .data:
                verifyLCObjectFieldValue(object: object, fieldName: field.rawValue, value: value as! Data)
            case .object:
                verifyLCObjectFieldValue(object: object, fieldName: field.rawValue, value: value as! LCObject)
            case .point:
                verifyLCObjectFieldValue(object: object, fieldName: field.rawValue, value: value as! LCGeoPoint)
            }
        
        }
    }
    
    
    static func verifyLCObjectValues(objectID: String, needVerifyFields: [TestField: Any], className: String = LCObjectTestCase.className) {
        let object = LCObject.init(className: className, objectId: objectID)
        XCTAssert(object.fetch())
        verifyLCObjectValues(object: object, needVerifyFields: needVerifyFields)
    }
    
    static func verifyLCObjectFieldValue<T :Equatable>(object: LCObject, fieldName: String, value: T) {
        
        do {
            let realValue: T = try getValue(from: object, key: fieldName)
            XCTAssert(value == realValue, "字段\(fieldName)发生错误，需要校验的值为：\(value)，实际值却是：\(realValue)")
        } catch  {
            XCTFail("字段\(fieldName)发生错误: " + error.localizedDescription)
        }
    }
    
    static func createLCObject(fields: [TestField: Any], save: Bool = true, className: String = LCObjectTestCase.className) -> LCObject {
        let object = LCObject.init(className: className)
        object.set(fields: fields)
        if save {
            XCTAssert(object.save())
            XCTAssertNotNil(object.objectId)
        }
        return object
    }
    
//    @inline(__always)
//    func setLCObjectFieldValues(object: LCObject, fields: [TestField: Any]){
//        for (field, value) in fields {
//            object.setObject(value, forKey: field.rawValue)
//        }
//    }
    
    static func updateLCObject(objectID: String, className: String = LCObjectTestCase.className, updateAction: ((LCObject) -> ())) {
        let object = LCObject.init(className: className, objectId: objectID)
        updateAction(object)
        XCTAssert(object.save())
    }
    
    
}

extension BaseTestCase {
    func getDistance(point1: LCGeoPoint, point2: LCGeoPoint) -> Double {
        let EARTH_RADIUS = 6378137.0
        
        let radLat1 = point1.latitude * Double.pi / 180.0
        let radLat2 = point2.latitude * Double.pi / 180.0
        let radLng1 = point1.longitude * Double.pi / 180.0
        let radLng2 = point2.longitude * Double.pi / 180.0
        
        let a = radLat1 - radLat2
        let b = radLng1 - radLng2
        
        var s: Double = 2 * asin(sqrt(pow(sin(a/2), 2) + cos(radLat1) * cos(radLat2) * pow(sin(b/2), 2)))
        s = s * EARTH_RADIUS
        return s
    }
}

extension LCObject {
    func set(fields: [BaseTestCase.TestField: Any]) {
        for (field, value) in fields {
            setObject(value, forKey: field.rawValue)
        }
    }
}

