//
//  AVFileTestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 22/01/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVFileTestCase: LCTestBase {
    
    func test_upload_urlFile() {
        
        let urlFile: AVFile = AVFile(url: "http://ac-jmbpc7y4.clouddn.com/d40e9cf44dc5dadf1577.m4a")
        
        if self.runloopTestAsync(closure: { (semaphore) -> (Void) in
            
            semaphore.increment()
            
            urlFile.saveInBackground({ (success: Bool, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
            })
            
        }) {
            
            XCTFail("timeout")
        }

    }
    
    func test_upload_localFile() {
        
        let filePath: String = Bundle(for: type(of: self)).path(forResource: "alpacino", ofType: "jpg")!
        
        let url: URL = URL.init(fileURLWithPath: filePath)
        
        let data: Data = try! Data.init(contentsOf: url)
        
        let localFile: AVFile = AVFile(data: data)
        
        if self.runloopTestAsync(timeout: .infinity, closure: { (semaphore) -> (Void) in
            
            semaphore.increment()
            
            localFile.saveInBackground({ (success: Bool, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
            })
            
        }) {
            
            XCTFail("timeout")
        }
    }

}
