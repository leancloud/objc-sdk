//
//  LCUserTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2020/07/13.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

class LCUserTestCase: BaseTestCase {
    
    static let testablePhoneNumber = "+8618622223333"
    static let testableSMSCode = "170402"
    
    func testVerifyPhoneNumberBySMSCode() {
        /*
        let user = AVUser()
        let username = uuid
        let password = uuid
        let phoneNumber = LCUserTestCase.testablePhoneNumber
        user.username = username
        user.password = password
        user.mobilePhoneNumber = phoneNumber
        XCTAssertTrue(user.signUp(nil))
        expecting { (exp) in
            AVUser.logInWithUsername(
                inBackground: username,
                password: password)
            { (user, error) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(user)
                XCTAssertNil(error)
                XCTAssertTrue(user === AVUser.current())
                exp.fulfill()
            }
        }
        expecting { (exp) in
            AVUser.requestVerificationCode(
                forPhoneNumber: phoneNumber,
                options: nil)
            { (succeeded, error) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        expecting { (exp) in
            AVUser.verifyCode(
                forPhoneNumber: phoneNumber,
                code: LCUserTestCase.testableSMSCode)
            { (succeeded, error) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        AVUser.logOut()
         */
    }
    
    func testUpdatePhoneNumberBySMSCode() {
        /*
        let user = AVUser()
        let username = uuid
        let password = uuid
        let phoneNumber = LCUserTestCase.testablePhoneNumber
        user.username = username
        user.password = password
        user.mobilePhoneNumber = phoneNumber
        XCTAssertTrue(user.signUp(nil))
        expecting { (exp) in
            AVUser.logInWithUsername(
                inBackground: username,
                password: password)
            { (user, error) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(user)
                XCTAssertNil(error)
                XCTAssertTrue(user === AVUser.current())
                exp.fulfill()
            }
        }
        expecting { (exp) in
            AVUser.requestVerificationCode(
                forUpdatingPhoneNumber: phoneNumber,
                options: nil)
            { (succeeded, error) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        expecting { (exp) in
            AVUser.verifyCode(
                toUpdatePhoneNumber: phoneNumber,
                code: LCUserTestCase.testableSMSCode)
            { (succeeded, error) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        AVUser.logOut()
        */
    }
}
