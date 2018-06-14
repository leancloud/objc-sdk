//
//  AVObject_TestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 27/03/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVObject_TestCase: LCTestBase {
    
    func test_save_associate_file_object() {
        
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
    
    func test_temp() {
        
        let object: AVObject = AVObject(className: "Comment")
        object["targetTodoFolder"] = AVObject(className: "TodoFolder", objectId: "5590cdfde4b00f7adb5860c8")
        object.save()
        
        let query: AVQuery = AVQuery(className: "Comment")
        query.whereKey("targetTodoFolder", equalTo: AVObject(className: "TodoFolder"))
        guard let results: [AVObject] = query.findObjects() as? [AVObject] else {
            XCTFail()
            return
        }
        
        var found = false
        for item in results {
            if item.objectId == object.objectId {
                found = true
            }
        }
        XCTAssertFalse(found)
    }
    
}
