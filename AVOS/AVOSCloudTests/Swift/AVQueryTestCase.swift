//
//  LCQueryTestCase.swift
//  AVOSCloud-iOSTests
//
//  Created by zapcannon87 on 2019/4/1.
//  Copyright © 2019 LeanCloud Inc. All rights reserved.
//

import XCTest

class LCQueryTestCase: LCTestBase {

    func testQuery() {
        let query = LCQuery(className: "TestObject")
        
        XCTAssertNotNil(query.findObjects())
    }

}
