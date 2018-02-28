//
//  LCIMTestCaseConversation.swift
//  AVOS
//
//  Created by zapcannon87 on 26/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import XCTest

class LCIMTestCaseConversation: LCIMTestBase {
    
    static var globalConversation: AVIMConversation?
    
    let bundle: Bundle = Bundle.init(for: LCIMTestCaseConversation.self)
    
    override class func setUp() {
        super.setUp()
        
        guard let client: AVIMClient = LCIMTestBase.baseGlobalClient else {
            
            XCTFail()
            
            globalConversation = nil
            
            return
        }
        
        var conversation: AVIMConversation? = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.createConversation(
                withName: "LCIMTestCaseConversation.globalConversation",
                clientIds: [],
                attributes: nil,
                options: [.unique],
                temporaryTTL: 0
            ){ (conv, err) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conv)
                XCTAssertNotNil(conv?.conversationId)
                XCTAssertNil(err)
                
                conversation = conv
            }
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        guard let _conversation: AVIMConversation = conversation else {
            
            XCTFail()
            
            return
        }
        
        self.globalConversation = _conversation
    }
    
    override class func tearDown() {
        
        self.globalConversation = nil
        
        super.tearDown()
    }
    
    func testSendTextMessage() {
        
        guard let conv: AVIMConversation = LCIMTestCaseConversation.globalConversation else {
            
            XCTFail()
            
            return
        }
        
        for i in 0..<5 {
            
            let text: String = "\(i)"
            
            let textMessage: AVIMTextMessage = AVIMTextMessage(
                text: text,
                attributes: nil
            )
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                conv.send(textMessage, callback: { (isSuccess, error) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(isSuccess)
                    XCTAssertNil(error)
                    XCTAssertNotNil(textMessage.messageId)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
    func testSendImageMessage() {
        
        guard let conv: AVIMConversation = LCIMTestCaseConversation.globalConversation else {
            
            XCTFail()
            
            return
        }
        
        let imageUrl: URL = self.bundle.url(forResource: "testImage", withExtension: "png")!
        let imageData: Data = try! Data.init(contentsOf: imageUrl)
        let imageFile: AVFile = AVFile.init(data: imageData, name: "image.png")
        
        for i in 0..<5 {
            
            let text: String = "\(i)"
            
            let imageMessage: AVIMImageMessage = AVIMImageMessage(
                text: text,
                file: imageFile,
                attributes: nil
            )
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                conv.send(imageMessage, callback: { (isSuccess, error) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(isSuccess)
                    XCTAssertNil(error)
                    XCTAssertNotNil(imageMessage.messageId)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
    func testSendAudioMessage() {
        
        guard let conv: AVIMConversation = LCIMTestCaseConversation.globalConversation else {
            
            XCTFail()
            
            return
        }
        
        let audioUrl: URL = self.bundle.url(forResource: "testAudio", withExtension: "mp3")!
        let audioData: Data = try! Data.init(contentsOf: audioUrl)
        let audioFile: AVFile = AVFile.init(data: audioData, name: "audio.mp3")
        
        for i in 0..<5 {
            
            let text: String = "\(i)"
            
            let audioMessage: AVIMAudioMessage = AVIMAudioMessage(
                text: text,
                file: audioFile,
                attributes: nil
            )
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                conv.send(audioMessage, callback: { (isSuccess, error) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(isSuccess)
                    XCTAssertNil(error)
                    XCTAssertNotNil(audioMessage.messageId)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
    func testSendVideoMessage() {
        
        guard let conv: AVIMConversation = LCIMTestCaseConversation.globalConversation else {
            
            XCTFail()
            
            return
        }
        
        let videoUrl: URL = bundle.url(forResource: "testVideo", withExtension: "mp4")!
        let videoData: Data = try! Data.init(contentsOf: videoUrl)
        let videoFile: AVFile = AVFile.init(data: videoData, name: "video.mp4")
        
        for i in 0..<5 {
            
            let text: String = "\(i)"
            
            let videoMessage: AVIMVideoMessage = AVIMVideoMessage(
                text: text,
                file: videoFile,
                attributes: nil
            )
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                conv.send(videoMessage, callback: { (isSuccess, error) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(isSuccess)
                    XCTAssertNil(error)
                    XCTAssertNotNil(videoMessage.messageId)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
    func testSendLocationMessage() {
        
        guard let conv: AVIMConversation = LCIMTestCaseConversation.globalConversation else {
            
            XCTFail()
            
            return
        }
        
        for i in 0..<5 {
            
            let text: String = "\(i)"
            
            let locationMessage: AVIMLocationMessage = AVIMLocationMessage(
                text: text,
                latitude: 39.9042,
                longitude: 116.4074,
                attributes: nil
            )
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                conv.send(locationMessage, callback: { (isSuccess, error) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(isSuccess)
                    XCTAssertNil(error)
                    XCTAssertNotNil(locationMessage.messageId)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
    func testSendFileMessage() {
        
        guard let conv: AVIMConversation = LCIMTestCaseConversation.globalConversation else {
            
            XCTFail()
            
            return
        }
        
        let fileUrl: URL = bundle.url(forResource: "testFile", withExtension: "md")!
        let fileData: Data = try! Data.init(contentsOf: fileUrl)
        let fileFile: AVFile = AVFile.init(data: fileData, name: "text.md")
        
        for i in 0..<5 {
            
            let text: String = "\(i)"
            
            let fileMessage: AVIMFileMessage = AVIMFileMessage(
                text: text,
                file: fileFile,
                attributes: nil
            )
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                conv.send(fileMessage, callback: { (isSuccess, error) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(isSuccess)
                    XCTAssertNil(error)
                    XCTAssertNotNil(fileMessage.messageId)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
    func testQueryMessageWithType() {
        
        guard let conv: AVIMConversation = LCIMTestCaseConversation.globalConversation else {
            
            XCTFail()
            
            return
        }
        
        let typeArray: [AVIMMessageMediaType] = [
            .text,
            .image,
            .audio,
            .video,
            .location,
            .file
        ]
        
        for type in typeArray {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                conv.queryMediaMessagesFromServer(
                    with: type,
                    limit: 10,
                    fromMessageId: nil,
                    fromTimestamp: 0
                ) { (array, error) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(array)
                    XCTAssertNil(error)
                    
                    guard let msgArray: [AVIMMessage] = array as? [AVIMMessage] else {
                        
                        XCTFail()
                        
                        return
                    }
                    
                    XCTAssertFalse(msgArray.isEmpty)
                    
                    for msg in msgArray {
                        
                        XCTAssertNotNil(msg.messageId)
                        XCTAssertTrue(msg.mediaType.rawValue == type.rawValue)
                    }
                }
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
    func testServiceConversation_subscribe_unsubscrib() {
        
        guard let client: AVIMClient = type(of: self).baseGlobalClient else {
            
            XCTFail()
            
            return
        }
        
        var serviceConversation: AVIMServiceConversation? = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.conversationQuery().getConversationById("5a5ee32afe88c2003b0f2d6b") { (conv: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                
                guard let serviceConv: AVIMServiceConversation = conv as? AVIMServiceConversation else {
                    
                    XCTFail()
                    
                    return
                }
                
                serviceConversation = serviceConv
            }
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        guard let serviceConv: AVIMServiceConversation = serviceConversation else {
            
            XCTFail()
            
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            serviceConv.subscribe(callback: { (success: Bool, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            serviceConv.unsubscribe(callback: { (success: Bool, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(success)
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
}
