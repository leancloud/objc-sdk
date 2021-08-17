//
//  LCFileTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2021/08/17.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

class LCFileTestCase: BaseTestCase {
    
    func testObjectAssociation() {
        let data = uuid.data(using: .utf8)!
        let file = LCFile(data: data)
        expecting { exp in
            file.saveInBackground { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        let fileFieldKey = "fileField"
        let object = LCObject()
        object[fileFieldKey] = file;
        XCTAssertTrue(object.save())
        
        guard let objectId = object.objectId else {
            XCTFail()
            return
        }
        
        let object0 = LCObject(objectId: objectId)
        XCTAssertTrue(object0.fetch())
        XCTAssertTrue(object0[fileFieldKey] is LCFile)
    }
}
