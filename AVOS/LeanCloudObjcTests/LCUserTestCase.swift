//
//  LCUserTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2020/07/13.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc
import AVFoundation

class LCUserTestCase: BaseTestCase {
    
    static let testablePhoneNumber = "+8618622223333"
    static let testableSMSCode = "170402"
    
    func testResetPasswordWithSmsCode() {
        expecting() { exp in
            LCUser.resetPassword(
                withSmsCode: LCUserTestCase.testableSMSCode,
                newPassword: "22223333",
                phoneNumber: LCUserTestCase.testablePhoneNumber)
            { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testSignUpAndLoginAndOther() {
        
        let username = uuid
        let password = uuid
        let email = uuid + "@163.com"
        
        let user = LCUser()
        user.username = username
        user.password = password
        user.email = email
        
        expecting { exp in
            user.signUpInBackground { result, error in
                XCTAssertNil(error)
                XCTAssertTrue(result)
                exp.fulfill()
            }
        }
        XCTAssertNotNil(LCUser.current())
        LCUser.logOut()
        XCTAssertNil(LCUser.current())
        
        expecting { exp in
            LCUser.logInWithUsername(inBackground: username, password: password) { user, error in
                XCTAssertNil(error)
                XCTAssertTrue(user === LCUser.current())
                exp.fulfill()
            }
        }
        
        XCTAssertNotNil(LCUser.current())
        LCUser.logOut()
        XCTAssertNil(LCUser.current())
        
        expecting { exp in
            LCUser.logInWithMobilePhoneNumber(inBackground: LCUserTestCase.testablePhoneNumber, smsCode: LCUserTestCase.testableSMSCode) { user, error in
                XCTAssertNil(error)
                XCTAssertTrue(user === LCUser.current())
                exp.fulfill()
            }
        }
        
        XCTAssertNotNil(LCUser.current())
        LCUser.logOut()
        XCTAssertNil(LCUser.current())
        
        expecting { exp in
            LCUser.login(withEmail: email, password: password) { user, error in
                XCTAssertNil(error)
                XCTAssertTrue(user === LCUser.current())
                exp.fulfill()
            }
        }
        
        XCTAssertNotNil(LCUser.current())
        let current = LCUser.current()!;
        XCTAssertNotNil(current.sessionToken)
        
        expecting { exp in
            current.isAuthenticated(withSessionToken: current.sessionToken!) { ret, error in
                XCTAssertNil(error)
                XCTAssertTrue(ret)
                exp.fulfill()
            }
        }
        
    }
    
    
    //    func testVerifyPhoneNumberBySMSCode() {
    //        let user = LCUser()
    //        let username = uuid
    //        let password = uuid
    //        let phoneNumber = LCUserTestCase.testablePhoneNumber
    //        user.username = username
    //        user.password = password
    //        user.mobilePhoneNumber = phoneNumber
    //        do {
    //            try user.signUp()
    //        } catch  {
    //            XCTFail()
    //        }
    //        expecting { (exp) in
    //            LCUser.logInWithUsername(
    //                inBackground: username,
    //                password: password)
    //            { (user, error) in
    //                XCTAssertTrue(Thread.isMainThread)
    //                XCTAssertNotNil(user)
    //                XCTAssertNil(error)
    //                XCTAssertTrue(user === LCUser.current())
    //                exp.fulfill()
    //            }
    //        }
    //        expecting { (exp) in
    //            LCUser.requestVerificationCode(
    //                forPhoneNumber: phoneNumber,
    //                options: nil)
    //            { (succeeded, error) in
    //                XCTAssertTrue(Thread.isMainThread)
    //                XCTAssertTrue(succeeded)
    //                XCTAssertNil(error)
    //                exp.fulfill()
    //            }
    //        }
    //        expecting { (exp) in
    //            LCUser.verifyCode(
    //                forPhoneNumber: phoneNumber,
    //                code: LCUserTestCase.testableSMSCode)
    //            { (succeeded, error) in
    //                XCTAssertTrue(Thread.isMainThread)
    //                XCTAssertTrue(succeeded)
    //                XCTAssertNil(error)
    //                exp.fulfill()
    //            }
    //        }
    //    }
    
    //    func testUpdatePhoneNumberBySMSCode() {
    //        let user = LCUser()
    //        let username = uuid
    //        let password = uuid
    //        let phoneNumber = LCUserTestCase.testablePhoneNumber
    //        user.username = username
    //        user.password = password
    //        user.mobilePhoneNumber = phoneNumber
    //        do {
    //            try user.signUp()
    //        } catch  {
    //            XCTFail()
    //        }
    //
    //        expecting { (exp) in
    //            LCUser.logInWithUsername(
    //                inBackground: username,
    //                password: password)
    //            { (user, error) in
    //                XCTAssertTrue(Thread.isMainThread)
    //                XCTAssertNotNil(user)
    //                XCTAssertNil(error)
    //                XCTAssertTrue(user === LCUser.current())
    //                exp.fulfill()
    //            }
    //        }
    //        expecting { (exp) in
    //            LCUser.requestVerificationCode(
    //                forUpdatingPhoneNumber: phoneNumber,
    //                options: nil)
    //            { (succeeded, error) in
    //                XCTAssertTrue(Thread.isMainThread)
    //                XCTAssertTrue(succeeded)
    //                XCTAssertNil(error)
    //                exp.fulfill()
    //            }
    //        }
    //        expecting { (exp) in
    //            LCUser.verifyCode(
    //                toUpdatePhoneNumber: phoneNumber,
    //                code: LCUserTestCase.testableSMSCode)
    //            { (succeeded, error) in
    //                XCTAssertTrue(Thread.isMainThread)
    //                XCTAssertTrue(succeeded)
    //                XCTAssertNil(error)
    //                exp.fulfill()
    //            }
    //        }
    //    }
    
    
    func testLogOut() {
        var uid1: String?
        expecting { exp in
            LCUser.loginAnonymously { user, error in
                uid1 = user?.objectId
                XCTAssertNotNil(uid1)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        LCUser.logOut(withClearingAnonymousId: false)
        
        expecting { exp in
            LCUser.loginAnonymously { user, error in
                XCTAssertEqual(uid1, user?.objectId)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        LCUser.logOut()
        
        expecting { exp in
            LCUser.loginAnonymously { user, error in
                XCTAssertNotNil(user?.objectId)
                XCTAssertNotEqual(uid1, user?.objectId)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testFriendshipRequestAccept() {
        let user_1 = LCUser()
        expecting { exp in
            user_1.login(withAuthData: ["openid": uuid], platformId: "test", options: nil) { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        guard
            let _ = user_1.objectId,
            LCUser.current() === user_1
        else {
            XCTFail()
            return
        }
        
        LCUser.logOut()
        
        let user_2 = LCUser()
        expecting { exp in
            user_2.login(withAuthData: ["openid": uuid], platformId: "test", options: nil) { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        guard
            let _ = user_2.objectId,
            LCUser.current() === user_2
        else {
            XCTFail()
            return
        }
        
        expecting { exp in
            LCFriendship.request(withUserId: user_1.objectId!, attributes: ["group": "sport"]) { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        LCUser.changeCurrentUser(user_1, save: false)
        var query: LCQuery!
        
        expecting(description: "Accept Friendship Request", count: 2) { exp in
            query = LCFriendshipRequest.query()
            query.findObjectsInBackground { requests, error in
                let request = requests?.first as? LCFriendshipRequest
                let friend = request?["friend"] as? LCUser
                let user = request?["user"] as? LCUser
                XCTAssertNotNil(request)
                XCTAssertNotNil(friend)
                XCTAssertNotNil(user)
                XCTAssertNil(error)
                exp.fulfill()
                if let request = request {
                    LCFriendship.accept(request, attributes: ["group": "music"]) { succeeded, error in
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                        exp.fulfill()
                    }
                }
            }
        }
        
        expecting { exp in
            query = user_1.followeeObjectsQuery()
            query.whereKey("friendStatus", equalTo: true)
            query.findObjectsInBackground { followees, error in
                let followee = followees?.first as? LCObject
                XCTAssertNotNil(followee)
                XCTAssertEqual(followee?["group"] as? String, "music")
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        LCUser.changeCurrentUser(user_2, save: false)
        
        expecting(count: 3) { exp in
            query = user_2.followeeObjectsQuery()
            query.whereKey("friendStatus", equalTo: true)
            query.findObjectsInBackground { followees, error in
                let followee = followees?.first as? LCObject
                XCTAssertNotNil(followee)
                XCTAssertEqual(followee?["group"] as? String, "sport")
                XCTAssertNil(error)
                exp.fulfill()
                if let followee = followee {
                    followee["group"] = "music"
                    followee.saveInBackground { succeeded, error in
                        XCTAssertNil(error)
                        exp.fulfill()
                        if succeeded {
                            user_2.unfollow(user_1.objectId!) { succeeded, error in
                                XCTAssertTrue(succeeded)
                                XCTAssertNil(error)
                                exp.fulfill()
                            }
                        }
                    }
                }
            }
        }
    }
    
    func testFriendshipRequestDecline() {
        let user_1 = LCUser()
        expecting { exp in
            user_1.login(withAuthData: ["openid": uuid], platformId: "test", options: nil) { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        guard
            let _ = user_1.objectId,
            LCUser.current() === user_1
        else {
            XCTFail()
            return
        }
        
        LCUser.logOut()
        
        let user_2 = LCUser()
        expecting { exp in
            user_2.login(withAuthData: ["openid": uuid], platformId: "test", options: nil) { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        guard
            let _ = user_2.objectId,
            LCUser.current() === user_2
        else {
            XCTFail()
            return
        }
        
        expecting { exp in
            LCFriendship.request(withUserId: user_1.objectId!, attributes: ["group": "sport"]) { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        LCUser.changeCurrentUser(user_1, save: false)
        var query: LCQuery!
        
        expecting(description: "Decline Friendship Request", count: 2) { exp in
            query = LCFriendshipRequest.query()
            query.findObjectsInBackground { requests, error in
                let request = requests?.first as? LCFriendshipRequest
                let friend = request?["friend"] as? LCUser
                let user = request?["user"] as? LCUser
                XCTAssertNotNil(request)
                XCTAssertNotNil(friend)
                XCTAssertNotNil(user)
                XCTAssertNil(error)
                exp.fulfill()
                if let request = request {
                    LCFriendship.declineRequest(request) { succeeded, error in
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                        exp.fulfill()
                    }
                }
            }
        }
        
        expecting(description: "Delete Friendship Request", count: 2) { exp in
            query = LCFriendshipRequest.query()
            query.whereKey("status", equalTo: "declined")
            query.findObjectsInBackground { requests, error in
                let request = requests?.first as? LCFriendshipRequest
                let friend = request?["friend"] as? LCUser
                let user = request?["user"] as? LCUser
                XCTAssertNotNil(request)
                XCTAssertNotNil(friend)
                XCTAssertNotNil(user)
                XCTAssertNil(error)
                exp.fulfill()
                request?.deleteInBackground({ succeeded, error in
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    exp.fulfill()
                })
            }
        }
    }
    
    func testFriendshipBlockAndUnblockAndQuery() {
        let user_1 = LCUser()
        expecting { exp in
            user_1.login(withAuthData: ["openid": uuid], platformId: "test", options: nil) { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        guard
            let _ = user_1.objectId,
            LCUser.current() === user_1
        else {
            XCTFail()
            return
        }
        
        LCUser.logOut()
        
        let user_2 = LCUser()
        expecting { exp in
            user_2.login(withAuthData: ["openid": uuid], platformId: "test", options: nil) { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        guard
            let _ = user_2.objectId,
            LCUser.current() === user_2
        else {
            XCTFail()
            return
        }
        
        expecting { exp in
            LCFriendship.request(withUserId: user_1.objectId!, attributes: ["group": "sport"]) { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        LCUser.changeCurrentUser(user_1, save: false)
        
        var query: LCQuery!
        expecting(description: "Accept Friendship Request", count: 2) { exp in
            query = LCFriendshipRequest.query()
            query.findObjectsInBackground { requests, error in
                let request = requests?.first as? LCFriendshipRequest
                let friend = request?["friend"] as? LCUser
                let user = request?["user"] as? LCUser
                XCTAssertNotNil(request)
                XCTAssertNotNil(friend)
                XCTAssertNotNil(user)
                XCTAssertNil(error)
                exp.fulfill()
                if let request = request {
                    LCFriendship.accept(request, attributes: ["group": "music"]) { succeeded, error in
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                        exp.fulfill()
                    }
                }
            }
        }
        
        expecting { exp in
            query = user_1.friendshipQuery()
            query.includeKey("followee")
            query.findObjectsInBackground { followees, error in
                let first = followees?.first as? LCObject
                let followee = first?["followee"] as? LCObject
                XCTAssertNotNil(followee)
                XCTAssertNotNil(followee?["username"] as? String)
                XCTAssertEqual(first?["group"] as? String, "music")
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            LCFriendship.blockFriend(withUserId: user_2.objectId!) { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            query = user_1.friendshipBlockQuery()
            query.includeKey("blockedUser")
            query.findObjectsInBackground { blockedUsers, error in
                let first = blockedUsers?.first as? LCObject
                let blockedUser = first?["blockedUser"] as? LCObject
                XCTAssertNotNil(blockedUser)
                XCTAssertNotNil(blockedUser?["username"] as? String)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            LCFriendship.unblockFriend(withUserId: user_2.objectId!) { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testStrictlyFind() {
        expecting { exp in
            LCUser.loginAnonymously { user, error in
                XCTAssertNotNil(user)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        guard let user = LCUser.current() else {
            XCTFail()
            return
        }
        let hiddenField = "hiddenField"
        let exposedField = "exposedField"
        user[hiddenField] = uuid
        user[exposedField] = uuid
        XCTAssertTrue(user.save())
        
        expecting { exp in
            let query = LCQuery()
            query.whereKey(hiddenField, equalTo: user[hiddenField] ?? "")
            LCUser.strictlyFind(with: query) { users, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(users)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            let query = LCQuery()
            query.whereKey(exposedField, equalTo: user[exposedField] ?? "")
            LCUser.strictlyFind(with: query) { users, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(users?.count, 1)
                XCTAssertEqual(users?.first?.objectId, user.objectId)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testUpdateAuthData() {
        let user = LCUser()
        let accessTokenKey = "access_token"
        let platform1 = "platform1";
        let openid1 = UUID().uuidString
        let authData1: [String: String] = [
            accessTokenKey : UUID().uuidString,
            "openid": openid1
        ]
        expecting { exp in
            user.login(withAuthData: authData1, platformId: platform1, options: nil) { succeeded, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        let getUserAuthData = { (platform: String, key: String) -> Any? in
            let authData = user["authData"] as? [String : Any]
            let platformAuthData = authData?[platform] as? [String : Any]
            return platformAuthData?[key]
        }
        XCTAssertEqual(getUserAuthData(platform1, accessTokenKey) as? String, authData1[accessTokenKey])
        
        let authData1_1: [String: String] = [
            accessTokenKey : UUID().uuidString,
            "openid": openid1
        ]
        let platform2 = "platform2";
        let openid2 = UUID().uuidString
        let authData2: [String: String] = [
            accessTokenKey : UUID().uuidString,
            "openid": openid2
        ]
        user["authData.\(platform1)"] = authData1_1
        user["authData.\(platform2)"] = authData2
        let saveOption = LCSaveOption()
        saveOption.fetchWhenSave = true
        try! user.save(with: saveOption)
        XCTAssertEqual(getUserAuthData(platform1, accessTokenKey) as? String, authData1_1[accessTokenKey])
        XCTAssertEqual(getUserAuthData(platform2, accessTokenKey) as? String, authData2[accessTokenKey])
        XCTAssertEqual((user["authData"] as? [String : Any])?.count, 2)
        
        let openid1_1 = UUID().uuidString
        let authData1_2: [String: String] = [
            accessTokenKey : UUID().uuidString,
            "openid": openid1_1
        ]
        let openid2_1 = UUID().uuidString
        let authData2_1: [String: String] = [
            accessTokenKey : UUID().uuidString,
            "openid": openid2_1
        ]
        user["authData.\(platform1)"] = authData1_2
        user["authData.\(platform2)"] = authData2_1
        try! user.save(with: saveOption)
        XCTAssertEqual(getUserAuthData(platform1, accessTokenKey) as? String, authData1_2[accessTokenKey])
        XCTAssertEqual(getUserAuthData(platform2, accessTokenKey) as? String, authData2_1[accessTokenKey])
        XCTAssertEqual(getUserAuthData(platform1, "openid") as? String, authData1_2["openid"])
        XCTAssertEqual(getUserAuthData(platform2, "openid") as? String, authData2_1["openid"])
        XCTAssertEqual((user["authData"] as? [String : Any])?.count, 2)
    }
}
