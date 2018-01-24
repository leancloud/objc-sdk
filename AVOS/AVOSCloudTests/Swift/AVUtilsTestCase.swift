//
//  AVUtilsTestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 24/01/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVUtilsTestCase: LCTestBase {

    func test_decodingFromDictionary() {
        
        let dic: [String : Any] = [
            "a" : NSString(string: "a"),
            "b" : NSNumber(integerLiteral: 1),
            "c" : NSObject()
        ]
        
        guard let _: NSString = NSString.decoding(withKey: "a", fromDic: dic) else {
            
            XCTFail()
            
            return
        }
        
        guard let _: NSNumber = NSNumber.decoding(withKey: "b", fromDic: dic) else {
            
            XCTFail()
            
            return
        }
        
        guard let _: NSObject = NSObject.decoding(withKey: "c", fromDic: dic) else {
            
            XCTFail()
            
            return
        }
        
        let a: NSNumber? = NSNumber.decoding(withKey: "a", fromDic: dic)
        XCTAssertNil(a)
    }

}
