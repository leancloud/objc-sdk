//
//  AVUser_TestCase.swift
//  AVOS
//
//  Created by ZapCannon87 on 11/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVUser_TestCase: LCTestBase {
    
    func testc_mobile_signup_password() {
        
        if self.isServerTesting { return }
        
        /// `mobileNumber` & `smsCode` defined in dashboard
        let mobileNumber: String = "18677777777"
        let smsCode: String = "375586"
        let password: String = "12345678"
        
        var aUser: AVUser! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            AVUser.signUpOrLoginWithMobilePhoneNumber(inBackground: mobileNumber, smsCode: smsCode, password: password, block: { (user: AVUser?, error:Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(user)
                XCTAssertNil(error)
                XCTAssertNotNil(user?.objectId)
                aUser = user
            })
        }, failure: { XCTFail("timeout") })
        
        if aUser != nil {
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                AVUser.logInWithMobilePhoneNumber(inBackground: mobileNumber, password: password) { (user: AVUser?, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertNotNil(user)
                    XCTAssertNil(error)
                    XCTAssertEqual(user?.objectId, aUser.objectId)
                }
            }, failure: { XCTFail("timeout") })
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                aUser.deleteInBackground { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                }
            }, failure: { XCTFail("timeout") })
        }
    }
    
    // MARK: - Auth Data
    
    func testc_auth_data_login_associate_disassociate() {
        
        if self.isServerTesting { return }
        
        var user: AVUser! = AVUser.init()
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            
            let testTag: String = "_1"
            
            let authData: [String : Any] = [
                "access_token" : "access_token_test" + testTag,
                "openid" : "\(#function[..<#function.index(of: "(")!])" + testTag
            ]
            let platformId: String = LeanCloudSocialPlatform.weiXin.rawValue + testTag
            
            let options: AVUserAuthDataLoginOption = AVUserAuthDataLoginOption()
            options.platform = LeanCloudSocialPlatform.weiXin
            
            semaphore.increment()
            
            user.login(withAuthData: authData, platformId: platformId, options: options, callback: { (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                
                XCTAssertNotNil(user.objectId)
                let userAuthData: [String : Any]? = user["authData"] as? [String : Any]
                XCTAssertNotNil(userAuthData)
                XCTAssertNotNil(userAuthData?[platformId])
                
                if !succeeded {
                    user = nil
                }
            })
            
        }, failure: {
            user = nil
            XCTFail("timeout")
        })
        
        if let _ = user {
            
            let testTag: String = "_2"
            let platformId: String = LeanCloudSocialPlatform.weiXin.rawValue + testTag
            
            let authData: [String : Any] = [
                "access_token" : "access_token_test" + testTag,
                "openid" : "\(#function[..<#function.index(of: "(")!])" + testTag
            ]
            
            let options: AVUserAuthDataLoginOption = AVUserAuthDataLoginOption()
            options.platform = LeanCloudSocialPlatform.weiXin
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                user.associate(withAuthData: authData, platformId: platformId, options: options, callback: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    
                    let userAuthData: [String : Any]? = user["authData"] as? [String : Any]
                    XCTAssertNotNil(userAuthData)
                    XCTAssertNotNil(userAuthData?[platformId])
                    
                    if !succeeded {
                        user = nil
                    }
                })
                
            }, failure: {
                user = nil
                XCTFail("timeout")
            })
            
            if let _ = user {
                
                RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                    
                    semaphore.increment()
                    
                    user.disassociate(withPlatformId: platformId, callback: { (succeeded: Bool, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                        
                        let userAuthData: [String : Any]? = user["authData"] as? [String : Any]
                        XCTAssertNotNil(userAuthData)
                        XCTAssertNil(userAuthData?[platformId])
                        
                    })
                    
                }, failure: {
                    
                    XCTFail("timeout")
                })
            }
        }
    }
    
    func testc_auth_data_union_id() {
        
        if self.isServerTesting { return }
        
        let unionId: String = "\(#function[..<#function.index(of: "(")!])"
        var user_1: AVUser! = AVUser()
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            
            let testTag: String = "_1"
            let platformId: String = LeanCloudSocialPlatform.weiXin.rawValue + testTag
            
            let authData: [String : Any] = [
                "access_token" : "access_token_test" + testTag,
                "openid" : "\(#function[..<#function.index(of: "(")!])" + testTag
            ]
            
            let options: AVUserAuthDataLoginOption = AVUserAuthDataLoginOption()
            options.platform = LeanCloudSocialPlatform.weiXin
            options.unionId = unionId
            options.isMainAccount = true
            
            semaphore.increment()
            
            user_1.login(withAuthData: authData, platformId: platformId, options: options, callback: { (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)

                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                
                XCTAssertNotNil(user_1.objectId)
                let userAuthData: [String : Any]? = user_1["authData"] as? [String : Any]
                XCTAssertNotNil(userAuthData)
                XCTAssertNotNil(userAuthData?[platformId])
                
                if !succeeded {
                    user_1 = nil
                }
            })
            
        }, failure: {
            user_1 = nil
            XCTFail("timeout")
        })
        
        if let _ = user_1 {
            
            var user_2: AVUser! = AVUser()
            let testTag: String = "_2"
            let platformId: String = LeanCloudSocialPlatform.weiXin.rawValue + testTag
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
                let authData: [String : Any] = [
                    "access_token" : "access_token_test" + testTag,
                    "openid" : "\(#function[..<#function.index(of: "(")!])" + testTag
                ]
                
                let options: AVUserAuthDataLoginOption = AVUserAuthDataLoginOption()
                options.platform = LeanCloudSocialPlatform.weiXin
                options.unionId = unionId
                options.isMainAccount = true
                
                semaphore.increment()
                
                user_2.login(withAuthData: authData, platformId: platformId, options: options, callback: { (succeeded, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    
                    XCTAssertEqual(user_2.objectId, user_1.objectId)
                    let userAuthData: [String : Any]? = user_2["authData"] as? [String : Any]
                    XCTAssertNotNil(userAuthData)
                    XCTAssertNotNil(userAuthData?[platformId])
                    
                    if !succeeded {
                        user_2 = nil
                    }
                })
                
            }, failure: {
                user_2 = nil
                XCTFail("timeout")
            })
            
            if let _ = user_2 {
                
                RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                    
                    semaphore.increment()
                    
                    user_2.disassociate(withPlatformId: platformId, callback: { (succeeded: Bool, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                    })
                    
                }, failure: {
                    
                    XCTFail("timeout")
                })
            }
        }
    }
    
    func testc_auth_data_fail_on_not_exist() {
        
        if self.isServerTesting { return }
        
        var deletingUser: AVUser?
        
        var user: AVUser! = AVUser()
        let authData: [String : Any] = [
            "access_token" : "access_token_test",
            "openid" : "\(#function[..<#function.index(of: "(")!])"
        ]
        let platformId: String = LeanCloudSocialPlatform.weiXin.rawValue
        
        let options: AVUserAuthDataLoginOption = AVUserAuthDataLoginOption()
        options.platform = LeanCloudSocialPlatform.weiXin
        options.failOnNotExist = true
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            user.login(withAuthData: authData, platformId: platformId, options: options, callback: { (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
            
                XCTAssertFalse(succeeded)
                XCTAssertNotNil(error)
                let responseError: [AnyHashable : Any]? = (error as NSError?)?.userInfo[kLeanCloudRESTAPIResponseError] as? [AnyHashable : Any]
                let code: Int? = responseError?["code"] as? Int
                XCTAssertNotNil(responseError)
                XCTAssertEqual(code, 211)
                
                if succeeded, let _ = user.objectId {
                    deletingUser = user
                    user = nil
                }
                
                if code == nil || code != 211 {
                    user = nil
                }
            })
            
        }, failure: {
            user = nil
            XCTFail("timeout")
        })
        
        if let _ = user {
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
                user.mobilePhoneNumber = {
                    let letters : NSString = "0123456789"
                    let len = UInt32(letters.length)
                    var randomString = ""
                    for _ in 0..<8 {
                        let rand = arc4random_uniform(len)
                        var nextChar = letters.character(at: Int(rand))
                        randomString += NSString(characters: &nextChar, length: 1) as String
                    }
                    return "186" + randomString
                }()
                options.failOnNotExist = false
                
                semaphore.increment()
                
                user.login(withAuthData: authData, platformId: platformId, options: options, callback: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    
                    if succeeded, let _ = user.objectId {
                        deletingUser = user
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        if let _deletingUser: AVUser = deletingUser {
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                _deletingUser.deleteInBackground({ (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
    // MARK: - Anonymous
    
    func testc_login_anonymous() {
        
        if self.isServerTesting { return }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            AVUser.loginAnonymously(callback: { (user: AVUser?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(user)
                XCTAssertNil(error)
                if let user = user { XCTAssertTrue(user.isAnonymous()) }
            })
        }, failure: { XCTFail("timeout") })
    }
    
    // MARK: - Error
    
    func testc_username_taken() {
        
        if self.isServerTesting { return }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            
            let username: String = "\(#function[..<#function.index(of: "(")!])"
            let password: String = "123"
            let user: AVUser = AVUser()
            user.username = username
            user.password = password
                
            semaphore.increment(2)
            
            user.signUpInBackground({ (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                if succeeded {
                    
                    let newUser: AVUser = AVUser()
                    newUser.username = username
                    newUser.password = password
                    
                    newUser.signUpInBackground({ (succeeded: Bool, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertFalse(succeeded)
                        XCTAssertNotNil(error)
                        let _error: NSError? = error as NSError?
                        XCTAssertEqual(_error?.code, 202)
                        XCTAssertEqual(_error?.domain, kLeanCloudErrorDomain)
                        /* for compatibility */
                        XCTAssertNotNil(_error?.userInfo[kLeanCloudRESTAPIResponseError])
                        XCTAssertNotNil(_error?.userInfo["com.alamofire.serialization.response.error.data"])
                    })
                } else {
                    
                    semaphore.decrement()
                    
                    XCTAssertNotNil(error)
                    let _error: NSError? = error as NSError?
                    XCTAssertEqual(_error?.code, 202)
                    XCTAssertEqual(_error?.domain, kLeanCloudErrorDomain)
                    /* for compatibility */
                    XCTAssertNotNil(_error?.userInfo[kLeanCloudRESTAPIResponseError])
                    XCTAssertNotNil(_error?.userInfo["com.alamofire.serialization.response.error.data"])
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
    func testLoginByEmail() {
        let user = AVUser()
        let username = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        user.username = username
        let password = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        user.password = password
        let email = "\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))@email.com"
        user.email = email
        
        do {
            try user.signUpAndThrows()
        } catch {
            XCTFail("\(error)")
        }
        
        let exp1 = expectation(description: "login by email")
        AVUser.login(withEmail: email, password: password) { (sameUser, error) in
            XCTAssertNotNil(sameUser)
            XCTAssertFalse(user === sameUser)
            XCTAssertEqual(user.objectId, sameUser?.objectId)
            XCTAssertEqual(username, sameUser?.username)
            XCTAssertEqual(email, sameUser?.email)
            XCTAssertNil(error)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 30)
        
        let exp2 = expectation(description: "login by username")
        AVUser.logInWithUsername(inBackground: username, password: password) { (sameUser, error) in
            XCTAssertNotNil(sameUser)
            XCTAssertFalse(user === sameUser)
            XCTAssertEqual(user.objectId, sameUser?.objectId)
            XCTAssertEqual(username, sameUser?.username)
            XCTAssertEqual(email, sameUser?.email)
            XCTAssertNil(error)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 30)
    }
    
}
