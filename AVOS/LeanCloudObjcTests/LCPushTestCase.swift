//
//  LCPushTestCase.swift
//  LeanCloudObjcTests
//
//  Created by 黄驿峰 on 2021/12/8.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

// MARK: Test case initialization
extension LCPushTestCase {
    
//    static let QueryName = "LiveQueryObject"
//    static var queryObject: LCObject!
//
    override class func setUp() {
        super.setUp()
        let data = uuid.data(using: .utf8)!
        LCInstallation.default().setDeviceTokenFrom(data, teamId: "teamID")
        XCTAssertTrue(LCInstallation.default().save())
        LCInstallation.default().save();
        LCPush.setProductionMode(false)
    }
    
//    static func deleteAllObjects() {
//        let query = LCQuery.init(className: QueryName)
//        let objects = query.findObjects()
//        guard let objects = objects as? [LCObject] else {
//            return
//        }
//        XCTAssert(LCObject.deleteAll(objects))
//    }
//
//    static func generateTestObjects() {
//        queryObject = createLCObject(fields: [
//            .integer: 1,
//            .string: "123",
//            .array: [7, 8, 9, 10]
//        ], save: true, className: QueryName)
//
//
//    }
    
    
}


class LCPushTestCase: BaseTestCase {
    
    let channelName = "Giants"
    
    func testSubscription() {
        let currentInstallation = LCInstallation.default()
        currentInstallation.addUniqueObject(channelName, forKey: "channels")
        expecting { exp in
            currentInstallation.saveInBackground { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testUnsubscribe() {
        let currentInstallation = LCInstallation.default()
        currentInstallation.remove(channelName, forKey: "channels")
        expecting { exp in
            currentInstallation.saveInBackground { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testPushMsgToChannel() {
        let push = LCPush.init()
        push.setChannel(channelName)
        push.setMessage("666")
        expecting { exp in
            push.sendInBackground { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testPushConditionMsgToChannels() {
        let query = LCInstallation.query()
        query.whereKeyExists("hehe")
        let push = LCPush.init()
        push.setChannels([channelName, "other"])
        push.setQuery(query)
        push.setMessage("666")
        expecting { exp in
            push.sendInBackground { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testPushDictToChannel() {
        let push = LCPush.init()
        push.setChannel(channelName)
        push.setData([
            "alert": "The Mets scored! The game is now tied 1-1!",
            "badge": "Increment",
            "sound": "cheering.caf",
            "newsItem": "Man bites dog",
            "name": "Vaughn",
        ])
        expecting { exp in
            push.sendInBackground { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testPushMsgWithExpireAfterTime() {
        let push = LCPush.init()
        push.setChannel(channelName)
        push.setMessage("666")
        push.expire(at: Date.init(timeIntervalSinceNow: 10))
        expecting { exp in
            push.sendInBackground { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testPushMsgWithDate() {
        let push = LCPush.init()
        push.setChannel(channelName)
        push.setMessage("666")
        push.setPush(Date.init(timeIntervalSinceNow: 5))
        push.expire(afterTimeInterval: 10)
        expecting { exp in
            push.sendInBackground { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testClearBadge() {
        LCInstallation.default().badge = 0
        expecting { exp in
            LCInstallation.default().saveInBackground { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
}
