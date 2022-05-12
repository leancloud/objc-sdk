//
//  LCInstallationTestCase.swift
//  LeanCloudObjcTests
//
//  Created by zapcannon87 on 2022/05/12.
//  Copyright © 2022 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

class LCInstallationTestCase: BaseTestCase {
    
    func testClearPersistentCache() {
        let installation = LCInstallation.default()
        installation.setDeviceTokenFrom(uuid.data(using: .utf8)!, teamId: "LeanCloud")
        XCTAssertTrue(installation.save())
        XCTAssertTrue(FileManager.default.fileExists(atPath: LCPersistenceUtils.currentInstallationArchivePath()))
        LCInstallation.clearPersistentCache()
        XCTAssertFalse(FileManager.default.fileExists(atPath: LCPersistenceUtils.currentInstallationArchivePath()))
    }
}
