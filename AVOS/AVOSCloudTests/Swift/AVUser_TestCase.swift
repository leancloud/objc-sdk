//
//  AVUser_TestCase.swift
//  AVOS
//
//  Created by ZapCannon87 on 11/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVUser_TestCase: LCTestBase {
    
    func newAVUser() -> AVUser? {
        
        let username: String = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let password: String = "123"
        
        var user: AVUser! = AVUser.init()
        user.username = username
        user.password = password
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            user.signUpInBackground { (succeeded: Bool, error: Error?) in
             
                XCTAssertTrue(Thread.isMainThread)
                
                if let err: NSError = error as NSError? {
                    
                    if let response: [String : Any] = err.userInfo[kLeanCloudRESTAPIResponseError] as? [String : Any],
                        let code: Int = response["code"] as? Int,
                        code == 202 {
                        
                        AVUser.logInWithUsername(inBackground: username, password: password, block: { (aUser: AVUser?, aError: Error?) in
                            
                            semaphore.decrement()
                            
                            if let _ = aError {
                                
                                user = nil
                                
                            } else {
                                
                                user = aUser
                            }
                        })
                        
                    } else {
                        
                        semaphore.decrement()
                        user = nil
                    }
                } else {
                    
                    semaphore.decrement()
                }
            }
        }, failure: {
            user = nil
            XCTFail("timeout")
        })
        
        return user
    }
    
    func test_temp_1() {
        
        guard let user: AVUser = self.newAVUser() else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            user.saveInBackground({ (succeeded: Bool, error: Error?) in
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                
                guard succeeded == true, error == nil else {
                    semaphore.decrement()
                    return
                }
                
                user.refreshInBackground({ (object: AVObject?, error: Error?) in
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(object === user)
                    XCTAssertNil(error)
                    
                    guard object === user, error == nil else {
                        semaphore.decrement()
                        return
                    }
                    
                    XCTAssertTrue(AVUser.current() == user)
                    
                    AVUser.logOut()
                    
                    semaphore.decrement()
                })
            })
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
    func test_temp_2() {
        
        guard let user: AVUser = self.newAVUser() else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            let i: Int = 5
            
            semaphore.increment(2 * i)
            
            for _ in 0..<i {
                
                user.saveInBackground({ (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
                
                user.refreshInBackground({ (object: AVObject?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(object === user)
                    XCTAssertNil(error)
                })
            }
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
}
