//
//  AVUtilsTestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 24/01/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVUtilsTestCase: LCTestBase {

    func test_cocoa_checkingType_decodingFromDictionary() {
        
        let dic: [String : Any] = [
            "a" : NSString(string: "a"),
            "b" : NSNumber(integerLiteral: 1),
            "c" : NSObject()
        ]
        
        guard NSDictionary.lc__checkingType(dic as NSDictionary) else {
            
            XCTFail()
            
            return
        }
        
        let b: NSString = NSString(string: "a")
        XCTAssertFalse(NSNumber.lc__checkingType(b))
        
        guard let _: NSString = NSString.lc__decoding(withKey: "a", fromDic: dic) else {
            
            XCTFail()
            
            return
        }
        
        guard let _: NSNumber = NSNumber.lc__decoding(withKey: "b", fromDic: dic) else {
            
            XCTFail()
            
            return
        }
        
        guard let _: NSObject = NSObject.lc__decoding(withKey: "c", fromDic: dic) else {
            
            XCTFail()
            
            return
        }
        
        let a: NSNumber? = NSNumber.lc__decoding(withKey: "a", fromDic: dic)
        XCTAssertNil(a)
    }

}
