//
//  AVIMConversation_TestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 2018/4/18.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVIMConversation_TestCase: LCIMTestBase {
    
    // MARK: - Message Send
    
    func test_msg_send_common() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if let normalConv: AVIMConversation = normalConv {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let content: String = "test"
                let commonMessage: AVIMMessage = AVIMMessage.init(content: content)
                
                semaphore.increment(2)
                
                delegate_2.didReceiveCommonMessageClosure = { (conv: AVIMConversation, message: AVIMMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.clientId, client_2.clientId)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.mediaType, .none)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.status, .delivered)
                    XCTAssertNotNil(message.messageId)
                    XCTAssertEqual(message.clientId, client_1.clientId)
                    XCTAssertEqual(message.localClientId, conv.clientId)
                    XCTAssertEqual(message.conversationId, conv.conversationId)
                    XCTAssertFalse(message.mentioned)
                    XCTAssertFalse(message.mentionAll)
                    XCTAssertTrue((message.mentionList ?? []).count == 0)
                    XCTAssertEqual(message.content, content)
                    XCTAssertTrue(message.sendTimestamp > 0)
                    XCTAssertTrue(message.deliveredTimestamp == 0)
                    XCTAssertTrue(message.readTimestamp == 0)
                    XCTAssertFalse(message.transient)
                    XCTAssertNil(message.updatedAt)
                }
                
                normalConv.send(commonMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(commonMessage.mediaType, .none)
                    XCTAssertEqual(commonMessage.ioType, .out)
                    XCTAssertEqual(commonMessage.status, .sent)
                    XCTAssertNotNil(commonMessage.messageId)
                    XCTAssertEqual(commonMessage.clientId, normalConv.clientId)
                    XCTAssertEqual(commonMessage.localClientId, normalConv.clientId)
                    XCTAssertEqual(commonMessage.conversationId, normalConv.conversationId)
                    XCTAssertFalse(commonMessage.mentioned)
                    XCTAssertFalse(commonMessage.mentionAll)
                    XCTAssertTrue((commonMessage.mentionList ?? []).count == 0)
                    XCTAssertEqual(commonMessage.content, content)
                    XCTAssertTrue(commonMessage.sendTimestamp > 0)
                    XCTAssertTrue(commonMessage.deliveredTimestamp == 0)
                    XCTAssertTrue(commonMessage.readTimestamp == 0)
                    XCTAssertFalse(commonMessage.transient)
                    XCTAssertNil(commonMessage.updatedAt)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func test_msg_send_type_text() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if let normalConv: AVIMConversation = normalConv {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let text: String = "test"
                let textMessage: AVIMTextMessage = AVIMTextMessage.init(text: text, attributes: nil)
                
                semaphore.increment(2)
                
                delegate_2.didReceiveTypeMessageClosure = { (conv: AVIMConversation, message: AVIMTypedMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.clientId, client_2.clientId)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.mediaType, .text)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.status, .delivered)
                    XCTAssertNotNil(message.messageId)
                    XCTAssertEqual(message.clientId, client_1.clientId)
                    XCTAssertEqual(message.localClientId, conv.clientId)
                    XCTAssertEqual(message.conversationId, conv.conversationId)
                    XCTAssertFalse(message.mentioned)
                    XCTAssertFalse(message.mentionAll)
                    XCTAssertTrue((message.mentionList ?? []).count == 0)
                    XCTAssertEqual(message.text, text)
                    XCTAssertTrue(message.sendTimestamp > 0)
                    XCTAssertTrue(message.deliveredTimestamp == 0)
                    XCTAssertTrue(message.readTimestamp == 0)
                    XCTAssertFalse(message.transient)
                    XCTAssertNil(message.updatedAt)
                }
                
                normalConv.send(textMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(textMessage.mediaType, .text)
                    XCTAssertEqual(textMessage.ioType, .out)
                    XCTAssertEqual(textMessage.status, .sent)
                    XCTAssertNotNil(textMessage.messageId)
                    XCTAssertEqual(textMessage.clientId, normalConv.clientId)
                    XCTAssertEqual(textMessage.localClientId, normalConv.clientId)
                    XCTAssertEqual(textMessage.conversationId, normalConv.conversationId)
                    XCTAssertFalse(textMessage.mentioned)
                    XCTAssertFalse(textMessage.mentionAll)
                    XCTAssertTrue((textMessage.mentionList ?? []).count == 0)
                    XCTAssertEqual(textMessage.text, text)
                    XCTAssertTrue(textMessage.sendTimestamp > 0)
                    XCTAssertTrue(textMessage.deliveredTimestamp == 0)
                    XCTAssertTrue(textMessage.readTimestamp == 0)
                    XCTAssertFalse(textMessage.transient)
                    XCTAssertNil(textMessage.updatedAt)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func test_msg_send_type_location() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if let normalConv: AVIMConversation = normalConv {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let text: String = "test"
                let latitude: CGFloat = 22
                let longitude: CGFloat = 33
                let locationMessage: AVIMLocationMessage = AVIMLocationMessage.init(text: text, latitude: latitude, longitude: longitude, attributes: nil)
                
                semaphore.increment(2)
                
                delegate_2.didReceiveTypeMessageClosure = { (conv: AVIMConversation, message: AVIMTypedMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.clientId, client_2.clientId)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.mediaType, .location)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.status, .delivered)
                    XCTAssertNotNil(message.messageId)
                    XCTAssertEqual(message.clientId, client_1.clientId)
                    XCTAssertEqual(message.localClientId, conv.clientId)
                    XCTAssertEqual(message.conversationId, conv.conversationId)
                    XCTAssertFalse(message.mentioned)
                    XCTAssertFalse(message.mentionAll)
                    XCTAssertTrue((message.mentionList ?? []).count == 0)
                    XCTAssertEqual(message.text, text)
                    XCTAssertTrue(message.sendTimestamp > 0)
                    XCTAssertTrue(message.deliveredTimestamp == 0)
                    XCTAssertTrue(message.readTimestamp == 0)
                    XCTAssertFalse(message.transient)
                    XCTAssertNil(message.updatedAt)
                    XCTAssertEqual((message as? AVIMLocationMessage)?.latitude ?? 0, latitude)
                    XCTAssertEqual((message as? AVIMLocationMessage)?.longitude ?? 0, longitude)
                }
                
                normalConv.send(locationMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(locationMessage.mediaType, .location)
                    XCTAssertEqual(locationMessage.ioType, .out)
                    XCTAssertEqual(locationMessage.status, .sent)
                    XCTAssertNotNil(locationMessage.messageId)
                    XCTAssertEqual(locationMessage.clientId, normalConv.clientId)
                    XCTAssertEqual(locationMessage.localClientId, normalConv.clientId)
                    XCTAssertEqual(locationMessage.conversationId, normalConv.conversationId)
                    XCTAssertFalse(locationMessage.mentioned)
                    XCTAssertFalse(locationMessage.mentionAll)
                    XCTAssertTrue((locationMessage.mentionList ?? []).count == 0)
                    XCTAssertEqual(locationMessage.text, text)
                    XCTAssertTrue(locationMessage.sendTimestamp > 0)
                    XCTAssertTrue(locationMessage.deliveredTimestamp == 0)
                    XCTAssertTrue(locationMessage.readTimestamp == 0)
                    XCTAssertFalse(locationMessage.transient)
                    XCTAssertNil(locationMessage.updatedAt)
                    XCTAssertEqual(locationMessage.latitude, latitude)
                    XCTAssertEqual(locationMessage.longitude, longitude)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func test_msg_send_type_image() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if let normalConv: AVIMConversation = normalConv {
            
            var receiveFile: AVFile! = nil
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let text: String = "test"
                let dataTuple: (data: Data, name: String) = {
                    let filePath: String = Bundle(for: type(of: self)).path(forResource: "testImage", ofType: "png")!
                    let url: URL = URL.init(fileURLWithPath: filePath)
                    let data: Data = try! Data.init(contentsOf: url)
                    return (data, "image.png")
                }()
                let imageFile: AVFile = AVFile.init(data: dataTuple.data, name: dataTuple.name)
                let imageMessage: AVIMImageMessage = AVIMImageMessage.init(text: text, file: imageFile, attributes: nil)
                
                semaphore.increment(2)
                
                delegate_2.didReceiveTypeMessageClosure = { (conv: AVIMConversation, message: AVIMTypedMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.clientId, client_2.clientId)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.mediaType, .image)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.status, .delivered)
                    XCTAssertNotNil(message.messageId)
                    XCTAssertEqual(message.clientId, client_1.clientId)
                    XCTAssertEqual(message.localClientId, conv.clientId)
                    XCTAssertEqual(message.conversationId, conv.conversationId)
                    XCTAssertFalse(message.mentioned)
                    XCTAssertFalse(message.mentionAll)
                    XCTAssertTrue((message.mentionList ?? []).count == 0)
                    XCTAssertEqual(message.text, text)
                    XCTAssertTrue(message.sendTimestamp > 0)
                    XCTAssertTrue(message.deliveredTimestamp == 0)
                    XCTAssertTrue(message.readTimestamp == 0)
                    XCTAssertFalse(message.transient)
                    XCTAssertNil(message.updatedAt)
                    XCTAssertEqual((message as? AVIMImageMessage)?.size ?? 0, UInt64(dataTuple.data.count))
                    XCTAssertTrue(((message as? AVIMImageMessage)?.height ?? 0) > 0)
                    XCTAssertTrue(((message as? AVIMImageMessage)?.width ?? 0) > 0)
                    XCTAssertEqual((message as? AVIMImageMessage)?.format, (dataTuple.name as NSString).pathExtension)
                    let file: AVFile? = message.file
                    XCTAssertNotNil(file)
                    if let file: AVFile = file {
                        receiveFile = file
                    }
                }
                
                normalConv.send(imageMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(imageMessage.mediaType, .image)
                    XCTAssertEqual(imageMessage.ioType, .out)
                    XCTAssertEqual(imageMessage.status, .sent)
                    XCTAssertNotNil(imageMessage.messageId)
                    XCTAssertEqual(imageMessage.clientId, normalConv.clientId)
                    XCTAssertEqual(imageMessage.localClientId, normalConv.clientId)
                    XCTAssertEqual(imageMessage.conversationId, normalConv.conversationId)
                    XCTAssertFalse(imageMessage.mentioned)
                    XCTAssertFalse(imageMessage.mentionAll)
                    XCTAssertTrue((imageMessage.mentionList ?? []).count == 0)
                    XCTAssertEqual(imageMessage.text, text)
                    XCTAssertTrue(imageMessage.sendTimestamp > 0)
                    XCTAssertTrue(imageMessage.deliveredTimestamp == 0)
                    XCTAssertTrue(imageMessage.readTimestamp == 0)
                    XCTAssertFalse(imageMessage.transient)
                    XCTAssertNil(imageMessage.updatedAt)
                    XCTAssertEqual(imageMessage.size, UInt64(dataTuple.data.count))
                    XCTAssertTrue(imageMessage.height > 0)
                    XCTAssertTrue(imageMessage.width > 0)
                    XCTAssertEqual(imageMessage.format, (dataTuple.name as NSString).pathExtension)
                })
            }, failure: { XCTFail("timeout") })
            
            if let receiveFile: AVFile = receiveFile {
                self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                    semaphore.increment()
                    receiveFile.download(completionHandler: { (url: URL?, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertNotNil(url)
                        XCTAssertNil(error)
                    })
                }, failure: { XCTFail("timeout") })
            }
        }
    }
    
    func test_msg_send_type_audio() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if let normalConv: AVIMConversation = normalConv {
            
            var receiveFile: AVFile! = nil
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let text: String = "test"
                let dataTuple: (data: Data, name: String) = {
                    let filePath: String = Bundle(for: type(of: self)).path(forResource: "testAudio", ofType: "mp3")!
                    let url: URL = URL.init(fileURLWithPath: filePath)
                    let data: Data = try! Data.init(contentsOf: url)
                    return (data, "audio.mp3")
                }()
                let audioFile: AVFile = AVFile.init(data: dataTuple.data, name: dataTuple.name)
                let audioMessage: AVIMAudioMessage = AVIMAudioMessage.init(text: text, file: audioFile, attributes: nil)
                
                semaphore.increment(2)
                
                delegate_2.didReceiveTypeMessageClosure = { (conv: AVIMConversation, message: AVIMTypedMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.clientId, client_2.clientId)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.mediaType, .audio)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.status, .delivered)
                    XCTAssertNotNil(message.messageId)
                    XCTAssertEqual(message.clientId, client_1.clientId)
                    XCTAssertEqual(message.localClientId, conv.clientId)
                    XCTAssertEqual(message.conversationId, conv.conversationId)
                    XCTAssertFalse(message.mentioned)
                    XCTAssertFalse(message.mentionAll)
                    XCTAssertTrue((message.mentionList ?? []).count == 0)
                    XCTAssertEqual(message.text, text)
                    XCTAssertTrue(message.sendTimestamp > 0)
                    XCTAssertTrue(message.deliveredTimestamp == 0)
                    XCTAssertTrue(message.readTimestamp == 0)
                    XCTAssertFalse(message.transient)
                    XCTAssertNil(message.updatedAt)
                    XCTAssertEqual((message as? AVIMAudioMessage)?.size ?? 0, UInt64(dataTuple.data.count))
                    XCTAssertTrue(((message as? AVIMAudioMessage)?.duration ?? 0) > 0)
                    XCTAssertEqual((message as? AVIMAudioMessage)?.format, (dataTuple.name as NSString).pathExtension)
                    let file: AVFile? = message.file
                    XCTAssertNotNil(file)
                    if let file: AVFile = file {
                        receiveFile = file
                    }
                }
                
                normalConv.send(audioMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(audioMessage.mediaType, .audio)
                    XCTAssertEqual(audioMessage.ioType, .out)
                    XCTAssertEqual(audioMessage.status, .sent)
                    XCTAssertNotNil(audioMessage.messageId)
                    XCTAssertEqual(audioMessage.clientId, normalConv.clientId)
                    XCTAssertEqual(audioMessage.localClientId, normalConv.clientId)
                    XCTAssertEqual(audioMessage.conversationId, normalConv.conversationId)
                    XCTAssertFalse(audioMessage.mentioned)
                    XCTAssertFalse(audioMessage.mentionAll)
                    XCTAssertTrue((audioMessage.mentionList ?? []).count == 0)
                    XCTAssertEqual(audioMessage.text, text)
                    XCTAssertTrue(audioMessage.sendTimestamp > 0)
                    XCTAssertTrue(audioMessage.deliveredTimestamp == 0)
                    XCTAssertTrue(audioMessage.readTimestamp == 0)
                    XCTAssertFalse(audioMessage.transient)
                    XCTAssertNil(audioMessage.updatedAt)
                    XCTAssertEqual(audioMessage.size, UInt64(dataTuple.data.count))
                    XCTAssertTrue(audioMessage.duration > 0)
                    XCTAssertEqual(audioMessage.format, (dataTuple.name as NSString).pathExtension)
                })
            }, failure: { XCTFail("timeout") })
            
            if let receiveFile: AVFile = receiveFile {
                self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                    semaphore.increment()
                    receiveFile.download(completionHandler: { (url: URL?, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertNotNil(url)
                        XCTAssertNil(error)
                    })
                }, failure: { XCTFail("timeout") })
            }
        }
    }
    
    func test_msg_send_type_video() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if let normalConv: AVIMConversation = normalConv {
            
            var receiveFile: AVFile! = nil
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let text: String = "test"
                let dataTuple: (data: Data, name: String) = {
                    let filePath: String = Bundle(for: type(of: self)).path(forResource: "testVideo", ofType: "mp4")!
                    let url: URL = URL.init(fileURLWithPath: filePath)
                    let data: Data = try! Data.init(contentsOf: url)
                    return (data, "video.mp4")
                }()
                let videoFile: AVFile = AVFile.init(data: dataTuple.data, name: dataTuple.name)
                let videoMessage: AVIMVideoMessage = AVIMVideoMessage.init(text: text, file: videoFile, attributes: nil)
                
                semaphore.increment(2)
                
                delegate_2.didReceiveTypeMessageClosure = { (conv: AVIMConversation, message: AVIMTypedMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.clientId, client_2.clientId)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.mediaType, .video)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.status, .delivered)
                    XCTAssertNotNil(message.messageId)
                    XCTAssertEqual(message.clientId, client_1.clientId)
                    XCTAssertEqual(message.localClientId, conv.clientId)
                    XCTAssertEqual(message.conversationId, conv.conversationId)
                    XCTAssertFalse(message.mentioned)
                    XCTAssertFalse(message.mentionAll)
                    XCTAssertTrue((message.mentionList ?? []).count == 0)
                    XCTAssertEqual(message.text, text)
                    XCTAssertTrue(message.sendTimestamp > 0)
                    XCTAssertTrue(message.deliveredTimestamp == 0)
                    XCTAssertTrue(message.readTimestamp == 0)
                    XCTAssertFalse(message.transient)
                    XCTAssertNil(message.updatedAt)
                    XCTAssertEqual((message as? AVIMVideoMessage)?.size ?? 0, UInt64(dataTuple.data.count))
                    XCTAssertTrue(((message as? AVIMVideoMessage)?.duration ?? 0) > 0)
                    XCTAssertEqual((message as? AVIMVideoMessage)?.format, (dataTuple.name as NSString).pathExtension)
                    let file: AVFile? = message.file
                    XCTAssertNotNil(file)
                    if let file: AVFile = file {
                        receiveFile = file
                    }
                }
                
                normalConv.send(videoMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(videoMessage.mediaType, .video)
                    XCTAssertEqual(videoMessage.ioType, .out)
                    XCTAssertEqual(videoMessage.status, .sent)
                    XCTAssertNotNil(videoMessage.messageId)
                    XCTAssertEqual(videoMessage.clientId, normalConv.clientId)
                    XCTAssertEqual(videoMessage.localClientId, normalConv.clientId)
                    XCTAssertEqual(videoMessage.conversationId, normalConv.conversationId)
                    XCTAssertFalse(videoMessage.mentioned)
                    XCTAssertFalse(videoMessage.mentionAll)
                    XCTAssertTrue((videoMessage.mentionList ?? []).count == 0)
                    XCTAssertEqual(videoMessage.text, text)
                    XCTAssertTrue(videoMessage.sendTimestamp > 0)
                    XCTAssertTrue(videoMessage.deliveredTimestamp == 0)
                    XCTAssertTrue(videoMessage.readTimestamp == 0)
                    XCTAssertFalse(videoMessage.transient)
                    XCTAssertNil(videoMessage.updatedAt)
                    XCTAssertEqual(videoMessage.size, UInt64(dataTuple.data.count))
                    XCTAssertTrue(videoMessage.duration > 0)
                    XCTAssertEqual(videoMessage.format, (dataTuple.name as NSString).pathExtension)
                })
            }, failure: { XCTFail("timeout") })
            
            if let receiveFile: AVFile = receiveFile {
                self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                    semaphore.increment()
                    receiveFile.download(completionHandler: { (url: URL?, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertNotNil(url)
                        XCTAssertNil(error)
                    })
                }, failure: { XCTFail("timeout") })
            }
        }
    }
    
    func test_msg_send_type_file() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if let normalConv: AVIMConversation = normalConv {
            
            var receiveFile: AVFile! = nil
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let text: String = "test"
                let dataTuple: (data: Data, name: String) = {
                    let filePath: String = Bundle(for: type(of: self)).path(forResource: "testFile", ofType: "md")!
                    let url: URL = URL.init(fileURLWithPath: filePath)
                    let data: Data = try! Data.init(contentsOf: url)
                    return (data, "file.md")
                }()
                let file: AVFile = AVFile.init(data: dataTuple.data, name: dataTuple.name)
                let fileMessage: AVIMFileMessage = AVIMFileMessage.init(text: text, file: file, attributes: nil)
                
                semaphore.increment(2)
                
                delegate_2.didReceiveTypeMessageClosure = { (conv: AVIMConversation, message: AVIMTypedMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.clientId, client_2.clientId)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.mediaType, .file)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.status, .delivered)
                    XCTAssertNotNil(message.messageId)
                    XCTAssertEqual(message.clientId, client_1.clientId)
                    XCTAssertEqual(message.localClientId, conv.clientId)
                    XCTAssertEqual(message.conversationId, conv.conversationId)
                    XCTAssertFalse(message.mentioned)
                    XCTAssertFalse(message.mentionAll)
                    XCTAssertTrue((message.mentionList ?? []).count == 0)
                    XCTAssertEqual(message.text, text)
                    XCTAssertTrue(message.sendTimestamp > 0)
                    XCTAssertTrue(message.deliveredTimestamp == 0)
                    XCTAssertTrue(message.readTimestamp == 0)
                    XCTAssertFalse(message.transient)
                    XCTAssertNil(message.updatedAt)
                    let file: AVFile? = message.file
                    XCTAssertNotNil(file)
                    if let file: AVFile = file {
                        receiveFile = file
                    }
                }
                
                normalConv.send(fileMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(fileMessage.mediaType, .file)
                    XCTAssertEqual(fileMessage.ioType, .out)
                    XCTAssertEqual(fileMessage.status, .sent)
                    XCTAssertNotNil(fileMessage.messageId)
                    XCTAssertEqual(fileMessage.clientId, normalConv.clientId)
                    XCTAssertEqual(fileMessage.localClientId, normalConv.clientId)
                    XCTAssertEqual(fileMessage.conversationId, normalConv.conversationId)
                    XCTAssertFalse(fileMessage.mentioned)
                    XCTAssertFalse(fileMessage.mentionAll)
                    XCTAssertTrue((fileMessage.mentionList ?? []).count == 0)
                    XCTAssertEqual(fileMessage.text, text)
                    XCTAssertTrue(fileMessage.sendTimestamp > 0)
                    XCTAssertTrue(fileMessage.deliveredTimestamp == 0)
                    XCTAssertTrue(fileMessage.readTimestamp == 0)
                    XCTAssertFalse(fileMessage.transient)
                    XCTAssertNil(fileMessage.updatedAt)
                })
            }, failure: { XCTFail("timeout") })
            
            if let receiveFile: AVFile = receiveFile {
                self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                    semaphore.increment()
                    receiveFile.download(completionHandler: { (url: URL?, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertNotNil(url)
                        XCTAssertNil(error)
                    })
                }, failure: { XCTFail("timeout") })
            }
        }
    }
    
    func test_msg_send_type_custom() {
        
        AVIMCustomTypedMessage.registerSubclass()
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if let normalConv: AVIMConversation = normalConv {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let text: String = "test"
                let customMessage: AVIMCustomTypedMessage = AVIMCustomTypedMessage()
                customMessage.text = text
                
                semaphore.increment(2)
                
                delegate_2.didReceiveTypeMessageClosure = { (conv: AVIMConversation, message: AVIMTypedMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.clientId, client_2.clientId)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.mediaType.rawValue, AVIMCustomTypedMessage.classMediaType().rawValue)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.status, .delivered)
                    XCTAssertNotNil(message.messageId)
                    XCTAssertEqual(message.clientId, client_1.clientId)
                    XCTAssertEqual(message.localClientId, conv.clientId)
                    XCTAssertEqual(message.conversationId, conv.conversationId)
                    XCTAssertFalse(message.mentioned)
                    XCTAssertFalse(message.mentionAll)
                    XCTAssertTrue((message.mentionList ?? []).count == 0)
                    XCTAssertEqual(message.text, text)
                    XCTAssertTrue(message.sendTimestamp > 0)
                    XCTAssertTrue(message.deliveredTimestamp == 0)
                    XCTAssertTrue(message.readTimestamp == 0)
                    XCTAssertFalse(message.transient)
                    XCTAssertNil(message.updatedAt)
                }
                
                normalConv.send(customMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(customMessage.mediaType.rawValue, AVIMCustomTypedMessage.classMediaType().rawValue)
                    XCTAssertEqual(customMessage.ioType, .out)
                    XCTAssertEqual(customMessage.status, .sent)
                    XCTAssertNotNil(customMessage.messageId)
                    XCTAssertEqual(customMessage.clientId, normalConv.clientId)
                    XCTAssertEqual(customMessage.localClientId, normalConv.clientId)
                    XCTAssertEqual(customMessage.conversationId, normalConv.conversationId)
                    XCTAssertFalse(customMessage.mentioned)
                    XCTAssertFalse(customMessage.mentionAll)
                    XCTAssertTrue((customMessage.mentionList ?? []).count == 0)
                    XCTAssertEqual(customMessage.text, text)
                    XCTAssertTrue(customMessage.sendTimestamp > 0)
                    XCTAssertTrue(customMessage.deliveredTimestamp == 0)
                    XCTAssertTrue(customMessage.readTimestamp == 0)
                    XCTAssertFalse(customMessage.transient)
                    XCTAssertNil(customMessage.updatedAt)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func test_msg_send_need_receipt() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if let normalConv: AVIMConversation = normalConv {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let content: String = "test"
                let commonMessage: AVIMMessage = AVIMMessage.init(content: content)
                let option: AVIMMessageOption = AVIMMessageOption()
                option.receipt = true
                
                semaphore.increment(5)
                
                delegate_2.didReceiveCommonMessageClosure = { (conv: AVIMConversation, message: AVIMMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.clientId, client_2.clientId)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.mediaType, .none)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertNotNil(message.messageId)
                    XCTAssertEqual(message.clientId, client_1.clientId)
                    XCTAssertEqual(message.localClientId, conv.clientId)
                    XCTAssertEqual(message.conversationId, conv.conversationId)
                    XCTAssertFalse(message.mentioned)
                    XCTAssertFalse(message.mentionAll)
                    XCTAssertTrue((message.mentionList ?? []).count == 0)
                    XCTAssertEqual(message.content, content)
                    XCTAssertTrue(message.sendTimestamp > 0)
                    XCTAssertFalse(message.transient)
                    XCTAssertNil(message.updatedAt)
                    
                    conv.readInBackground()
                }
                
                delegate_1.messageDeliveredClosure = { (conv: AVIMConversation, message: AVIMMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(message === commonMessage)
                    XCTAssertEqual(message.messageId, commonMessage.messageId)
                    XCTAssertEqual(message.status, .delivered)
                    XCTAssertTrue(message.deliveredTimestamp > 0)
                }
                
                delegate_1.didUpdateForKeyClosure = { (conv: AVIMConversation, updatedKey: AVIMConversationUpdatedKey) in
                    if updatedKey == AVIMConversationUpdatedKey.lastDeliveredAt {
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertEqual(conv.lastDeliveredAt, Date(timeIntervalSince1970: TimeInterval(commonMessage.deliveredTimestamp) / 1000.0))
                    }
                    if updatedKey == AVIMConversationUpdatedKey.lastReadAt {
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertNotNil(conv.lastReadAt)
                    }
                }
                
                normalConv.send(commonMessage, option: option, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(commonMessage.mediaType, .none)
                    XCTAssertEqual(commonMessage.ioType, .out)
                    XCTAssertNotNil(commonMessage.messageId)
                    XCTAssertEqual(commonMessage.clientId, normalConv.clientId)
                    XCTAssertEqual(commonMessage.localClientId, normalConv.clientId)
                    XCTAssertEqual(commonMessage.conversationId, normalConv.conversationId)
                    XCTAssertFalse(commonMessage.mentioned)
                    XCTAssertFalse(commonMessage.mentionAll)
                    XCTAssertTrue((commonMessage.mentionList ?? []).count == 0)
                    XCTAssertEqual(commonMessage.content, content)
                    XCTAssertTrue(commonMessage.sendTimestamp > 0)
                    XCTAssertFalse(commonMessage.transient)
                    XCTAssertNil(commonMessage.updatedAt)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func test_msg_send_priority() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(3)
            client_1.createConversation(withName: nil, clientIds: clientIds, attributes: nil, options: [.transient], callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                if let conversationId: String = conv?.conversationId {
                    client_2.conversationQuery().getConversationById(conversationId, callback: { (conv1: AVIMConversation?, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertNotNil(conv1)
                        XCTAssertNil(error)
                        if let conv1: AVIMConversation = conv1 {
                            conv1.join(callback: { (succeeded: Bool, error: Error?) in
                                semaphore.decrement()
                                XCTAssertTrue(Thread.isMainThread)
                                XCTAssertTrue(succeeded)
                                XCTAssertNil(error)
                                normalConv = succeeded ? conv : nil
                            })
                        } else {
                            semaphore.decrement()
                            XCTFail()
                        }
                    })
                } else {
                    semaphore.decrement()
                    XCTFail()
                }
            })
        }, failure: { XCTFail("timeout") })
        
        if let normalConv: AVIMConversation = normalConv {
            
            let priorityArray: [AVIMMessagePriority] = [.high, .normal, .low]
            
            for item in priorityArray {
                
                self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                    
                    let content: String = "test"
                    let commonMessage: AVIMMessage = AVIMMessage.init(content: content)
                    let option: AVIMMessageOption = AVIMMessageOption()
                    option.priority = item
                    
                    semaphore.increment(2)
                    
                    delegate_2.didReceiveCommonMessageClosure = { (conv: AVIMConversation, message: AVIMMessage) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertEqual(conv.clientId, client_2.clientId)
                        XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                        XCTAssertEqual(message.mediaType, .none)
                        XCTAssertEqual(message.ioType, .in)
                        XCTAssertEqual(message.status, .delivered)
                        XCTAssertNotNil(message.messageId)
                        XCTAssertEqual(message.clientId, client_1.clientId)
                        XCTAssertEqual(message.localClientId, conv.clientId)
                        XCTAssertEqual(message.conversationId, conv.conversationId)
                        XCTAssertFalse(message.mentioned)
                        XCTAssertFalse(message.mentionAll)
                        XCTAssertTrue((message.mentionList ?? []).count == 0)
                        XCTAssertEqual(message.content, content)
                        XCTAssertTrue(message.sendTimestamp > 0)
                        XCTAssertTrue(message.deliveredTimestamp == 0)
                        XCTAssertTrue(message.readTimestamp == 0)
                        XCTAssertTrue(message.transient)
                        XCTAssertNil(message.updatedAt)
                    }
                    
                    normalConv.send(commonMessage, option: option, callback: { (succeeded: Bool, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                        XCTAssertEqual(commonMessage.mediaType, .none)
                        XCTAssertEqual(commonMessage.ioType, .out)
                        XCTAssertEqual(commonMessage.status, .sent)
                        XCTAssertNotNil(commonMessage.messageId)
                        XCTAssertEqual(commonMessage.clientId, normalConv.clientId)
                        XCTAssertEqual(commonMessage.localClientId, normalConv.clientId)
                        XCTAssertEqual(commonMessage.conversationId, normalConv.conversationId)
                        XCTAssertFalse(commonMessage.mentioned)
                        XCTAssertFalse(commonMessage.mentionAll)
                        XCTAssertTrue((commonMessage.mentionList ?? []).count == 0)
                        XCTAssertEqual(commonMessage.content, content)
                        XCTAssertTrue(commonMessage.sendTimestamp > 0)
                        XCTAssertTrue(commonMessage.deliveredTimestamp == 0)
                        XCTAssertTrue(commonMessage.readTimestamp == 0)
                        XCTAssertTrue(commonMessage.transient)
                        XCTAssertNil(commonMessage.updatedAt)
                    })
                }, failure: {
                    XCTFail("timeout")
                    XCTFail("\(item)")
                })
            }
        }
    }
    
    func test_msg_send_transient() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if let normalConv: AVIMConversation = normalConv {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let content: String = "test"
                let commonMessage: AVIMMessage = AVIMMessage.init(content: content)
                let option: AVIMMessageOption = AVIMMessageOption()
                option.transient = true
                
                semaphore.increment(2)
                
                delegate_2.didReceiveCommonMessageClosure = { (conv: AVIMConversation, message: AVIMMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.clientId, client_2.clientId)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.mediaType, .none)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.status, .delivered)
                    XCTAssertNotNil(message.messageId)
                    XCTAssertEqual(message.clientId, client_1.clientId)
                    XCTAssertEqual(message.localClientId, conv.clientId)
                    XCTAssertEqual(message.conversationId, conv.conversationId)
                    XCTAssertFalse(message.mentioned)
                    XCTAssertFalse(message.mentionAll)
                    XCTAssertTrue((message.mentionList ?? []).count == 0)
                    XCTAssertEqual(message.content, content)
                    XCTAssertTrue(message.sendTimestamp > 0)
                    XCTAssertTrue(message.deliveredTimestamp == 0)
                    XCTAssertTrue(message.readTimestamp == 0)
                    XCTAssertTrue(message.transient)
                    XCTAssertNil(message.updatedAt)
                }
                
                normalConv.send(commonMessage, option: option, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(commonMessage.mediaType, .none)
                    XCTAssertEqual(commonMessage.ioType, .out)
                    XCTAssertEqual(commonMessage.status, .sent)
                    XCTAssertNotNil(commonMessage.messageId)
                    XCTAssertEqual(commonMessage.clientId, normalConv.clientId)
                    XCTAssertEqual(commonMessage.localClientId, normalConv.clientId)
                    XCTAssertEqual(commonMessage.conversationId, normalConv.conversationId)
                    XCTAssertFalse(commonMessage.mentioned)
                    XCTAssertFalse(commonMessage.mentionAll)
                    XCTAssertTrue((commonMessage.mentionList ?? []).count == 0)
                    XCTAssertEqual(commonMessage.content, content)
                    XCTAssertTrue(commonMessage.sendTimestamp > 0)
                    XCTAssertTrue(commonMessage.deliveredTimestamp == 0)
                    XCTAssertTrue(commonMessage.readTimestamp == 0)
                    XCTAssertTrue(commonMessage.transient)
                    XCTAssertNil(commonMessage.updatedAt)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func test_msg_send_mention() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if let normalConv: AVIMConversation = normalConv {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let content: String = "test"
                let commonMessage: AVIMMessage = AVIMMessage.init(content: content)
                commonMessage.mentionAll = true
                commonMessage.mentionList = clientIds
                
                semaphore.increment(2)
                
                delegate_2.didReceiveCommonMessageClosure = { (conv: AVIMConversation, message: AVIMMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.clientId, client_2.clientId)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.mediaType, .none)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.status, .delivered)
                    XCTAssertNotNil(message.messageId)
                    XCTAssertEqual(message.clientId, client_1.clientId)
                    XCTAssertEqual(message.localClientId, conv.clientId)
                    XCTAssertEqual(message.conversationId, conv.conversationId)
                    XCTAssertTrue(message.mentioned)
                    XCTAssertTrue(message.mentionAll)
                    if let mentionList: [String] = message.mentionList {
                        XCTAssertEqual(Set(mentionList), Set(clientIds))
                    } else {
                        XCTFail()
                    }
                    XCTAssertEqual(message.content, content)
                    XCTAssertTrue(message.sendTimestamp > 0)
                    XCTAssertTrue(message.deliveredTimestamp == 0)
                    XCTAssertTrue(message.readTimestamp == 0)
                    XCTAssertFalse(message.transient)
                    XCTAssertNil(message.updatedAt)
                }
                
                normalConv.send(commonMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(commonMessage.mediaType, .none)
                    XCTAssertEqual(commonMessage.ioType, .out)
                    XCTAssertEqual(commonMessage.status, .sent)
                    XCTAssertNotNil(commonMessage.messageId)
                    XCTAssertEqual(commonMessage.clientId, normalConv.clientId)
                    XCTAssertEqual(commonMessage.localClientId, normalConv.clientId)
                    XCTAssertEqual(commonMessage.conversationId, normalConv.conversationId)
                    XCTAssertFalse(commonMessage.mentioned)
                    XCTAssertTrue(commonMessage.mentionAll)
                    XCTAssertEqual(commonMessage.mentionList, clientIds)
                    XCTAssertEqual(commonMessage.content, content)
                    XCTAssertTrue(commonMessage.sendTimestamp > 0)
                    XCTAssertTrue(commonMessage.deliveredTimestamp == 0)
                    XCTAssertTrue(commonMessage.readTimestamp == 0)
                    XCTAssertFalse(commonMessage.transient)
                    XCTAssertNil(commonMessage.updatedAt)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func test_msg_send_sync() {
        
        let clientId: String = "\(#function.substring(to: #function.index(of: "(")!))"
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        let installation_1: AVInstallation = AVInstallation()
        installation_1.deviceToken = UUID().uuidString
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientId, delegate: delegate_1, installation: installation_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        let installation_2: AVInstallation = AVInstallation()
        installation_2.deviceToken = UUID().uuidString
        guard let _: AVIMClient = self.newOpenedClient(clientId: clientId, delegate: delegate_2, installation: installation_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: [clientId, "\(clientId)_1"], callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if normalConv != nil {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let content: String = "test"
                let commonMessage: AVIMMessage = AVIMMessage.init(content: content)
                
                semaphore.increment(2)
                
                delegate_2.didReceiveCommonMessageClosure = { (conv: AVIMConversation, message: AVIMMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.clientId, clientId)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.mediaType, .none)
                    XCTAssertEqual(message.ioType, .out)
                    XCTAssertEqual(message.status, .sent)
                    XCTAssertNotNil(message.messageId)
                    XCTAssertEqual(message.clientId, clientId)
                    XCTAssertEqual(message.localClientId, clientId)
                    XCTAssertEqual(message.conversationId, conv.conversationId)
                    XCTAssertFalse(message.mentioned)
                    XCTAssertFalse(message.mentionAll)
                    XCTAssertTrue((message.mentionList ?? []).count == 0)
                    XCTAssertEqual(message.content, content)
                    XCTAssertTrue(message.sendTimestamp > 0)
                    XCTAssertTrue(message.deliveredTimestamp == 0)
                    XCTAssertTrue(message.readTimestamp == 0)
                    XCTAssertFalse(message.transient)
                    XCTAssertNil(message.updatedAt)
                }
                
                normalConv.send(commonMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(commonMessage.mediaType, .none)
                    XCTAssertEqual(commonMessage.ioType, .out)
                    XCTAssertEqual(commonMessage.status, .sent)
                    XCTAssertNotNil(commonMessage.messageId)
                    XCTAssertEqual(commonMessage.clientId, clientId)
                    XCTAssertEqual(commonMessage.localClientId, clientId)
                    XCTAssertEqual(commonMessage.conversationId, normalConv.conversationId)
                    XCTAssertFalse(commonMessage.mentioned)
                    XCTAssertFalse(commonMessage.mentionAll)
                    XCTAssertTrue((commonMessage.mentionList ?? []).count == 0)
                    XCTAssertEqual(commonMessage.content, content)
                    XCTAssertTrue(commonMessage.sendTimestamp > 0)
                    XCTAssertTrue(commonMessage.deliveredTimestamp == 0)
                    XCTAssertTrue(commonMessage.readTimestamp == 0)
                    XCTAssertFalse(commonMessage.transient)
                    XCTAssertNil(commonMessage.updatedAt)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    // MARK: - Message Read & RCP Timestamp Fetch
    
    func test_msg_read_timestamp() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        var uniqueConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, attributes: nil, options: [.unique], callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                uniqueConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if uniqueConv != nil {
            
            let messageCount: Int = 3
            
            for i in 0..<messageCount {
                
                self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                    semaphore.increment()
                    let content: String = "test_\(i)"
                    let commonMessage: AVIMMessage = AVIMMessage.init(content: content)
                    uniqueConv.send(commonMessage, callback: { (succeeded: Bool, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                    })
                }, failure: { XCTFail("timeout") })
            }
            
            let client_2: AVIMClient = AVIMClient(clientId: clientIds[1], tag: nil)
            let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
            client_2.delegate = delegate_2
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment(4)
                delegate_2.didUpdateForKeyClosure = { (conv: AVIMConversation, updatedKey: AVIMConversationUpdatedKey) in
                    if updatedKey == .unreadMessagesCount {
                        if let convId1: String = conv.conversationId,
                            let convId2: String = uniqueConv.conversationId,
                            convId1 == convId2
                        {
                            if conv.unreadMessagesCount == 0 {
                                /* unreadMessagesCount == 0 will run twice */
                                semaphore.decrement()
                                XCTAssertTrue(Thread.isMainThread)
                            } else {
                                semaphore.decrement()
                                XCTAssertTrue(Thread.isMainThread)
                                XCTAssertEqual(conv.unreadMessagesCount, UInt(messageCount))
                                conv.readInBackground()
                            }
                        }
                    }
                }
                client_2.open(with: .forceOpen, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
            }, failure: { XCTFail("timeout") })
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment(2)
                delegate_1.didUpdateForKeyClosure = { (conv: AVIMConversation, updatedKey: AVIMConversationUpdatedKey) in
                    if updatedKey == AVIMConversationUpdatedKey.lastDeliveredAt {
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertNotNil(conv.lastDeliveredAt)
                    }
                    if updatedKey == AVIMConversationUpdatedKey.lastReadAt {
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertNotNil(conv.lastReadAt)
                    }
                }
                uniqueConv.fetchReceiptTimestampsInBackground()
            }, failure: { XCTFail("timeout") })
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                client_2.close(callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    // MARK: - Messsage Patch
    
    func test_msg_modify() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2",
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1 = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let _ = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if normalConv != nil {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let content: String = "test"
                let commonMessage: AVIMMessage = AVIMMessage.init(content: content)
                commonMessage.mentionAll = true
                commonMessage.mentionList = clientIds
                
                let newContent: String = "new_test"
                let newCommonMessage: AVIMMessage = AVIMMessage.init(content: newContent)
                
                semaphore.increment(3)
                
                delegate_2.messageHasBeenUpdatedClosure = { (conv: AVIMConversation, message: AVIMMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.messageId, newCommonMessage.messageId)
                    XCTAssertEqual(message.content, newCommonMessage.content)
                    XCTAssertEqual(message.sendTimestamp, newCommonMessage.sendTimestamp)
                    XCTAssertEqual(message.clientId, newCommonMessage.clientId)
                    XCTAssertEqual(message.updatedAt, newCommonMessage.updatedAt)
                    XCTAssertTrue(message.isKind(of: type(of: newCommonMessage)))
                }
                
                normalConv.send(commonMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(commonMessage.messageId)
                    XCTAssertTrue(commonMessage.sendTimestamp > 0)
                    XCTAssertNotNil(commonMessage.clientId)
                    if succeeded {
                        XCTAssertTrue(RunLoop.current.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow: 1.0)))
                        normalConv.update(commonMessage, toNewMessage: newCommonMessage, callback: { (succeeded: Bool, error: Error?) in
                            semaphore.decrement()
                            XCTAssertTrue(Thread.isMainThread)
                            XCTAssertTrue(succeeded)
                            XCTAssertNil(error)
                            XCTAssertEqual(commonMessage.messageId, newCommonMessage.messageId)
                            XCTAssertEqual(commonMessage.sendTimestamp, newCommonMessage.sendTimestamp)
                            XCTAssertEqual(commonMessage.clientId, newCommonMessage.clientId)
                            XCTAssertNotNil(newCommonMessage.updatedAt)
                        })
                    } else {
                        semaphore.decrement()
                        XCTFail()
                    }
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func test_msg_recall() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2",
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1 = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let _ = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if normalConv != nil {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                let content: String = "test"
                let commonMessage: AVIMMessage = AVIMMessage.init(content: content)
                commonMessage.mentionAll = true
                commonMessage.mentionList = clientIds
                
                semaphore.increment(3)
                
                delegate_2.messageHasBeenUpdatedClosure = { (conv: AVIMConversation, message: AVIMMessage) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertEqual(message.messageId, commonMessage.messageId)
                    XCTAssertEqual(message.sendTimestamp, commonMessage.sendTimestamp)
                    XCTAssertEqual(message.clientId, commonMessage.clientId)
                    XCTAssertNotNil(message.updatedAt)
                    XCTAssertTrue(message.isKind(of: AVIMRecalledMessage.self))
                }
                
                normalConv.send(commonMessage, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(commonMessage.messageId)
                    XCTAssertTrue(commonMessage.sendTimestamp > 0)
                    XCTAssertNotNil(commonMessage.clientId)
                    if succeeded {
                        XCTAssertTrue(RunLoop.current.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow: 1.0)))
                        normalConv.recall(commonMessage, callback: { (succeeded: Bool, error: Error?, recalledMessage: AVIMRecalledMessage?) in
                            semaphore.decrement()
                            XCTAssertTrue(Thread.isMainThread)
                            XCTAssertTrue(succeeded)
                            XCTAssertNil(error)
                            XCTAssertNotNil(recalledMessage)
                            XCTAssertEqual(commonMessage.messageId, recalledMessage?.messageId)
                            XCTAssertEqual(commonMessage.sendTimestamp, recalledMessage?.sendTimestamp)
                            XCTAssertEqual(commonMessage.clientId, recalledMessage?.clientId)
                            XCTAssertNotNil(recalledMessage?.updatedAt)
                        })
                    } else {
                        semaphore.decrement()
                        XCTFail()
                    }
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    // MARK: - Conversation Member
    
    func test_conv_member_join_quit() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2",
            "\(#function.substring(to: #function.index(of: "(")!))_3",
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1 = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2 = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        let delegate_3: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_3 = self.newOpenedClient(clientId: clientIds[2], delegate: delegate_3) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation!
        let originClientIds: [String] = [client_1.clientId, client_2.clientId]
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(3)
            delegate_1.membersAddedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(members?.count, originClientIds.count)
                XCTAssertEqual(conv.members?.count, originClientIds.count)
                XCTAssertTrue((members ?? []).contains(client_1.clientId))
                XCTAssertTrue((members ?? []).contains(client_2.clientId))
                XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                XCTAssertEqual(byId, client_1.clientId)
            }
            delegate_2.membersAddedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(members?.count, originClientIds.count)
                XCTAssertEqual(conv.members?.count, originClientIds.count)
                XCTAssertTrue((members ?? []).contains(client_1.clientId))
                XCTAssertTrue((members ?? []).contains(client_2.clientId))
                XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                XCTAssertEqual(byId, client_1.clientId)
            }
            client_1.createConversation(withName: nil, clientIds: originClientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if normalConv != nil, let normalConvId: String = normalConv.conversationId {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(7)
                
                delegate_1.membersAddedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConvId)
                    XCTAssertEqual(members?.count, 1)
                    XCTAssertEqual(members?.first, client_3.clientId)
                    XCTAssertEqual(conv.members?.count, clientIds.count)
                    XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_3.clientId))
                    XCTAssertEqual(byId, client_3.clientId)
                }
                
                delegate_1.membersRemovedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(members?.count, 1)
                    XCTAssertEqual(members?.first, client_3.clientId)
                    XCTAssertEqual(conv.members?.count, originClientIds.count)
                    XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                    XCTAssertEqual(byId, client_3.clientId)
                }
                
                delegate_2.membersAddedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConvId)
                    XCTAssertEqual(members?.count, 1)
                    XCTAssertEqual(members?.first, client_3.clientId)
                    XCTAssertEqual(conv.members?.count, clientIds.count)
                    XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_3.clientId))
                    XCTAssertEqual(byId, client_3.clientId)
                }
                
                delegate_2.membersRemovedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(members?.count, 1)
                    XCTAssertEqual(members?.first, client_3.clientId)
                    XCTAssertEqual(conv.members?.count, originClientIds.count)
                    XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                    XCTAssertEqual(byId, client_3.clientId)
                }
                
                client_3.conversationQuery().getConversationById(normalConvId, callback: { (conv: AVIMConversation?, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertNotNil(conv)
                    XCTAssertNil(error)
                    XCTAssertNotNil(conv?.conversationId)
                    if let conv: AVIMConversation = conv {
                        conv.join(callback: { (succeeded: Bool, error: Error?) in
                            semaphore.decrement()
                            XCTAssertTrue(Thread.isMainThread)
                            XCTAssertTrue(succeeded)
                            XCTAssertNil(error)
                            XCTAssertEqual(conv.members?.count, clientIds.count)
                            XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                            XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                            XCTAssertTrue((conv.members ?? []).contains(client_3.clientId))
                            conv.quit(callback: { (suceeded: Bool, error: Error?) in
                                semaphore.decrement()
                                XCTAssertTrue(Thread.isMainThread)
                                XCTAssertTrue(succeeded)
                                XCTAssertNil(error)
                                XCTAssertEqual(conv.members?.count, originClientIds.count)
                                XCTAssertFalse((conv.members ?? []).contains(client_3.clientId))
                                XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                                XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                            })
                        })
                    }
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func test_conv_member_add_remove() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2",
            "\(#function.substring(to: #function.index(of: "(")!))_3",
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1 = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2 = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        let delegate_3: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_3 = self.newOpenedClient(clientId: clientIds[2], delegate: delegate_3) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation!
        let originClientIds: [String] = [client_1.clientId, client_2.clientId]
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(3)
            delegate_1.membersAddedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(members?.count, originClientIds.count)
                XCTAssertEqual(conv.members?.count, originClientIds.count)
                XCTAssertTrue((members ?? []).contains(client_1.clientId))
                XCTAssertTrue((members ?? []).contains(client_2.clientId))
                XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                XCTAssertEqual(byId, client_1.clientId)
            }
            delegate_2.membersAddedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(members?.count, originClientIds.count)
                XCTAssertEqual(conv.members?.count, originClientIds.count)
                XCTAssertTrue((members ?? []).contains(client_1.clientId))
                XCTAssertTrue((members ?? []).contains(client_2.clientId))
                XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                XCTAssertEqual(byId, client_1.clientId)
            }
            client_1.createConversation(withName: nil, clientIds: originClientIds, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if normalConv != nil, let normalConvId: String = normalConv.conversationId {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(8)
                
                delegate_1.membersAddedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConvId)
                    XCTAssertEqual(members?.count, 1)
                    XCTAssertEqual(members?.first, client_3.clientId)
                    XCTAssertEqual(conv.members?.count, clientIds.count)
                    XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_3.clientId))
                    XCTAssertEqual(byId, client_1.clientId)
                }
                
                delegate_1.membersRemovedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(members?.count, 1)
                    XCTAssertEqual(members?.first, client_3.clientId)
                    XCTAssertEqual(conv.members?.count, originClientIds.count)
                    XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                    XCTAssertEqual(byId, client_1.clientId)
                }
                
                delegate_2.membersAddedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConvId)
                    XCTAssertEqual(members?.count, 1)
                    XCTAssertEqual(members?.first, client_3.clientId)
                    XCTAssertEqual(conv.members?.count, clientIds.count)
                    XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_3.clientId))
                    XCTAssertEqual(byId, client_1.clientId)
                }
                
                delegate_2.membersRemovedClosure = { (conv: AVIMConversation, members: [String]?, byId: String?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(members?.count, 1)
                    XCTAssertEqual(members?.first, client_3.clientId)
                    XCTAssertEqual(conv.members?.count, originClientIds.count)
                    XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                    XCTAssertEqual(byId, client_1.clientId)
                }
                
                delegate_3.invitedByClosure = { (conv: AVIMConversation, byId: String?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConvId)
                    XCTAssertEqual(conv.members?.count, clientIds.count)
                    XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_3.clientId))
                    XCTAssertEqual(byId, client_1.clientId)
                }
                
                delegate_3.kickedByClosure = { (conv: AVIMConversation, byId: String?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.members?.count, originClientIds.count)
                    XCTAssertTrue((conv.members ?? []).contains(client_1.clientId))
                    XCTAssertTrue((conv.members ?? []).contains(client_2.clientId))
                    XCTAssertEqual(byId, client_1.clientId)
                }
                
                normalConv.addMembers(withClientIds: [client_3.clientId], callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(normalConv.members?.count, clientIds.count)
                    XCTAssertTrue((normalConv.members ?? []).contains(client_1.clientId))
                    XCTAssertTrue((normalConv.members ?? []).contains(client_2.clientId))
                    XCTAssertTrue((normalConv.members ?? []).contains(client_3.clientId))
                    normalConv.removeMembers(withClientIds: [client_3.clientId], callback: { (succeeded: Bool, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                        XCTAssertEqual(normalConv.members?.count, originClientIds.count)
                        XCTAssertTrue((normalConv.members ?? []).contains(client_1.clientId))
                        XCTAssertTrue((normalConv.members ?? []).contains(client_2.clientId))
                        XCTAssertFalse((normalConv.members ?? []).contains(client_3.clientId))
                    })
                })
                
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func test_conv_count_member() {
        
        guard let client: AVIMClient = self.newOpenedClient(clientId: "\(#function.substring(to: #function.index(of: "(")!))") else {
            XCTFail()
            return
        }
        
        var chatRoom: AVIMChatRoom! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.createChatRoom(withName: nil, attributes: nil, callback: { (conv: AVIMChatRoom?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                chatRoom = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if chatRoom != nil {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                chatRoom.countMembers(callback: { (memberCount: Int, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(memberCount, 1)
                    XCTAssertNil(error)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    // MARK: - Conversation Attribution
    
    func test_conv_attr_update() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2",
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let _: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        let keyPrefix: String = "attr"
        let key1: String = "key_1"
        let value1: String = "value_1"
        let key2: String = "key_2"
        let value2: [String: Any] = [
            "__op": "Increment",
            "amount": 1
        ]
        let key3: String = "key_3"
        let value3: [String: Any] = [
            "__op": "Delete"
        ]
        let subKey1: String = "sub_key_1"
        let subKey2: String = "sub_key_2"
        let subKey3: String = "sub_key_2"
        let subValue: String = "subValue"
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client_1.createConversation(withName: nil, clientIds: clientIds, attributes: [key3: "value_3"], options: [], callback: { (conversation: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                normalConv = conversation
            })
        }, failure: { XCTFail("timeout") })
        
        if normalConv != nil {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                normalConv["\(keyPrefix).\(key1)"] = value1
                normalConv["\(keyPrefix).\(key2)"] = value2
                normalConv["\(keyPrefix).\(key3)"] = value3
                normalConv["\(keyPrefix).\(subKey1).\(subKey2).\(subKey3)"] = subValue
                
                semaphore.increment(2)
                
                delegate_2.updateByClosure = { (conv: AVIMConversation, date: Date?, clientId: String?, data: [AnyHashable: Any]?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConv.conversationId)
                    XCTAssertNotNil(date)
                    XCTAssertEqual(clientId, client_1.clientId)
                    XCTAssertEqual(conv.attributes?[key1] as? String, value1)
                    XCTAssertEqual(conv.attributes?[key2] as? Int, 1)
                    XCTAssertNil(conv.attributes?[key3])
                    XCTAssertEqual(((conv.attributes?[subKey1] as? [String: Any])?[subKey2] as? [String: Any])?[subKey3] as? String, subValue)
                    if let attr: [String: Any] = data?[keyPrefix] as? [String: Any] {
                        XCTAssertEqual(attr[key1] as? String, value1)
                        XCTAssertEqual(attr[key2] as? Int, 1)
                        XCTAssertNil(attr[key3])
                        XCTAssertEqual(((attr[subKey1] as? [String: Any])?[subKey2] as? [String: Any])?[subKey3] as? String, subValue)
                    } else {
                        XCTFail()
                    }
                }
                
                normalConv.update(callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertEqual(normalConv.attributes?[key1] as? String, value1)
                    XCTAssertEqual(normalConv.attributes?[key2] as? Int, 1)
                    XCTAssertNil(normalConv.attributes?[key3])
                    XCTAssertEqual(((normalConv.attributes?[subKey1] as? [String: Any])?[subKey2] as? [String: Any])?[subKey3] as? String, subValue)
                })
                
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func test_conv_attr_fetch() {
        
        guard let client: AVIMClient = self.newOpenedClient(clientId: "\(#function.substring(to: #function.index(of: "(")!))") else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.createConversation(withName: nil, clientIds: [], callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if normalConv != nil {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                normalConv.fetch(callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    // MARK: - Conversation Mute
    
    func test_conv_mute_unmute() {
        
        guard let client: AVIMClient = self.newOpenedClient(clientId: "\(#function.substring(to: #function.index(of: "(")!))") else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.createConversation(withName: nil, clientIds: [], callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertNotNil(conv?.conversationId)
                normalConv = conv
            })
        }, failure: { XCTFail("timeout") })
        
        if normalConv != nil {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                normalConv.mute(callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertTrue(normalConv.muted)
                })
            }, failure: { XCTFail("timeout") })
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                normalConv.unmute(callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertFalse(normalConv.muted)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    // MARK: - Conv Query
    
    func test_conv_query() {
        
        let clientId: String = "\(#function.substring(to: #function.index(of: "(")!))"
        
        guard let client: AVIMClient = self.newOpenedClient(clientId: clientId) else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment(3)
            
            client.createConversation(withName: nil, clientIds: [clientId], callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNil(error)
                XCTAssertNotNil(conversation?.conversationId)
                
                if let conv: AVIMConversation = conversation,
                    let conversationId: String = conv.conversationId {
                    
                    let textMessage: AVIMTextMessage = AVIMTextMessage.init(text: "test", attributes: nil)
                    textMessage.mentionAll = true;
                    
                    conv.send(textMessage, callback: { (succeeded: Bool, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                        
                        if succeeded {
                            let query: AVIMConversationQuery = client.conversationQuery()
                            query.option = [.withMessage]
                            query.getConversationById(conversationId, callback: { (queryConv: AVIMConversation?, error: Error?) in
                                
                                semaphore.decrement()
                                XCTAssertTrue(Thread.isMainThread)
                                
                                XCTAssertNotNil(queryConv)
                                XCTAssertEqual(queryConv?.conversationId, conv.conversationId)
                                XCTAssertNil(error)
                            })
                        }
                    })
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
    // MARK: - Member Info
    
    func test_conv_member_info_get() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2",
            "\(#function.substring(to: #function.index(of: "(")!))_3",
        ]
        
        guard let client: AVIMClient = self.newOpenedClient(clientId: clientIds[0]) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(1)
            client.createConversation(withName: nil, clientIds: clientIds, callback: { (conversation: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                normalConv = conversation
            })
        }, failure: { XCTFail("timeout") })
        
        if normalConv != nil {
            
            for memberId in [clientIds[1], clientIds[2]] {
                self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                    semaphore.increment()
                    normalConv.updateMemberRole(withMemberId: memberId, role: .manager, callback: { (succeeded: Bool, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertTrue(succeeded)
                        XCTAssertNil(error)
                    })
                }, failure: { XCTFail("timeout") })
            }
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                normalConv.getAllMemberInfo(callback: { (memberInfos: [AVIMConversationMemberInfo]?, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertNotNil(memberInfos)
                    XCTAssertNil(error)
                    var memberIdSet: Set = Set<String>()
                    for item in memberInfos ?? [] {
                        if let memberId: String = item.memberId() {
                            memberIdSet.insert(memberId)
                        }
                    }
                    XCTAssertEqual(memberIdSet, Set<String>(clientIds))
                })
            }, failure: { XCTFail("timeout") })
            
            for memberId in clientIds {
                self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                    semaphore.increment()
                    normalConv.getMemberInfo(withMemberId: memberId, callback: { (memberInfo: AVIMConversationMemberInfo?, error: Error?) in
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertNotNil(memberInfo)
                        XCTAssertNil(error)
                        XCTAssertEqual(memberInfo?.conversationId(), normalConv.conversationId)
                        XCTAssertEqual(memberInfo?.memberId(), memberId)
                        if memberId == client.clientId {
                            XCTAssertEqual(memberInfo?.memberId(), normalConv.creator)
                            XCTAssertEqual(memberInfo?.role(), AVIMConversationMemberRole.owner)
                            XCTAssertEqual(memberInfo?.isOwner(), true)
                        } else {
                            XCTAssertEqual(memberInfo?.role(), AVIMConversationMemberRole.manager)
                            XCTAssertEqual(memberInfo?.isOwner(), false)
                        }
                    })
                }, failure: { XCTFail("timeout") })
            }
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                normalConv.getMemberInfo(withIgnoringCache: true, memberId: clientIds[1], callback: { (memberInfo: AVIMConversationMemberInfo?, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(memberInfo?.conversationId(), normalConv.conversationId)
                    XCTAssertEqual(memberInfo?.memberId(), clientIds[1])
                    XCTAssertEqual(memberInfo?.role(), AVIMConversationMemberRole.manager)
                    XCTAssertEqual(memberInfo?.isOwner(), false)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func test_conv_member_info_update() {
        
        let clientIds: [String] = [
            "\(#function.substring(to: #function.index(of: "(")!))_1",
            "\(#function.substring(to: #function.index(of: "(")!))_2",
            "\(#function.substring(to: #function.index(of: "(")!))_3",
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }

        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_2: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        let delegate_3: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_3: AVIMClient = self.newOpenedClient(clientId: clientIds[2], delegate: delegate_3) else {
            XCTFail()
            return
        }
        
        var normalConv_1: AVIMConversation! = nil
        var normalConv_2: AVIMConversation! = nil
        var normalConv_3: AVIMConversation! = nil
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment(3)
            
            delegate_2.invitedByClosure = { (conv: AVIMConversation, byClientId: String?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv.conversationId)
                normalConv_2 = conv
            }
            
            delegate_3.invitedByClosure = { (conv: AVIMConversation, byClientId: String?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conv.conversationId)
                normalConv_3 = conv
            }
            
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conversation: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                normalConv_1 = conversation
            })
        }, failure: { XCTFail("timeout") })
        
        if normalConv_1 != nil, normalConv_2 != nil, normalConv_3 != nil {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(4)
                
                delegate_1.memberInfoChangeClosure = { (conv: AVIMConversation, byClientId: String?, memberId: String?, role: AVIMConversationMemberRole) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConv_1.conversationId)
                    XCTAssertEqual(byClientId, client_1.clientId)
                    XCTAssertEqual(memberId, client_2.clientId)
                    XCTAssertEqual(role, .manager)
                }
                
                delegate_2.memberInfoChangeClosure = { (conv: AVIMConversation, byClientId: String?, memberId: String?, role: AVIMConversationMemberRole) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConv_1.conversationId)
                    XCTAssertEqual(byClientId, client_1.clientId)
                    XCTAssertEqual(memberId, client_2.clientId)
                    XCTAssertEqual(role, .manager)
                }
                
                delegate_3.memberInfoChangeClosure = { (conv: AVIMConversation, byClientId: String?, memberId: String?, role: AVIMConversationMemberRole) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConv_1.conversationId)
                    XCTAssertEqual(byClientId, client_1.clientId)
                    XCTAssertEqual(memberId, client_2.clientId)
                    XCTAssertEqual(role, .manager)
                }
                
                normalConv_1.updateMemberRole(withMemberId: client_2.clientId, role: .manager, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
            }, failure: { XCTFail("timeout") })
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                normalConv_1.updateMemberRole(withMemberId: client_1.clientId, role: .manager, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertFalse(succeeded)
                    XCTAssertNotNil(error)
                    XCTAssertEqual((error as NSError?)?.code, AVIMErrorCode.ownerPromotionNotAllowed.rawValue)
                })
            }, failure: { XCTFail("timeout") })
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                normalConv_2.updateMemberRole(withMemberId: client_3.clientId, role: .manager, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertFalse(succeeded)
                    XCTAssertNotNil(error)
                })
            }, failure: { XCTFail("timeout") })
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                normalConv_3.updateMemberRole(withMemberId: client_2.clientId, role: .member, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertFalse(succeeded)
                    XCTAssertNotNil(error)
                })
            }, failure: { XCTFail("timeout") })
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(4)
                
                delegate_1.memberInfoChangeClosure = { (conv: AVIMConversation, byClientId: String?, memberId: String?, role: AVIMConversationMemberRole) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConv_1.conversationId)
                    XCTAssertEqual(byClientId, client_1.clientId)
                    XCTAssertEqual(memberId, client_2.clientId)
                    XCTAssertEqual(role, .member)
                }
                
                delegate_2.memberInfoChangeClosure = { (conv: AVIMConversation, byClientId: String?, memberId: String?, role: AVIMConversationMemberRole) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConv_1.conversationId)
                    XCTAssertEqual(byClientId, client_1.clientId)
                    XCTAssertEqual(memberId, client_2.clientId)
                    XCTAssertEqual(role, .member)
                }
                
                delegate_3.memberInfoChangeClosure = { (conv: AVIMConversation, byClientId: String?, memberId: String?, role: AVIMConversationMemberRole) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(conv.conversationId, normalConv_1.conversationId)
                    XCTAssertEqual(byClientId, client_1.clientId)
                    XCTAssertEqual(memberId, client_2.clientId)
                    XCTAssertEqual(role, .member)
                }
                
                normalConv_1.updateMemberRole(withMemberId: client_2.clientId, role: .member, callback: { (succeeded: Bool, error: Error?) in
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    // MARK: - Member Block
    
    func test_block_unblock_member_query_blocked_member() {
        
        let cliendIds: [String] = [
            "test_conv_block_member_1",
            "test_conv_block_member_2",
            "test_conv_block_member_3",
            "test_conv_block_member_4"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: cliendIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let _: AVIMClient = self.newOpenedClient(clientId: cliendIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        let delegate_3: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let _: AVIMClient = self.newOpenedClient(clientId: cliendIds[3], delegate: delegate_3) else {
            XCTFail()
            return
        }
        
        var conversation_0: AVIMConversation!
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client_1.createConversation(withName: nil, clientIds: cliendIds, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                
                if let _conversation: AVIMConversation = conversation,
                    let _: String = conversation?.conversationId {
                    
                    conversation_0 = _conversation
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        let blockingId_1: String = cliendIds[1]
        let blockingId_2: String = cliendIds[2]
        
        if conversation_0 != nil {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(4)
                
                delegate_1.membersBlockByClosure = { (conv: AVIMConversation, byId: String?, mIds: [String]?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv.conversationId, conversation_0.conversationId)
                    XCTAssertEqual(byId, client_1.clientId)
                    XCTAssertEqual(mIds?.count, 2)
                    XCTAssertTrue((mIds ?? []).contains(blockingId_1))
                    XCTAssertTrue((mIds ?? []).contains(blockingId_2))
                }
                
                delegate_2.blockByClosure = { (conv: AVIMConversation, byId: String?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv.conversationId, conversation_0.conversationId)
                    XCTAssertEqual(byId, client_1.clientId)
                }
                
                delegate_3.membersBlockByClosure = { (conv: AVIMConversation, byId: String?, mIds: [String]?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv.conversationId, conversation_0.conversationId)
                    XCTAssertEqual(byId, client_1.clientId)
                    XCTAssertEqual(mIds?.count, 2)
                    XCTAssertTrue((mIds ?? []).contains(blockingId_1))
                    XCTAssertTrue((mIds ?? []).contains(blockingId_2))
                }
                
                conversation_0.blockMembers([blockingId_1, blockingId_2], callback: { (successfulIds: [String]?, failedIds: [AVIMOperationFailure]?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(successfulIds)
                    XCTAssertNotNil(failedIds)
                    XCTAssertNil(error)
                    
                    if let _successfulIds: [String] = successfulIds,
                        let _failedIds: [AVIMOperationFailure] = failedIds {
                        
                        XCTAssertEqual(_successfulIds.count, 2)
                        XCTAssertTrue(_successfulIds.contains(blockingId_1))
                        XCTAssertTrue(_successfulIds.contains(blockingId_2))
                        XCTAssertEqual(_failedIds.count, 0)
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(3)
                
                conversation_0.queryBlockedMembers(withLimit: 0, next: nil, callback: { (blockedIds: [String]?, next_1: String?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(blockedIds)
                    XCTAssertEqual(blockedIds?.count, 2)
                    XCTAssertTrue((blockedIds ?? []).contains(blockingId_1))
                    XCTAssertTrue((blockedIds ?? []).contains(blockingId_2))
                    XCTAssertNil(next_1)
                    XCTAssertNil(error)
                })
                
                conversation_0.queryBlockedMembers(withLimit: 1, next: nil, callback: { (blockedIds: [String]?, next_2: String?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(blockedIds)
                    XCTAssertEqual(blockedIds?.count, 1)
                    XCTAssertTrue(
                        (blockedIds?.first ?? "") == blockingId_1 ||
                            (blockedIds?.first ?? "") == blockingId_2
                    )
                    XCTAssertNotNil(next_2)
                    XCTAssertNil(error)
                    
                    conversation_0.queryBlockedMembers(withLimit: 0, next: next_2, callback: { (blockedIds_0: [String]?, next_3: String?, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotNil(blockedIds_0)
                        XCTAssertEqual(blockedIds_0?.count, 1)
                        XCTAssertTrue(
                            (blockedIds_0?.first ?? "") == blockingId_1 ||
                                (blockedIds_0?.first ?? "") == blockingId_2
                        )
                        XCTAssertNotEqual(blockedIds_0?.first, blockedIds?.first)
                        XCTAssertNil(next_3)
                        XCTAssertNil(error)
                    })
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(4)
                
                delegate_1.membersUnblockByClosure = { (conv: AVIMConversation, byId: String?, mIds: [String]?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv.conversationId, conversation_0.conversationId)
                    XCTAssertEqual(byId, client_1.clientId)
                    XCTAssertEqual(mIds?.count, 2)
                    XCTAssertTrue((mIds ?? []).contains(blockingId_1))
                    XCTAssertTrue((mIds ?? []).contains(blockingId_2))
                }
                
                delegate_2.unblockByClosure = { (conv: AVIMConversation, byId: String?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv.conversationId, conversation_0.conversationId)
                    XCTAssertEqual(byId, client_1.clientId)
                }
                
                delegate_3.membersUnblockByClosure = { (conv: AVIMConversation, byId: String?, mIds: [String]?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv.conversationId, conversation_0.conversationId)
                    XCTAssertEqual(byId, client_1.clientId)
                    XCTAssertEqual(mIds?.count, 2)
                    XCTAssertTrue((mIds ?? []).contains(blockingId_1))
                    XCTAssertTrue((mIds ?? []).contains(blockingId_2))
                }
                
                conversation_0.unblockMembers([blockingId_1, blockingId_2], callback: { (successfulIds: [String]?, failedIds: [AVIMOperationFailure]?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(successfulIds)
                    XCTAssertNotNil(failedIds)
                    XCTAssertNil(error)
                    
                    if let _successfulIds: [String] = successfulIds,
                        let _failedIds: [AVIMOperationFailure] = failedIds {
                        
                        XCTAssertEqual(_successfulIds.count, 2)
                        XCTAssertTrue(_successfulIds.contains(blockingId_1))
                        XCTAssertTrue(_successfulIds.contains(blockingId_2))
                        XCTAssertEqual(_failedIds.count, 0)
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
    func test_failure_block_member() {
        
        let clientIds: [String] = [
            "test_failure_block_member_1",
            "test_failure_block_member_2",
            "test_failure_block_member_3"
        ]
        let invalidMemberId: String = "test_failure_block_member_0"
        
        guard let client: AVIMClient = self.newOpenedClient(clientId: clientIds[0]) else {
            XCTFail()
            return
        }
        
        var aConversation: AVIMConversation!
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.createConversation(withName: nil, clientIds: clientIds, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                
                if let conv: AVIMConversation = conversation {
                    
                    aConversation = conv
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        if let conversation: AVIMConversation = aConversation {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                conversation.blockMembers([invalidMemberId], callback: { (successfulIds: [String]?, failedIds: [AVIMOperationFailure]?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(successfulIds)
                    XCTAssertEqual(successfulIds?.count, 0)
                    XCTAssertNotNil(failedIds)
                    XCTAssertEqual(failedIds?.count, 1)
                    if let operationFailure: AVIMOperationFailure = failedIds?.first {
                        XCTAssertTrue(operationFailure.code > 0)
                        XCTAssertNotNil(operationFailure.reason)
                        XCTAssertNotNil(operationFailure.clientIds)
                        XCTAssertEqual(operationFailure.clientIds?.count, 1)
                        XCTAssertEqual(operationFailure.clientIds?.first, invalidMemberId)
                    }
                    XCTAssertNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
    // MARK: - Member Mute
    
    func test_mute_unmute_member_query_muted_member() {
        
        let clientIds: [String] = [
            "test_conv_shutup_member_1",
            "test_conv_shutup_member_2",
            "test_conv_shutup_member_3",
            "test_conv_shutup_member_4"
        ]
        
        let delegate_1: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let client_1: AVIMClient = self.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let _: AVIMClient = self.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        let delegate_3: AVIMClientDelegate_TestCase = AVIMClientDelegate_TestCase()
        guard let _: AVIMClient = self.newOpenedClient(clientId: clientIds[3], delegate: delegate_3) else {
            XCTFail()
            return
        }
        
        var conversation_0: AVIMConversation!
        
        let mutingMembers: [String] = [
            clientIds[1],
            clientIds[2]
        ]
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment(5)
            
            client_1.createConversation(withName: nil, clientIds: clientIds, callback: { (conversation: AVIMConversation?, error: Error?) in
              
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                
                if let _conversation: AVIMConversation = conversation {
                    
                    conversation_0 = _conversation
                    
                    delegate_1.membersMuteByClosure = { (conversation: AVIMConversation, byClientId: String?, memberIds: [String]?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertEqual(conversation, _conversation)
                        XCTAssertNotNil(byClientId)
                        XCTAssertEqual(_conversation.clientId, byClientId)
                        XCTAssertNotNil(memberIds)
                        XCTAssertEqual(memberIds?.count, mutingMembers.count)
                        for item in (memberIds ?? []) {
                            XCTAssertTrue(mutingMembers.contains(item))
                        }
                    }
                    
                    delegate_2.muteByClosure = { (conversation: AVIMConversation, byClientId: String?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotEqual(conversation, _conversation)
                        XCTAssertNotNil(byClientId)
                        XCTAssertEqual(_conversation.clientId, byClientId)
                    }
                    
                    delegate_3.membersMuteByClosure = { (conversation: AVIMConversation, byClientId: String?, memberIds: [String]?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotEqual(conversation, _conversation)
                        XCTAssertNotNil(byClientId)
                        XCTAssertEqual(_conversation.clientId, byClientId)
                        XCTAssertNotNil(memberIds)
                        XCTAssertEqual(memberIds?.count, mutingMembers.count)
                        for item in (memberIds ?? []) {
                            XCTAssertTrue(mutingMembers.contains(item))
                        }
                    }
                    
                    _conversation.muteMembers(mutingMembers, callback: { (successfulIds: [String]?, failedIds: [AVIMOperationFailure]?, error: Error?) in
                        
                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotNil(successfulIds)
                        XCTAssertEqual(successfulIds?.count, mutingMembers.count)
                        for item in (successfulIds ?? []) {
                            XCTAssertTrue(mutingMembers.contains(item))
                        }
                        XCTAssertNotNil(failedIds)
                        XCTAssertEqual(failedIds?.count, 0)
                        XCTAssertNil(error)
                    })
                    
                } else {
                    
                    semaphore.decrement(4)
                }
            })
        }, failure: {
            
            conversation_0 = nil
            
            XCTFail("timeout")
        })
        
        if let conversation: AVIMConversation = conversation_0 {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(3)
                
                let limit: Int = 1
                
                conversation.queryMutedMembers(withLimit: limit, next: nil) { (mutedMembers_1: [String]?, next_1: String?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(mutedMembers_1)
                    XCTAssertEqual(mutedMembers_1?.count, limit)
                    for item in (mutedMembers_1 ?? []) {
                        XCTAssertTrue(mutingMembers.contains(item))
                    }
                    XCTAssertNotNil(next_1)
                    XCTAssertNil(error)
                    
                    conversation.queryMutedMembers(withLimit: 0, next: next_1, callback: { (mutedMembers_2: [String]?, next_2: String?, error: Error?) in

                        semaphore.decrement()
                        XCTAssertTrue(Thread.isMainThread)
                        
                        XCTAssertNotNil(mutedMembers_2)
                        XCTAssertEqual(mutedMembers_2?.count, mutingMembers.count - limit)
                        for item in (mutedMembers_2 ?? []) {
                            XCTAssertTrue(mutingMembers.contains(item))
                            XCTAssertFalse((mutedMembers_1 ?? []).contains(item))
                        }
                        XCTAssertNil(next_2)
                        XCTAssertNil(error)
                    })
                }
                
                conversation.queryMutedMembers(withLimit: 0, next: nil, callback: { (mutedMembers: [String]?, next: String?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(mutedMembers)
                    XCTAssertEqual(mutedMembers?.count, mutingMembers.count)
                    for item in (mutedMembers ?? []) {
                        XCTAssertTrue(mutingMembers.contains(item))
                    }
                    XCTAssertNil(next)
                    XCTAssertNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        if let conversation: AVIMConversation = conversation_0 {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment(4)
                
                delegate_1.membersUnmuteByClosure = { (conv: AVIMConversation, byClientId: String?, memberIds: [String]?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(conv, conversation)
                    XCTAssertNotNil(byClientId)
                    XCTAssertEqual(conversation.clientId, byClientId)
                    XCTAssertNotNil(memberIds)
                    XCTAssertEqual(memberIds?.count, mutingMembers.count)
                    for item in (memberIds ?? []) {
                        XCTAssertTrue(mutingMembers.contains(item))
                    }
                }
                
                delegate_2.unmuteByClosure = { (conv: AVIMConversation, byClientId: String?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotEqual(conv, conversation)
                    XCTAssertNotNil(byClientId)
                    XCTAssertEqual(conversation.clientId, byClientId)
                }
                
                delegate_3.membersUnmuteByClosure = { (conv: AVIMConversation, byClientId: String?, memberIds: [String]?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotEqual(conv, conversation)
                    XCTAssertNotNil(byClientId)
                    XCTAssertEqual(conversation.clientId, byClientId)
                    XCTAssertNotNil(memberIds)
                    XCTAssertEqual(memberIds?.count, mutingMembers.count)
                    for item in (memberIds ?? []) {
                        XCTAssertTrue(mutingMembers.contains(item))
                    }
                }
                
                conversation.unmuteMembers(mutingMembers, callback: { (successfulIds: [String]?, failedIds: [AVIMOperationFailure]?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(successfulIds)
                    XCTAssertEqual(successfulIds?.count, mutingMembers.count)
                    for item in (successfulIds ?? []) {
                        XCTAssertTrue(mutingMembers.contains(item))
                    }
                    XCTAssertNotNil(failedIds)
                    XCTAssertEqual(failedIds?.count, 0)
                    XCTAssertNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
    func test_failure_mute_member() {
        
        let clientIds: [String] = [
            "test_failure_mute_member_1",
            "test_failure_mute_member_2",
            "test_failure_mute_member_3"
        ]
        let invalidMemberId: String = "test_failure_mute_member_0"
        
        guard let client: AVIMClient = self.newOpenedClient(clientId: clientIds[0]) else {
            XCTFail()
            return
        }
        
        var aConversation: AVIMConversation!
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            client.createConversation(withName: nil, clientIds: clientIds, callback: { (conversation: AVIMConversation?, error: Error?) in
                
                semaphore.decrement()
                XCTAssertTrue(Thread.isMainThread)
                
                XCTAssertNotNil(conversation)
                XCTAssertNotNil(conversation?.conversationId)
                XCTAssertNil(error)
                
                if let conv: AVIMConversation = conversation {
                    
                    aConversation = conv
                }
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
        
        if let conversation: AVIMConversation = aConversation {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                conversation.muteMembers([invalidMemberId], callback: { (successfulIds: [String]?, failedIds: [AVIMOperationFailure]?, error: Error?) in
                    
                    semaphore.decrement()
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(successfulIds)
                    XCTAssertEqual(successfulIds?.count, 0)
                    XCTAssertNotNil(failedIds)
                    XCTAssertEqual(failedIds?.count, 1)
                    if let operationFailure: AVIMOperationFailure = failedIds?.first {
                        XCTAssertTrue(operationFailure.code > 0)
                        XCTAssertNotNil(operationFailure.reason)
                        XCTAssertNotNil(operationFailure.clientIds)
                        XCTAssertEqual(operationFailure.clientIds?.count, 1)
                        XCTAssertEqual(operationFailure.clientIds?.first, invalidMemberId)
                    }
                    XCTAssertNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
    }
    
}

class AVIMCustomTypedMessage: AVIMTypedMessage, AVIMTypedMessageSubclassing {
    
    class func classMediaType() -> AVIMMessageMediaType {
        return AVIMMessageMediaType(rawValue: 1)!
    }
    
}
