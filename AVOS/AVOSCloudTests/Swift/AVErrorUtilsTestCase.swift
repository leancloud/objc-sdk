//
//  AVErrorUtilsTestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 16/01/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVErrorUtilsTestCase: LCTestBase {
    
    func testErrorFromJSON() {
        
        let dic1: [String : Any] = [
            "code" : 0,
            "error" : "error"
        ]
        
        XCTAssertNotNil(AVErrorUtils.error(fromJSON: dic1))
        
        let dic2: [String : Any] = [
            "code" : "error",
            "error" : "error"
        ]
        
        XCTAssertNil(AVErrorUtils.error(fromJSON: dic2))
        
        let dic3: [String : Any] = [
            "code" : 0,
            "error" : 0
        ]
        
        XCTAssertNil(AVErrorUtils.error(fromJSON: dic3))
        
        let dic4: [String : Any] = [
            "code" : 0
        ]
        
        XCTAssertNil(AVErrorUtils.error(fromJSON: dic4))
        
        let dic5: [String : Any] = [
            "error" : "error"
        ]
        
        XCTAssertNil(AVErrorUtils.error(fromJSON: dic5))
        
        let dic6: [String : Any] = [:]
        
        XCTAssertNil(AVErrorUtils.error(fromJSON: dic6))
        
        let dic7: [String : Any]? = nil
        
        XCTAssertNil(AVErrorUtils.error(fromJSON: dic7))
        
        let dic8: [String : Any] = [
            "a" : dic1
        ]
        
        XCTAssertNotNil(AVErrorUtils.error(fromJSON: dic8))
        
        let dic9: [String : Any] = [
            "a" : [dic1]
        ]
        
        XCTAssertNotNil(AVErrorUtils.error(fromJSON: dic9))
        
        let dic10: [String : Any] = [
            "a" : ["b" : dic1]
        ]
        
        XCTAssertNotNil(AVErrorUtils.error(fromJSON: dic10))
        
        let arr1: [Any] = [dic1]
        
        XCTAssertNotNil(AVErrorUtils.error(fromJSON: arr1))
        
        let arr2: [Any] = [dic2, arr1]
        
        XCTAssertNotNil(AVErrorUtils.error(fromJSON: arr2))
        
        let arr3: [Any] = [dic2, dic10]
        
        XCTAssertNotNil(AVErrorUtils.error(fromJSON: arr3))
        
        let arr4: [Any] = []
        
        XCTAssertNil(AVErrorUtils.error(fromJSON: arr4))
        
        let arr5: [Any]? = nil
        
        XCTAssertNil(AVErrorUtils.error(fromJSON: arr5))
    }

}
