//
//  AVUserTestCase.swift
//  AVOS
//
//  Created by ZapCannon87 on 11/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVUserTestCase: LCTestBase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testUserLogin() {
        
        let username: String = "Swift.AVUserTestCase.testUserLogin"
        let password: String = "123456"
        
        let user: AVUser = AVUser()
        
        user.username = username
        user.password = password
        
        user.signUp(nil);
        
        do {
            
            let _ = try AVUser.logIn(withUsername:username, password: password, error: ())
            
        } catch {
            
            print(error)
        }
    }
    
}
