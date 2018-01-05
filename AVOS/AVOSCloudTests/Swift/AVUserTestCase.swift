//
//  AVUserTestCase.swift
//  AVOS
//
//  Created by ZapCannon87 on 11/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVUserTestCase: LCTestBase {
    
    func testUserLogin() {
        
        let username: String = "Swift.AVUserTestCase.testUserLogin"
        let password: String = "123456"
        
        let user: AVUser = AVUser()
        
        user.username = username
        user.password = password
        
        user.signUp(nil);
        
        do {
            
            let _ = try AVUser.logIn(
                withUsername: username,
                password: password,
                error: ()
            )
            
        } catch {
            
            XCTAssertNil(error)
        }
    }
    
}
