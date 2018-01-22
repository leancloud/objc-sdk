//
//  AVInstallationTestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 05/01/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVInstallationTestCase: LCTestBase {
    
    func test_save_deviceToken_and_teamId() {
        
        if self.runloopTestAsync(timeout: 5, closure: { (semaphore) -> (Void) in
            
            semaphore.increment()
            
            AVOSCloud.handleRemoteNotifications(
                withDeviceToken: "device_token".data(using: .ascii)!,
                teamId: "team_id"
            )
            
        }) {
            
            // No callback.
        }
        
        guard AVInstallation.default().objectId != nil else {
            
            XCTFail()
            
            return
        }
        
        let installation: AVInstallation = AVInstallation(objectId: AVInstallation.default().objectId!)
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            semaphore.increment()
            
            installation.fetchInBackground(withKeys: ["deviceToken", "apnsTeamId"], block: { (object: AVObject?, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(object)
                XCTAssertNil(error)
                XCTAssertEqual(object?.object(forKey: "deviceToken") as? String, AVInstallation.default().deviceToken)
                XCTAssertEqual(object?.object(forKey: "apnsTeamId") as? String, AVInstallation.default().apnsTeamId)
            })
            
        }) {
            
            XCTFail("timeout")
        }

    }

}
