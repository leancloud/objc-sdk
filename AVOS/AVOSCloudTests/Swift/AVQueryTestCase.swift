//
//  AVQueryTestCase.swift
//  AVOSCloud-iOSTests
//
//  Created by zapcannon87 on 2019/4/1.
//  Copyright © 2019 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVQueryTestCase: LCTestBase {

    func testQuery() {
        let query = AVQuery(className: "TestObject")
        
        XCTAssertNotNil(query.findObjects())
    }

}
