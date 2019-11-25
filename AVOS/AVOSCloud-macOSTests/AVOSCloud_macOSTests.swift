//
//  AVOSCloud_macOSTests.swift
//  AVOSCloud-macOSTests
//
//  Created by zapcannon87 on 2019/11/25.
//  Copyright © 2019 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVOSCloud_macOSTests: LCTestBase {

    func testMacOS() {
        let object = AVObject(className: "Test")
        XCTAssertTrue(object.save())
    }
}
