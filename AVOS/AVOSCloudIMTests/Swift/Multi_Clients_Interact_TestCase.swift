//
//  Multi_Clients_Interact_TestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 09/03/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

let file: String = "\(URL.init(fileURLWithPath: #file).deletingPathExtension().lastPathComponent)"

class Multi_Clients_Interact_TestCase: LCIMTestBase {
    
    static var client1: AVIMClient_Wrapper!
    
    static var client2: AVIMClient_Wrapper!
    
    override class func setUp() {
        super.setUp()
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            let client1: AVIMClient_Wrapper = AVIMClient_Wrapper(with: "\(file)\(#line)")
            
            semaphore.increment()
            
            client1.client.open(callback: { (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
    
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                
                if succeeded {
                    
                    self.client1 = client1
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            let client2: AVIMClient_Wrapper = AVIMClient_Wrapper(with: "\(file)\(#line)")
            
            semaphore.increment()
            
            client2.client.open(callback: { (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                
                if succeeded {
                    
                    self.client2 = client2
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
    override func tearDown() {
        
        super.tearDown()
    }
    
    func test_recall_message() {
        
        guard let client1: AVIMClient_Wrapper = type(of: self).client1,
            let client2: AVIMClient_Wrapper = type(of: self).client2 else {
                XCTFail()
                return
        }
        
        var conversation: AVIMConversation?
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client1.client.createConversation(withName: "\(file)\(#line)", clientIds: [client1.client.clientId, client2.client.clientId], attributes: nil, options: [.unique], callback: { (conv: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                
                if let conv: AVIMConversation = conv {
                    
                    conversation = conv
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        guard let _conversation: AVIMConversation = conversation else {
            XCTFail()
            return
        }
        
        var message: AVIMMessage?
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            let sendingMessage: AVIMTextMessage = AVIMTextMessage.init(text: "test", attributes: nil)
            
            semaphore.increment()
            
            _conversation.send(sendingMessage, callback: { (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                
                if succeeded {
                    
                    message = sendingMessage
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        guard let _message: AVIMMessage = message else {
            XCTFail()
            return
        }
        
        _conversation.add(client1)
        
        _conversation.add(client2)
        
        self.runloopTestingAsync(timeout: 60, async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client1.messageHasBeenUpdatedClosure = { (conv: AVIMConversation, message: AVIMMessage) in
                
                semaphore.decrement()
                
                XCTAssertEqual(message.messageId, _message.messageId)
            }
            
            semaphore.increment()
            
            client2.messageHasBeenUpdatedClosure = { (conv: AVIMConversation, message: AVIMMessage) in
                
                semaphore.decrement()
                
                XCTAssertEqual(message.messageId, _message.messageId)
            }
            
            semaphore.increment()
            
            _conversation.recall(_message, callback: { (succeeded: Bool, error: Error?, recalledMessage: AVIMMessage?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                
                XCTAssertEqual(_message.messageId, recalledMessage?.messageId)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
}

class AVIMClient_Wrapper: NSObject {
    
    let client: AVIMClient
    
    var messageHasBeenUpdatedClosure: ((AVIMConversation, AVIMMessage) -> Void)?
    
    init(with clientId: String) {
        
        self.client = AVIMClient.init(clientId: clientId)
        
        super.init()
        
        self.client.delegate = self
    }
    
}

extension AVIMClient_Wrapper: AVIMClientDelegate, AVIMConversationDelegate {
    
    func imClientClosed(_ imClient: AVIMClient, error: Error?) {}
    func imClientResuming(_ imClient: AVIMClient) {}
    func imClientResumed(_ imClient: AVIMClient) {}
    func imClientPaused(_ imClient: AVIMClient) {}
    
    func conversation(_ conversation: AVIMConversation, messageHasBeenUpdated message: AVIMMessage) {
        self.messageHasBeenUpdatedClosure?(conversation, message)
    }
    
}
