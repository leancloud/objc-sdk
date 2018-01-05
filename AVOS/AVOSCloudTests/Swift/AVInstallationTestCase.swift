//
//  AVInstallationTestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 05/01/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVInstallationTestCase: LCTestBase {
    
    func testSaveDeviceTokenAndTeamId() {
        
        let deviceTokenData: Data = "testSaveDeviceTokenAndTeamId.deviceTokenData".data(using: .ascii)!
        
        if self.runloopTestAsync(timeout: 5, closure: { (semaphore) -> (Void) in
            
            AVOSCloud.handleRemoteNotifications(
                withDeviceToken: deviceTokenData,
                teamId: "testSaveDeviceTokenAndTeamId.teamId"
            )
            
        }) {
            
            // No callback, validate data in Sudo Backend.
        }
    }

}
