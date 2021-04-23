//
//  LCObject_TestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 27/03/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class LCObject_TestCase: LCTestBase {
    
    func testc_save_associate_file_object() {
        
        if self.isServerTesting { return }
        
        var objectID: String?
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            
            let filePath: String = Bundle(for: type(of: self)).path(forResource: "_10_MB_", ofType: "png")!
            
            let url: URL = URL.init(fileURLWithPath: filePath)
            
            let data: Data = try! Data.init(contentsOf: url)
            
            let file: LCFile = LCFile(data: data)
            
            let lcObjectt: LCObject = LCObject(className: "Todo")
            
            lcObjectt.setObject(file, forKey: "image")
            
            semaphore.increment()
            
            lcObjectt.saveInBackground({ (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                objectID = lcObjectt.objectId
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        if let objectID = objectID {
            let object = LCObject(className: "Todo", objectId: objectID)
            XCTAssertTrue(object.fetch())
        }
    }

    func testc_fetch_all_objects() {
        let object1 = LCObject()
        let object2 = LCObject()

        object1["firstName"] = "Bar"
        object1["lastName"]  = "Foo"

        object2["firstName"] = "Baz"
        object2["lastName"]  = "Foo"

        XCTAssertTrue(LCObject.saveAll([object1, object2]))

        RunLoopSemaphore.wait(timeout: 60, async: { semaphore in
            semaphore.increment()

            let objects = [
                LCObject(objectId: object1.objectId!),
                LCObject(objectId: object2.objectId!)
            ]

            LCObject.fetchAll(inBackground: objects) { (objects, error) in
                guard let objects = objects as? [LCObject], objects.count == 2 else {
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
    
    func testDate() {
        let className = "LCObjectTestCase"
        let object = LCObject(className: className)
        object.setObject(Date(), forKey: "date")
        let exp1 = expectation(description: "save date")
        object.saveInBackground { (success, error) in
            XCTAssertTrue(success)
            XCTAssertNil(error)
            XCTAssertNotNil(object["date"] as? Date)
            XCTAssertNotNil(object.createdAt)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 60)
        
        let fetchObject = LCObject(className: className, objectId: object.objectId!)
        let exp2 = expectation(description: "fetch object")
        fetchObject.fetchInBackground { (object, error) in
            XCTAssertNotNil(object)
            XCTAssertNil(error)
            XCTAssertNotNil(object?["date"] as? Date)
            XCTAssertNotNil(object?.createdAt)
            XCTAssertNotNil(object?.updatedAt)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 60)
    }
}
