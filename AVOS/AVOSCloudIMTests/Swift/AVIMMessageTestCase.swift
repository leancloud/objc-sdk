//
//  AVIMMessageTestCase.swift
//  AVOSCloudIM-iOSTests
//
//  Created by zapcannon87 on 2018/8/7.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVIMMessageTestCase: LCIMTestBase {
    
    // MARK: - Message Send
    
    func testSendAndReceiveLargeSizeMessage() {
        let delegate1 = AVIMClientDelegateWrapper()
        let delegate2 = AVIMClientDelegateWrapper()
        guard let client1 = LCIMTestBase.newOpenedClient(clientId: uuid, delegate: delegate1),
            let client2 = LCIMTestBase.newOpenedClient(clientId: uuid, delegate: delegate2) else {
                XCTFail()
                return
        }
        var conversation: AVIMConversation!
        expecting { (exp) in
            client1.createConversation(
                withName: nil,
                clientIds: [client1.clientId, client2.clientId])
            { (conv, error) in
                if let conv = conv {
                    conversation = conv
                } else {
                    XCTAssertNil(error)
                }
                exp.fulfill()
            }
        }
        var content: String = "LargeSize"
        for _ in 0...8 {
            content += content
        }
        expecting(
            description: "send and receive message",
            count: 50)
        { (exp) in
            delegate2.didReceiveCommonMessageClosure = { (_, _) in
                exp.fulfill()
            }
            for _ in 0..<25 {
                let message = AVIMMessage(content: content)
                conversation.send(message, callback: { (succeeded: Bool, error: Error?) in
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    exp.fulfill()
                })
            }
        }
    }
    
    func testc_msg_send_common() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2"
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
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
    
    func testc_msg_send_type_text() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2"
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
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
    
    func testc_msg_send_type_location() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2"
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
                let text: String = "test"
                let latitude = 22.0
                let longitude = 33.0
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
    
    func testc_msg_send_type_image() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2"
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
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
                    XCTAssertEqual((message as? AVIMImageMessage)?.size ?? 0, Double(dataTuple.data.count))
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
                    XCTAssertEqual(imageMessage.size, Double(dataTuple.data.count))
                    XCTAssertTrue(imageMessage.height > 0)
                    XCTAssertTrue(imageMessage.width > 0)
                    XCTAssertEqual(imageMessage.format, (dataTuple.name as NSString).pathExtension)
                })
            }, failure: { XCTFail("timeout") })
            
            if let receiveFile: AVFile = receiveFile {
                RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
    
    func testc_msg_send_type_audio() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2"
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
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
                    XCTAssertEqual((message as? AVIMAudioMessage)?.size ?? 0, Double(dataTuple.data.count))
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
                    XCTAssertEqual(audioMessage.size, Double(dataTuple.data.count))
                    XCTAssertTrue(audioMessage.duration > 0)
                    XCTAssertEqual(audioMessage.format, (dataTuple.name as NSString).pathExtension)
                })
            }, failure: { XCTFail("timeout") })
            
            if let receiveFile: AVFile = receiveFile {
                RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
    
    func testc_msg_send_type_video() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2"
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
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
                    XCTAssertEqual((message as? AVIMVideoMessage)?.size ?? 0, Double(dataTuple.data.count))
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
                    XCTAssertEqual(videoMessage.size, Double(dataTuple.data.count))
                    XCTAssertTrue(videoMessage.duration > 0)
                    XCTAssertEqual(videoMessage.format, (dataTuple.name as NSString).pathExtension)
                })
            }, failure: { XCTFail("timeout") })
            
            if let receiveFile: AVFile = receiveFile {
                RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
    
    func testc_msg_send_type_file() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2"
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
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
                RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
    
    func testc_msg_send_type_custom() {
        
        if self.isServerTesting { return }
        
        AVIMCustomTypedMessage.registerSubclass()
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2"
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
                let text: String = "test"
                let customMessage: AVIMCustomTypedMessage = AVIMCustomTypedMessage()
                customMessage.text = text
                customMessage.setObject("value", forKey: "key")
                
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
                    XCTAssertEqual(message.object(forKey: "key") as? String, "value")
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
    
    func testc_msg_send_need_receipt() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2"
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
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
    
    func testc_msg_send_priority() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2"
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
                
                RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                    
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
    
    func testc_msg_send_transient() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2"
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
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
    
    func testc_msg_send_mention() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2"
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_2: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
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
    
    func testc_msg_send_sync() {
        
        if self.isServerTesting { return }
        
        let clientId: String = "\(#function[..<#function.firstIndex(of: "(")!])"
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        let installation_1: AVInstallation = AVInstallation()
        installation_1.setDeviceTokenHexString(UUID().uuidString, teamId: "LeanCloud")
        guard let client_1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId, delegate: delegate_1, installation: installation_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        let installation_2: AVInstallation = AVInstallation()
        installation_2.setDeviceTokenHexString(UUID().uuidString, teamId: "LeanCloud")
        guard let _: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId, delegate: delegate_2, installation: installation_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
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
    
    // MARK: - Messsage Patch
    
    func testc_msg_modify() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2",
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1 = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let _ = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
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
                        sleep(1)
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
    
    func testc_msg_recall() {
        
        if self.isServerTesting { return }
        
        let clientIds: [String] = [
            "\(#function[..<#function.firstIndex(of: "(")!])_1",
            "\(#function[..<#function.firstIndex(of: "(")!])_2",
        ]
        
        let delegate_1: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let client_1 = LCIMTestBase.newOpenedClient(clientId: clientIds[0], delegate: delegate_1) else {
            XCTFail()
            return
        }
        
        let delegate_2: AVIMClientDelegateWrapper = AVIMClientDelegateWrapper()
        guard let _ = LCIMTestBase.newOpenedClient(clientId: clientIds[1], delegate: delegate_2) else {
            XCTFail()
            return
        }
        
        var normalConv: AVIMConversation! = nil
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
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
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                
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
                        sleep(1)
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
    
    // MARK: - Message Query
    
    func testc_msg_query() {
        if self.isServerTesting {
            return
        }
        let clientId1: String = String(#function[..<#function.firstIndex(of: "(")!]) + "1"
        let clientId2: String = String(#function[..<#function.firstIndex(of: "(")!]) + "2"
        
        guard let client1: AVIMClient = LCIMTestBase.newOpenedClient(clientId: clientId1) else {
            XCTFail()
            return
        }
        
        guard let conversation: AVIMConversation = LCIMTestBase.newConversation(client: client1, clientIds: [clientId1, clientId2]) else {
            XCTFail()
            return
        }
        
        var sentMessages: [AVIMMessage] = []
        for _ in 0..<10 {
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                let message: AVIMMessage = AVIMMessage.init(content: "test")
                semaphore.increment()
                conversation.send(message, callback: { (succeeded: Bool, error: Error?) in
                    XCTAssertTrue(Thread.isMainThread)
                    semaphore.decrement()
                    XCTAssertTrue({ if succeeded { sentMessages.append(message) }; return succeeded }())
                    XCTAssertNil(error)
                })
            }, failure: { XCTFail("timeout") })
        }
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            conversation.queryMessagesFromServer(beforeId: sentMessages.last?.messageId, timestamp: sentMessages.last?.sendTimestamp ?? 0, limit: 10, callback: { (messages: [AVIMMessage]?, error: Error?) in
                XCTAssertTrue(Thread.isMainThread)
                semaphore.decrement()
                XCTAssertEqual(messages?.count, sentMessages.count - 1)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            conversation.queryMessagesFromServer(beforeId: sentMessages.last?.messageId, timestamp: sentMessages.last?.sendTimestamp ?? 0, toMessageId: sentMessages.first?.messageId, toTimestamp: sentMessages.first?.sendTimestamp ?? 0, limit: 10, callback: { (messages: [AVIMMessage]?, error: Error?) in
                XCTAssertTrue(Thread.isMainThread)
                semaphore.decrement()
                XCTAssertEqual(messages?.count, sentMessages.count - 2)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            let startBound: AVIMMessageIntervalBound = AVIMMessageIntervalBound(messageId: sentMessages.last?.messageId, timestamp: sentMessages.last?.sendTimestamp ?? 0, closed: true)
            let endBound: AVIMMessageIntervalBound = AVIMMessageIntervalBound(messageId: sentMessages.first?.messageId, timestamp: sentMessages.first?.sendTimestamp ?? 0, closed: true)
            let interval: AVIMMessageInterval = AVIMMessageInterval(start: startBound, end: endBound)
            conversation.queryMessages(in: interval, direction: .fromNewToOld, limit: 10, callback: { (message: [AVIMMessage]?, error: Error?) in
                XCTAssertTrue(Thread.isMainThread)
                semaphore.decrement()
                XCTAssertEqual(message?.count, sentMessages.count)
                XCTAssertNil(error)
            })
        }, failure: { XCTFail("timeout") })
    }
    
}

class AVIMCustomTypedMessage: AVIMTypedMessage, AVIMTypedMessageSubclassing {
    
    class func classMediaType() -> AVIMMessageMediaType {
        return AVIMMessageMediaType(rawValue: 1)!
    }
    
}
