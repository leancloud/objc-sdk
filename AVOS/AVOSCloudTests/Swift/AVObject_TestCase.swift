//
//  AVObject_TestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 27/03/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVObject_TestCase: LCTestBase {
    
    func test_associate_AVFile_save() {
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            let filePath: String = Bundle(for: type(of: self)).path(forResource: "_10_MB_", ofType: "png")!
            
            let url: URL = URL.init(fileURLWithPath: filePath)
            
            let data: Data = try! Data.init(contentsOf: url)
            
            let file: AVFile = AVFile(data: data)
            
            let avObject: AVObject = AVObject(className: "Todo")
            
            avObject.setObject(file, forKey: "image")
            
            semaphore.increment()
            
            avObject.saveInBackground({ (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
}
