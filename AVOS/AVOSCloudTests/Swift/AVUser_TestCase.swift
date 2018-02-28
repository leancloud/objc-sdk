//
//  AVUser_TestCase.swift
//  AVOS
//
//  Created by ZapCannon87 on 11/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVUser_TestCase: LCTestBase {
    
    func testUserLogin() {
        
        let username: String = "Swift.AVUser_TestCase.testUserLogin"
        let password: String = "123456"
        
        let user: AVUser = AVUser()
        
        user.username = username
        user.password = password
        
        user.signUp(nil);
        
        do {
            
            let _user = try AVUser.logIn(
                withUsername: username,
                password: password,
                error: ()
            )
            
            let dic = _user.object(forKey: "localData")
            
            XCTAssertNotNil(dic)
            
        } catch {
            
            XCTAssertNil(error)
        }
    }
    
}
