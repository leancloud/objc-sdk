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
    
    func test_save_multiple_installation() {
        
        let installation0 = AVInstallation()
        installation0.apnsTopic = "0"
        installation0.deviceToken = "0"
        
        var installation0_objectId: String? = nil
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            semaphore.increment()
            
            installation0.saveInBackground({ (success: Bool, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
                
                XCTAssertNotNil(installation0.objectId)
                
                installation0_objectId = installation0.objectId
            })
            
        }) {
            
            XCTFail("timeout")
        }
        
        guard installation0_objectId != nil else {
            
            XCTFail()
            
            return
        }
        
        let installation1 = AVInstallation()
        installation1.apnsTopic = "1"
        installation1.deviceToken = "1"
        
        var installation1_objectId: String? = nil
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            semaphore.increment()
            
            installation0.saveInBackground({ (success: Bool, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
                
                XCTAssertNotNil(installation1.objectId)
                
                installation1_objectId = installation1.objectId
            })
            
        }) {
            
            XCTFail("timeout")
        }
        
        guard installation1_objectId != nil else {
            
            XCTFail()
            
            return
        }
        
        XCTAssertNotEqual(installation0_objectId, installation1_objectId)
    }

}
