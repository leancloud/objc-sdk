//
//  AVObject_TestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 27/03/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVObject_TestCase: LCTestBase {
    
    func testc_save_associate_file_object() {
        
        if self.isServerTesting { return }
        
        var objectID: String?
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            
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
                objectID = avObject.objectId
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        if let objectID = objectID {
            let object = AVObject(className: "Todo", objectId: objectID)
            XCTAssertTrue(object.fetch())
        }
    }

    func testc_fetch_all_objects() {
        let object1 = AVObject()
        let object2 = AVObject()

        object1["firstName"] = "Bar"
        object1["lastName"]  = "Foo"

        object2["firstName"] = "Baz"
        object2["lastName"]  = "Foo"

        XCTAssertTrue(AVObject.saveAll([object1, object2]))

        RunLoopSemaphore.wait(timeout: 60, async: { semaphore in
            semaphore.increment()

            let objects = [
                AVObject(objectId: object1.objectId!),
                AVObject(objectId: object2.objectId!)
            ]

            AVObject.fetchAll(inBackground: objects) { (objects, error) in
                guard let objects = objects as? [AVObject], objects.count == 2 else {
                    XCTFail()
                    return
                }

                let object1 = objects[0]
                let object2 = objects[1]

                XCTAssertEqual(object1["firstName"] as? String, "Bar")
                XCTAssertEqual(object1["lastName"] as? String, "Foo")

                XCTAssertEqual(object2["firstName"] as? String, "Baz")
                XCTAssertEqual(object2["lastName"] as? String, "Foo")

                semaphore.decrement()
            }
        }, failure: {
            XCTFail()
        })
    }
    
    func testInstallation() {
        AVInstallation.default().deviceToken = UUID().uuidString
        XCTAssertTrue(AVInstallation.default().save())
    }
    
}
