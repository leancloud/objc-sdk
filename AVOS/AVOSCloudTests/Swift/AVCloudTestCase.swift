//
//  AVCloud_TestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 2018/4/4.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest
import AVOSCloud

class AVCloud_TestCase: LCTestBase {
    
    func testError() {
        let exp = self.expectation(description: "error")
        LCCloud.callFunction(inBackground: "error", withParameters: nil) { (result, error) in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 30)
    }
    
}
