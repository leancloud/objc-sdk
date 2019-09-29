//
//  AVInstallationTestCase.swift
//  AVOSCloud-iOSTests
//
//  Created by zapcannon87 on 2019/9/27.
//  Copyright © 2019 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVInstallation_TestCase: LCTestBase {
    
    let teamId: String = "LeanCloud"
    
    func testDefault() {
        AVInstallation.default().setDeviceTokenHexString(
            UUID().uuidString,
            teamId: teamId)
        XCTAssertTrue(AVInstallation.default().save())
    }
    
    func testSave() {
        let installation = AVInstallation()
        installation.setDeviceTokenHexString(
            "",
            teamId: teamId)
        XCTAssertFalse(installation.save())
        
        installation.setDeviceTokenFrom(
            Data(),
            teamId: teamId)
        XCTAssertFalse(installation.save())
        
        installation.setDeviceTokenHexString(
            UUID().uuidString,
            teamId: "")
        XCTAssertFalse(installation.save())
        
        installation.setDeviceTokenHexString(
            UUID().uuidString,
            teamId: teamId)
        XCTAssertTrue(installation.save())
        
        installation.setDeviceTokenFrom(
            UUID().uuidString.data(using: .utf8)!,
            teamId: teamId)
        XCTAssertTrue(installation.save())
    }
    
    func testSaveWithBadge() {
        let installation = AVInstallation()
        installation.setDeviceTokenHexString(
            UUID().uuidString,
            teamId: teamId)
        XCTAssertTrue(installation.save())
        XCTAssertEqual(installation.badge, 0)
        
        installation.badge = 1
        XCTAssertTrue(installation.save())
        XCTAssertEqual(installation.badge, 1)
        
        installation.badge = 0
        XCTAssertTrue(installation.save())
        XCTAssertEqual(installation.badge, 0)
    }
    
    func testSaveWithChannels() {
        let installation = AVInstallation()
        installation.setDeviceTokenHexString(
            UUID().uuidString,
            teamId: teamId)
        XCTAssertTrue(installation.save())
        XCTAssertEqual(installation.channels?.count ?? 0, 0)
        
        let channelID = UUID().uuidString
        installation.addUniqueObject(
            channelID,
            forKey: "channels")
        XCTAssertTrue(installation.save())
        XCTAssertEqual(installation.channels?.count, 1)
        XCTAssertEqual(installation.channels?.first as? String, channelID)
        
        installation.remove(channelID, forKey: "channels")
        XCTAssertTrue(installation.save())
        XCTAssertEqual(installation.channels?.count, 0)
        
        installation.channels = [UUID().uuidString, UUID().uuidString]
        XCTAssertTrue(installation.save())
        XCTAssertEqual(installation.channels?.count, 2)
    }
    
    func testSaveWithDeviceProfile() {
        let installation = AVInstallation()
        installation.setDeviceTokenHexString(
            UUID().uuidString,
            teamId: teamId)
        installation.deviceProfile = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        XCTAssertTrue(installation.save())
        XCTAssertNotNil(installation.deviceProfile)
    }
    
    func testCustomField() {
        let installation = AVInstallation()
        installation.setDeviceTokenHexString(
            UUID().uuidString,
            teamId: teamId)
        installation["customField"] = UUID().uuidString
        XCTAssertTrue(installation.save())
        XCTAssertNotNil(installation["customField"])
    }

}
