//
//  LCIMConversationTestCase.swift
//  LeanCloudObjcTests
//
//  Created by 黄驿峰 on 2021/12/17.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import XCTest
import XCTest
@testable import LeanCloudObjc
import CoreMedia

extension LCIMConversationTestCase {
    
}

class LCIMConversationTestCase: RTMBaseTestCase {

    func testCreateConversationThenErrorThrows() {

        let client: LCIMClient! = try? LCIMClient.init(clientId: uuid)
        XCTAssertNotNil(client)
        expecting(description: "not open") { exp in
            client.createConversation(withClientIds: []) { conversation, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(error)
                XCTAssertNil(conversation)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            let invalidID: String = Array<String>.init(repeating: "a", count: 65).joined()
            client.createConversation(withClientIds: [invalidID]) { conversation, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(error)
                XCTAssertNil(conversation)
                exp.fulfill()
            }
        }

    }
    
    func testCreateNormalConversation() {
        let delegatorA = LCIMClientDelegator.init()
        let delegatorB = LCIMClientDelegator.init()
        let clientA = newOpenedClient(delegator: delegatorA)
        let clientB = newOpenedClient(delegator: delegatorB)
        
        let delegators = [delegatorA, delegatorB];

        let name: String? = "normalConv"
        let attribution: [String: Any] = [
            "String": "",
            "Int": 1,
            "Double": 1.0,
            "Bool": true,
            "Array": Array<String>(),
            "Dictionary": Dictionary<String, Any>()
        ]

        let convAssertion: (LCIMConversation, LCIMClient) -> Void = { conv, client in
            XCTAssertTrue(type(of: conv) == LCIMConversation.self)
            guard let convAttr = conv.attributes as? [String: Any] else {
                XCTFail()
                return
            }
//            XCTAssertEqual(conv["objectId"] as? String, conv.conversationId)
            XCTAssertEqual(conv.convType.rawValue, 1)
//            conv. == .normal
            XCTAssertEqual(conv.convType, .normal)
            XCTAssertEqual(conv.members?.count, 2)
            XCTAssertEqual(conv.members?.contains(clientA.clientId), true)
            XCTAssertEqual(conv.members?.contains(clientB.clientId), true)
            XCTAssertNotNil(conv.imClient)
            XCTAssertTrue(conv.imClient === client)
            XCTAssertEqual(conv.clientId, client.clientId)
            XCTAssertFalse(conv.unique)
            XCTAssertNil(conv.uniqueId)
            XCTAssertEqual(conv.creator, clientA.clientId)
            XCTAssertNotNil(conv.updatedAt ?? conv.createdAt)
            XCTAssertFalse(conv.muted)
            XCTAssertNil(conv.lastMessage)
            XCTAssertEqual(conv.unreadMessagesCount, 0)
            XCTAssertFalse(conv.unreadMessagesMentioned)
            if let name: String = name {
                XCTAssertEqual(name, conv.name)
            } else {
                XCTAssertNil(conv.name)
            }
            XCTAssertEqual(attribution.count, convAttr.count)
            for (key, value) in attribution {
                switch key {
                case "String":
                    XCTAssertEqual(value as? String, convAttr[key] as? String)
                case "Int":
                    XCTAssertEqual(value as? Int, convAttr[key] as? Int)
                case "Double":
                    XCTAssertEqual(value as? Double, convAttr[key] as? Double)
                case "Bool":
                    XCTAssertEqual(value as? Bool, convAttr[key] as? Bool)
                case "Array":
                    XCTAssertEqual((value as? Array<String>)?.isEmpty, true)
                    XCTAssertEqual((convAttr[key] as? Array<String>)?.isEmpty, true)
                case "Dictionary":
                    XCTAssertEqual((value as? Dictionary<String, Any>)?.isEmpty, true)
                    XCTAssertEqual((convAttr[key] as? Dictionary<String, Any>)?.isEmpty, true)
                default:
                    XCTFail()
                }
            }
        }
        
        expecting(description: "create conversation", count: 5) { exp in
            delegators.forEach {
                $0.conversationEvent = { client, conv, event in
                    XCTAssertTrue(Thread.isMainThread)
                    convAssertion(conv, client)
                    switch event {
                    case .joined(byClientID: let cID):
                        XCTAssertEqual(cID, clientA.ID)
                        exp.fulfill()
                    case .membersJoined(members: let members, byClientID: let byClientID):
                        XCTAssertEqual(byClientID, clientA.ID)
                        XCTAssertEqual(Set(members), Set([clientA.ID, clientB.ID]))
                        exp.fulfill()
                    default:
                        break
                    }
                    
                }
            }
            let options = LCIMConversationCreationOption.init()
            options.name = name
            options.attributes = attribution
            options.isUnique = false
            clientA.createConversation(withClientIds: [clientA.ID, clientB.ID], option: options) { conv, error in
                XCTAssertTrue(Thread.isMainThread)
                if let conv = conv, let client = conv.imClient {
                    convAssertion(conv, client)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }

//        delay(seconds: 5)

        XCTAssertEqual(clientA.convCollection.count, 1)
        XCTAssertEqual(clientB.convCollection.count, 1)
        XCTAssertEqual(
            clientA.convCollection.first?.value.ID,
            clientB.convCollection.first?.value.ID
        )
        XCTAssertTrue(clientA.convQueryCallbackCollection.isEmpty)
        XCTAssertTrue(clientB.convQueryCallbackCollection.isEmpty)
    }

    func testCreateNormalAndUniqueConversation() {
        let delegatorA = LCIMClientDelegator.init()
        let delegatorB = LCIMClientDelegator.init()
        let clientA = newOpenedClient(delegator: delegatorA)
        let clientB = newOpenedClient(delegator: delegatorB)
        
        let existingKey = "existingKey"
        let existingValue = "existingValue"

        let delegators = [delegatorA, delegatorB];

        expecting(description: "create unique conversation", count: 5) { exp in
            delegators.forEach {
                $0.conversationEvent = { _, _, event in
                    switch event {
                    case .joined:
                        exp.fulfill()
                    case .membersJoined:
                        exp.fulfill()
                    default:
                        break
                    }
                }
            }
            
            let options = LCIMConversationCreationOption.init()
            options.attributes = [existingKey : existingValue]
            clientA.createConversation(withClientIds: [clientA.ID, clientB.ID], option: options) { conv, error in
                XCTAssertTrue(Thread.isMainThread)
                if let conv = conv {
                    XCTAssertEqual(conv.convType, .normal)
                    XCTAssertTrue(conv.unique)
                    XCTAssertNotNil(conv.uniqueId)
                    XCTAssertEqual(conv.attributes?[existingKey] as? String, existingValue)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }

        delegatorA.conversationEvent = nil
        delegatorB.conversationEvent = nil

        delay(seconds: 5)

        clientB.convCollection.removeAll()
        
        expecting(description: "recreate unique conversation") { exp in
            clientB.createConversation(withClientIds: [clientA.ID, clientB.ID]) { conv, error in
                if let conv = conv {
                    XCTAssertEqual(conv.convType, .normal)
                    XCTAssertTrue(conv.unique)
                    XCTAssertNotNil(conv.uniqueId)
                    XCTAssertNil(conv.attributes?[existingKey])
                    conv.fetch { ret, error in
                        XCTAssertNil(error)
                        XCTAssertTrue(ret)
                        XCTAssertEqual(conv.attributes?[existingKey] as? String, existingValue)
                        exp.fulfill()
                    }
                } else {
                    XCTFail()
                    exp.fulfill()
                }
            }
        }


        XCTAssertEqual(
            clientA.convCollection.first?.value.ID,
            clientB.convCollection.first?.value.ID
        )
        XCTAssertEqual(
            clientA.convCollection.first?.value.uniqueID,
            clientB.convCollection.first?.value.uniqueID
        )

    }

    func testCreateChatRoom() {
        let client = newOpenedClient()
        expecting(description: "create chat room") { exp in
            client.createChatRoom { chatRoom, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(chatRoom?.convType, .transient)
                XCTAssertEqual(chatRoom?.convType.rawValue, 2)
                XCTAssertEqual(chatRoom?.members?.count, 1)
                exp.fulfill()
            }
        }
    }

    func testCreateTemporaryConversation() {
        let delegatorA = LCIMClientDelegator.init()
        let delegatorB = LCIMClientDelegator.init()
        let clientA = newOpenedClient(delegator: delegatorA)
        let clientB = newOpenedClient(delegator: delegatorB)
        let delegators = [delegatorA, delegatorB];

        let ttl: Int32 = 3600
        expecting(description: "create conversation", count: 5) { exp in
            delegators.forEach {
                $0.conversationEvent = { client, conv, event in
                    XCTAssertEqual(conv.convType, .temporary)
                    XCTAssertEqual((conv as? LCIMTemporaryConversation)?.timeToLive, Int(ttl))
                    switch event {
                    case .joined(byClientID: let cID):
                        XCTAssertEqual(cID, clientA.ID)
                        exp.fulfill()
                    case .membersJoined(members: let members, byClientID: let byClientID):
                        XCTAssertEqual(byClientID, clientA.ID)
                        XCTAssertEqual(Set(members), Set([clientA.ID, clientB.ID]))
                        exp.fulfill()
                    default:
                        break
                    }
                }
            }
            let options = LCIMConversationCreationOption.init()
            options.timeToLive = UInt(ttl)
            clientA.createTemporaryConversation(withClientIds: [clientA.ID, clientB.ID], option: options) { conv, error in
                if let conv = conv {
                    XCTAssertEqual(conv.convType, .temporary)
                    XCTAssertEqual(conv.rawJSONDataCopy()["objectId"] as? String, conv.ID)
                    XCTAssertEqual(conv.convType.rawValue, 4)
                    XCTAssertEqual(conv.timeToLive, Int(ttl))
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }

        XCTAssertEqual(
            clientA.convCollection.first?.value.ID,
            clientB.convCollection.first?.value.ID
        )
        XCTAssertEqual(
            clientA.convCollection.first?.value.ID.hasPrefix(kTemporaryConversationIdPrefix),
            true
        )
    }

    func testServiceConversationSubscription() {
        let client = newOpenedClient()
        let serviceConversationID = newServiceConversation()
        var serviceConversation: LCIMServiceConversation!
        expecting { (exp) in
            client.conversationQuery().getConversationById(serviceConversationID) { conv, error in
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                XCTAssertEqual(conv?.rawJSONDataCopy()["objectId"] as? String, conv?.ID)
                XCTAssertEqual(conv?.convType.rawValue, 3)
                serviceConversation = conv as? LCIMServiceConversation
                exp.fulfill()
            }
        }
        XCTAssertNotNil(serviceConversation)

        expecting(
            description: "service conversation subscription",
            count: 1)
        { (exp) in
            serviceConversation.subscribe { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        let query = client.conversationQuery()
        expecting { exp in
            query.getConversationById(serviceConversationID) { conv, error in
                XCTAssertNil(error)
                if let conv = conv {
                    XCTAssertEqual(conv.muted, false)
                    XCTAssertNotNil(conv.rawJSONDataCopy()["joinedAt"])
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }
    }

    func testNormalConversationUnreadEvent() {
        let clientA = newOpenedClient()

        let clientBID = uuid

        var conversation1: LCIMConversation!
        var conversation2: LCIMConversation!

        let message1 = LCIMMessage.init(content: uuid)
        let message2 = LCIMMessage.init(content: uuid)
        
        expecting(
            description: "create conversation, then send message",
            count: 4)
        { (exp) in
            let option = LCIMConversationCreationOption.init()
            option.isUnique = false
            clientA.createConversation(withClientIds: [clientBID], option: option) { conv1, error in
                XCTAssertNil(error)
                XCTAssertNotNil(conv1)
                conversation1 = conv1
                exp.fulfill()
                conv1?.send(message1, callback: { ret, error in
                    XCTAssertNil(error)
                    XCTAssertTrue(ret)
                    exp.fulfill()
                    clientA.createConversation(withClientIds: [clientBID], option: option) { conv2, error in
                        XCTAssertNil(error)
                        XCTAssertNotNil(conv2)
                        conversation2 = conv2
                        exp.fulfill()
                        conv2?.send(message2, callback: { ret, error in
                            XCTAssertNil(error)
                            XCTAssertTrue(ret)
                            exp.fulfill()
                        })
                    }
                })
            }
        }
        
        delay()

        XCTAssertNotNil(conversation1)
        XCTAssertNotNil(conversation2)

        LCRTMConnectionManager.shared().imProtobuf1Registry.removeAllObjects()
        LCRTMConnectionManager.shared().imProtobuf3Registry.removeAllObjects()
        
        let delegatorB = LCIMClientDelegator.init()
        let clientB: LCIMClient! = try? LCIMClient.init(clientId: clientBID)
        XCTAssertNotNil(clientB)
        clientB.delegate = delegatorB

        expecting(
            description: "open, then receive unread event",
            count: 5)
        { (exp) in
            delegatorB.conversationEvent = { client, conversation, event in
                if conversation.ID == conversation1.ID {
                    switch event {
                    case .lastMessageUpdated:
                        let lastMessage = conversation.lastMessage
                        XCTAssertEqual(lastMessage?.conversationID, message1.conversationID)
                        XCTAssertEqual(lastMessage?.sentTimestamp, message1.sentTimestamp)
                        XCTAssertEqual(lastMessage?.ID, message1.ID)
                        exp.fulfill()
                    case .unreadMessageCountUpdated:
                        XCTAssertEqual(conversation.unreadMessageCount, 1)
//                        XCTAssertTrue(conversation.isUnreadMessageContainMention)
                        exp.fulfill()
                    default:
                        break
                    }
                } else if conversation.ID == conversation2.ID {
                    switch event {
                    case .lastMessageUpdated:
                        let lastMessage = conversation.lastMessage
                        XCTAssertEqual(lastMessage?.conversationID, message2.conversationID)
                        XCTAssertEqual(lastMessage?.sentTimestamp, message2.sentTimestamp)
                        XCTAssertEqual(lastMessage?.ID, message2.ID)
                        exp.fulfill()
                    case .unreadMessageCountUpdated:
                        XCTAssertEqual(conversation.unreadMessageCount, 1)
                        XCTAssertFalse(conversation.isUnreadMessageContainMention)
                        exp.fulfill()
                    default:
                        break
                    }
                }
            }
            clientB.open { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }

        expecting { (exp) in
            delegatorB.clientEvent = { client, event in
                switch event {
                case .sessionDidPause:
                    exp.fulfill()
                default:
                    break
                }
            }
            clientB.connection.disconnect()
        }

        delay()
        XCTAssertTrue(clientB.lastUnreadNotifTime != 0)

        let message3 = LCIMMessage.init(content: uuid)

        expecting { (exp) in
            conversation1.send(message3, callback: { ret, error in
                XCTAssertNil(error)
                XCTAssertTrue(ret)
                exp.fulfill()
            })
        }

        expecting(
            description: "reconnect, then receive unread event",
            count: 3)
        { (exp) in
            delegatorB.clientEvent = { client, event in
                switch event {
                case .sessionDidOpen:
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conversation, event in
                if conversation.ID == conversation1.ID {
                    switch event {
                    case .lastMessageUpdated:
                        let lastMessage = conversation.lastMessage
                        XCTAssertEqual(lastMessage?.conversationID, message3.conversationID)
                        XCTAssertEqual(lastMessage?.sentTimestamp, message3.sentTimestamp)
                        XCTAssertEqual(lastMessage?.ID, message3.ID)
                        exp.fulfill()
                    case .unreadMessageCountUpdated:
                        XCTAssertEqual(conversation.unreadMessageCount, 2)
//                        XCTAssertTrue(conversation.isUnreadMessageContainMention)
                        exp.fulfill()
                    default:
                        break
                    }
                }
            }
            clientB.connection.testConnect()
        }

        expecting(
            description: "read",
            count: 2)
        { (exp) in
            delegatorB.conversationEvent = { client, conversation, event in
                if conversation.ID == conversation1.ID {
                    switch event {
                    case .unreadMessageCountUpdated:
                        XCTAssertEqual(conversation.unreadMessageCount, 0)
                        exp.fulfill()
                    default:
                        break
                    }
                } else if conversation.ID == conversation2.ID {
                    switch event {
                    case .unreadMessageCountUpdated:
                        XCTAssertEqual(conversation.unreadMessageCount, 0)
                        exp.fulfill()
                    default:
                        break
                    }
                }
            }
            for (_, conv) in clientB.convCollection {
                conv.read()
            }
        }
    }

    func testTemporaryConversationUnreadEvent() {
        let clientA = newOpenedClient()

        let otherClientID: String = uuid
        let message = LCIMMessage.init(content: "test")
        message.isAllMembersMentioned = true
        
        expecting(description: "create temporary conversation and send message", count: 2) { exp in
            let options = LCIMConversationCreationOption.init()
            options.timeToLive = 3600
            clientA.createTemporaryConversation(withClientIds: [otherClientID], option: options) { conv, error in
                XCTAssertNil(error)
                XCTAssertNotNil(conv)
                conv?.send(message, callback: { ret, error in
                    XCTAssertNil(error)
                    XCTAssertTrue(ret)
                    exp.fulfill()
                })
                exp.fulfill()
            }
        }
        
        let delegator = LCIMClientDelegator.init()
        let clientB: LCIMClient! = try? LCIMClient.init(clientId: otherClientID)
        XCTAssertNotNil(clientB)
        clientB.delegate = delegator

        expecting(description: "opened and get unread event", count: 3) { exp in
            delegator.conversationEvent = { client, conversation, event in
                if client === clientB, conversation.ID == message.conversationID {
                    switch event {
                    case .lastMessageUpdated:
                        XCTAssertEqual(conversation.lastMessage?.conversationID, message.conversationID)
                        XCTAssertEqual(conversation.lastMessage?.sentTimestamp, message.sentTimestamp)
                        XCTAssertEqual(conversation.lastMessage?.ID, message.ID)
                        exp.fulfill()
                    case .unreadMessageCountUpdated:
                        XCTAssertEqual(conversation.unreadMessageCount, 1)
                        XCTAssertTrue(conversation.isUnreadMessageContainMention)
                        exp.fulfill()
                    default:
                        break
                    }
                }
            }
            clientB.open { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        expecting(description: "read") { exp in
            delegator.conversationEvent = { client, conversation, event in
                if client === clientB, conversation.ID == message.conversationID {
                    if case .unreadMessageCountUpdated = event {
                        XCTAssertEqual(conversation.unreadMessageCount, 0)
                        exp.fulfill()
                    }
                }
            }
            for (_, conv) in clientB.convCollection {
                conv.read()
            }
        }

    }

    func testServiceConversationUnreadEvent() {

        let clientID = uuid

        let serviceConvID = newServiceConversation()
        XCTAssertTrue(subscribing(serviceConversation: serviceConvID, by: clientID))
        broadcastingMessage(to: serviceConvID)

        delay(seconds: 15)

        let delegator = LCIMClientDelegator.init()
        let clientA: LCIMClient! = try? LCIMClient.init(clientId: clientID)
        XCTAssertNotNil(clientA)
        clientA.delegate = delegator
        
        expecting(description: "opened and get unread event", count: 3) { exp in
            delegator.conversationEvent = { client, conversation, event in
                if client === clientA, conversation.ID == serviceConvID {
                    switch event {
                    case .lastMessageUpdated:
                        exp.fulfill()
                    case .unreadMessageCountUpdated:
                        exp.fulfill()
                    default:
                        break
                    }
                }
            }
            clientA.open { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }

        expecting(description: "read") { exp in
            delegator.conversationEvent = { client, conversation, event in
                if client === clientA, conversation.ID == serviceConvID {
                    if case .unreadMessageCountUpdated = event {
                        XCTAssertEqual(conversation.unreadMessageCount, 0)
                        exp.fulfill()
                    }
                }
            }
            for (_, conv) in clientA.convCollection {
                conv.read()
            }
        }

    }

    func testLargeUnreadEvent() {
        let clientA = newOpenedClient()

        let otherClientID: String = uuid
        let count: Int = 20

        for i in 0..<count {
            let exp = expectation(description: "create conversation and send message")
            exp.expectedFulfillmentCount = 2
            let message = LCIMMessage.init(content: "test")
            if i % 2 == 0 {
                let options = LCIMConversationCreationOption.init()
                options.timeToLive = 3600
                clientA.createTemporaryConversation(withClientIds: [otherClientID], option: options) { conv, error in
                    XCTAssertNil(error)
                    XCTAssertNotNil(conv)
                    conv?.send(message, callback: { ret, error in
                        XCTAssertNil(error)
                        XCTAssertTrue(ret)
                        exp.fulfill()
                    })
                    exp.fulfill()
                }
                wait(for: [exp], timeout: timeout)
            } else {
                let option = LCIMConversationCreationOption.init()
                option.isUnique = false
                clientA.createConversation(withClientIds: [otherClientID], option: option) { conv, error in
                    XCTAssertNil(error)
                    XCTAssertNotNil(conv)
                    conv?.send(message, callback: { ret, error in
                        XCTAssertNil(error)
                        XCTAssertTrue(ret)
                        exp.fulfill()
                    })
                    exp.fulfill()
                }
                wait(for: [exp], timeout: timeout)
            }
        }

        let convIDSet = Set<String>(clientA.convCollection.keys)
        let delegator = LCIMClientDelegator.init()
        let clientB: LCIMClient! = try? LCIMClient.init(clientId: otherClientID)
        XCTAssertNotNil(clientB)
        clientB.delegate = delegator
        
        let largeUnreadExp = expectation(description: "opened and get large unread event")
        largeUnreadExp.expectedFulfillmentCount = (count + 2) + 1
//        var lcount = 0
//        var ucount = 0
        delegator.conversationEvent = { client, conversaton, event in
            switch event {
            case .lastMessageUpdated:
//                lcount += 1
//                print("lastMessageUpdated count---\(lcount)")
                largeUnreadExp.fulfill()
            case .unreadMessageCountUpdated:
//                ucount += 1
//                print("unreadMessageCountUpdated count---\(ucount)")
                largeUnreadExp.fulfill()
            default:
                break
            }
        }
        clientB.open { ret, error in
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            largeUnreadExp.fulfill()
        }
        wait(for: [largeUnreadExp], timeout: timeout)

        delay()
        XCTAssertNotNil(clientB.lastUnreadNotifTime)

        let allReadExp = expectation(description: "all read")
        allReadExp.expectedFulfillmentCount = count
        delegator.conversationEvent = { client, conversation, event in
            if client === clientB, convIDSet.contains(conversation.ID) {
                if case .unreadMessageCountUpdated = event {
                    allReadExp.fulfill()
                }
            }
        }
        for (_, conv) in clientB.convCollection {
            conv.read()
        }
        wait(for: [allReadExp], timeout: timeout)
    }

    func testMembersChange() {
        let delegatorA = LCIMClientDelegator.init()
        let delegatorB = LCIMClientDelegator.init()
        let clientA = newOpenedClient(delegator: delegatorA)
        let clientB = newOpenedClient(delegator: delegatorB)

        var convA: LCIMConversation!

        expecting(
            description: "create conversation",
            count: 5)
        { (exp) in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .joined(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                case let .membersJoined(members: members, byClientID: byClientID):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientA.ID))
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .joined(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                case let .membersJoined(members: members, byClientID: byClientID):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientA.ID))
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }
            clientA.createConversation(withClientIds: [clientB.ID]) { conv, error in
                XCTAssertNil(error)
                XCTAssertNotNil(conv)
                convA = conv
                exp.fulfill()
            }
        }

        let convB = clientB.convCollection[convA?.ID ?? ""]
        XCTAssertNotNil(convB)

        expecting(
            description: "leave",
            count: 3)
        { (exp) in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersLeft(members: members, byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientB.ID)
                    XCTAssertEqual(members.count, 1)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertEqual(conv.members?.count, 1)
                    XCTAssertEqual(conv.members?.first, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .left(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientB.ID)
                    XCTAssertEqual(conv.members?.count, 1)
                    XCTAssertEqual(conv.members?.first, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }
            convB?.quit(callback: { ret, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
        }

        expecting(
            description: "join",
            count: 4)
        { (exp) in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersJoined(members: members, byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientB.ID)
                    XCTAssertEqual(members.count, 1)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertEqual(conv.members?.count, 2)
                    XCTAssertEqual(conv.members?.contains(clientA.ID), true)
                    XCTAssertEqual(conv.members?.contains(clientB.ID), true)
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .joined(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientB.ID)
                    XCTAssertEqual(conv.members?.count, 2)
                    XCTAssertEqual(conv.members?.contains(clientA.ID), true)
                    XCTAssertEqual(conv.members?.contains(clientB.ID), true)
                    exp.fulfill()
                case let .membersJoined(members: members, byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientB.ID)
                    XCTAssertEqual(members.count, 1)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertEqual(conv.members?.count, 2)
                    XCTAssertEqual(conv.members?.contains(clientA.ID), true)
                    XCTAssertEqual(conv.members?.contains(clientB.ID), true)
                    exp.fulfill()
                default:
                    break
                }
            }
            convB?.join { ret, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }

        expecting(
            description: "remove",
            count: 3)
        { (exp) in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersLeft(members: members, byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(members.count, 1)
                    XCTAssertEqual(members.first, clientB.ID)
                    XCTAssertEqual(conv.members?.count, 1)
                    XCTAssertEqual(conv.members?.first, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .left(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(conv.members?.count, 1)
                    XCTAssertEqual(conv.members?.first, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }
            convA?.removeMembers(withClientIds: [clientB.ID]) { ret, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }

        expecting(
            description: "add",
            count: 4)
        { (exp) in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersJoined(members: members, byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(members.count, 1)
                    XCTAssertEqual(members.first, clientB.ID)
                    XCTAssertEqual(conv.members?.count, 2)
                    XCTAssertEqual(conv.members?.contains(clientA.ID), true)
                    XCTAssertEqual(conv.members?.contains(clientB.ID), true)
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .joined(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(conv.members?.count, 2)
                    XCTAssertEqual(conv.members?.contains(clientA.ID), true)
                    XCTAssertEqual(conv.members?.contains(clientB.ID), true)
                    exp.fulfill()
                case let .membersJoined(members: members, byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(members.count, 1)
                    XCTAssertEqual(members.first, clientB.ID)
                    XCTAssertEqual(conv.members?.count, 2)
                    XCTAssertEqual(conv.members?.contains(clientA.ID), true)
                    XCTAssertEqual(conv.members?.contains(clientB.ID), true)
                    exp.fulfill()
                default:
                    break
                }
            }
            convA?.addMembers(withClientIds: [clientB.ID], callback: { ret, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
        }

        expecting { (exp) in
            convA?.countMembers(callback: { num, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertEqual(num, 2);
                exp.fulfill()
            })
        }
    }

    func testGetChatRoomOnlineMembers() {
        let clientA = newOpenedClient()
        let clientB = newOpenedClient()

        var chatRoomA: LCIMChatRoom?

        expecting { (exp) in
            clientA.createChatRoom { room, error in
                XCTAssertNil(error)
                XCTAssertNotNil(room)
                chatRoomA = room
                exp.fulfill()
            }
        }

        var chatRoomB: LCIMChatRoom?

        expecting { (exp) in
            if let ID = chatRoomA?.ID {
                clientB.conversationQuery().getConversationById(ID) { conv, error in
                    XCTAssertNil(error)
                    XCTAssertNotNil(conv)
                    chatRoomB = conv as? LCIMChatRoom
                    exp.fulfill()
                }
            } else {
                XCTFail()
                exp.fulfill()
            }
        }

        expecting(
            description: "get online count",
            count: 7)
        { (exp) in
            chatRoomA?.countMembers(callback: { num, error in
                XCTAssertNil(error)
                XCTAssertEqual(num, 1);
                exp.fulfill()
                chatRoomB?.join(callback: { ret, error in
                    XCTAssertNil(error)
                    XCTAssertTrue(ret)
                    exp.fulfill()
                    self.delay()
                    chatRoomA?.countMembers(callback: { num, error in
                        XCTAssertNil(error)
                        XCTAssertEqual(num, 2);
                        exp.fulfill()
                        chatRoomA?.getAllMemberInfo(callback: { memberInfos, error in
                            XCTAssertNil(error)
                            //???
                            XCTAssertEqual(memberInfos?.count, 1)
                            exp.fulfill()
                            chatRoomB?.quit(callback: { ret, error in
                                XCTAssertTrue(ret)
                                XCTAssertNil(error)
                                exp.fulfill()
                                self.delay()
                                chatRoomA?.countMembers(callback: { num, error in
                                    XCTAssertNil(error)
                                    XCTAssertEqual(num, 1);
                                    exp.fulfill()
                                    chatRoomA?.getAllMemberInfo(callback: { memberInfos, error in
                                        XCTAssertNil(error)
                                        XCTAssertEqual(memberInfos?.count, 1)
                                        exp.fulfill()
                                    })
                                })
                            })
                        })
                    })
                })
            })
        }
    }

    func testMuteAndUnmute() {
        let client = newOpenedClient()

        var conversation: LCIMConversation? = nil
//        var previousUpdatedAt: Date?

        let createExp = expectation(description: "create conversation")
        let option = LCIMConversationCreationOption.init()
        option.isUnique = false
        client.createConversation(withClientIds: [uuid, uuid], option: option) { conv, error in
            XCTAssertNil(error)
            XCTAssertNotNil(conv)
            conversation = conv
//            previousUpdatedAt = conversation?.updatedAt ?? conversation?.createdAt
            createExp.fulfill()
        }
        
        wait(for: [createExp], timeout: timeout)

        delay()

        let muteExp = expectation(description: "mute")
        conversation?.mute(callback: {[weak conversation] ret, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            XCTAssertEqual(conversation?.isMuted, true)
            let mutedMembers = conversation?.rawJSONDataCopy()[LCIMConversationKey.mutedMembers] as? [String]
            XCTAssertEqual(mutedMembers?.count, 1)
            XCTAssertEqual(mutedMembers?.contains(client.ID), true)
//            if let updatedAt = conversation?.updatedAt, let preUpdatedAt = previousUpdatedAt {
//                XCTAssertGreaterThan(updatedAt, preUpdatedAt)
//                previousUpdatedAt = updatedAt
//            } else {
//                XCTFail()
//            }
            muteExp.fulfill()
        })
        wait(for: [muteExp], timeout: timeout)

        delay()

        let unmuteExp = expectation(description: "unmute")
        conversation?.unmute(callback: { [weak conversation] ret, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            XCTAssertEqual(conversation?.isMuted, false)
            let mutedMembers = conversation?.rawJSONDataCopy()[LCIMConversationKey.mutedMembers] as? [String]
            XCTAssertEqual(mutedMembers?.count, 0)
//            if let updatedAt = conversation?.updatedAt, let preUpdatedAt = previousUpdatedAt {
//                XCTAssertGreaterThan(updatedAt, preUpdatedAt)
//                previousUpdatedAt = updatedAt
//            } else {
//                XCTFail()
//            }
            unmuteExp.fulfill()
        })
        wait(for: [unmuteExp], timeout: timeout)
    }

    func testConversationQuery() {
        let clientA = newOpenedClient()

        var ID1: String? = nil
        var ID2: String? = nil
        var ID3: String? = nil
        var ID4: String? = nil
        for i in 0...3 {
            switch i {
            case 0:
                let createExp = expectation(description: "create normal conversation")
                createExp.expectedFulfillmentCount = 2
                let option = LCIMConversationCreationOption.init()
                option.isUnique = false
                clientA.createConversation(withClientIds: [uuid], option: option) { conv, error in
                    XCTAssertNil(error)
                    XCTAssertNotNil(conv)
                    ID1 = conv?.ID
                    let message = LCIMMessage.init(content: "test")
                    conv?.send(message, callback: { ret, error in
                        XCTAssertNil(error)
                        XCTAssertTrue(ret)
                        createExp.fulfill()
                    })
                    createExp.fulfill()
                }
                wait(for: [createExp], timeout: timeout)
            case 1:
                let createExp = expectation(description: "create chat room")
                clientA.createChatRoom { room, error in
                    XCTAssertNil(error)
                    XCTAssertNotNil(room)
                    ID2 = room?.ID
                    createExp.fulfill()
                }
                wait(for: [createExp], timeout: timeout)
            case 2:
                let ID = newServiceConversation()
                XCTAssertNotNil(ID)
                ID3 = ID
            case 3:
                let createExp = expectation(description: "create temporary conversation")
                let options = LCIMConversationCreationOption.init()
                options.timeToLive = 3600
                clientA.createTemporaryConversation(withClientIds: [uuid], option: options) { conv, error in
                    XCTAssertNil(error)
                    XCTAssertNotNil(conv)
                    ID4 = conv?.ID
                    createExp.fulfill()
                }
                wait(for: [createExp], timeout: timeout)
            default:
                break
            }
        }

        guard
            let normalConvID = ID1,
            let chatRoomID = ID2,
            let serviceID = ID3,
            let tempID = ID4
            else
        {
            XCTFail()
            return
        }

        delay()
        clientA.convCollection.removeAll()

        let queryExp1 = expectation(description: "query normal conversation with message and without member")
        let query1 = clientA.conversationQuery()
        query1.option = [.compact, .withMessage]
        query1.getConversationById(normalConvID) { conv, error in
            XCTAssertNil(error)
            XCTAssertNotNil(conv)
            XCTAssertEqual(conv?.convType, .normal)
            XCTAssertEqual(conv?.members ?? [], [])
            XCTAssertNotNil(conv?.lastMessage)
            queryExp1.fulfill()
        }
        wait(for: [queryExp1], timeout: timeout)

        let queryExp2 = expectation(description: "query chat room")
        clientA.conversationQuery().getConversationById(chatRoomID) { conv, error in
            XCTAssertNil(error)
            XCTAssertNotNil(conv)
            XCTAssertEqual(conv?.convType, .transient)
            queryExp2.fulfill()
        }
        wait(for: [queryExp2], timeout: timeout)

        let queryExp3 = expectation(description: "query service conversation")
        clientA.conversationQuery().getConversationById(serviceID) { conv, error in
            XCTAssertNil(error)
            XCTAssertNotNil(conv)
            XCTAssertEqual(conv?.convType, .system)
            queryExp3.fulfill()
        }
        wait(for: [queryExp3], timeout: timeout)

        clientA.convCollection.removeAll()

        let queryTempExp = expectation(description: "query temporary conversation")
        clientA.conversationQuery().findTemporaryConversations(with: [tempID]) { conv, error in
            XCTAssertNil(error)
            XCTAssertNotNil(conv)
            XCTAssertEqual(conv?.count, 1)
            if let tmpConv = conv?.first {
                XCTAssertEqual(tmpConv.convType.rawValue, 4)
            } else {
                XCTFail()
            }
            queryTempExp.fulfill()
        }
        wait(for: [queryTempExp], timeout: timeout)

        clientA.convCollection.removeAll()

        let generalQueryExp1 = expectation(description: "general query with default conditon")
        clientA.conversationQuery().findConversations { convs, error in
            XCTAssertNil(error)
            XCTAssertEqual(convs?.count, 1)
            XCTAssertEqual(convs?.first?.convType, .normal)
            XCTAssertEqual(convs?.first?.members?.contains(clientA.ID), true)
            generalQueryExp1.fulfill()
        }
        wait(for: [generalQueryExp1], timeout: timeout)

        let generalQueryExp2 = expectation(description: "general query with custom conditon")
        let generalQuery1 = clientA.conversationQuery()
        generalQuery1.whereKey(LCIMConversationKey.transient.rawValue, equalTo: true)
        let generalQuery2 = clientA.conversationQuery()
        generalQuery2.whereKey(LCIMConversationKey.system.rawValue, equalTo: true)
        let generalQuery3 = LCIMConversationQuery.orQuery(withSubqueries: [generalQuery1, generalQuery2])
        generalQuery3?.addAscendingOrder(LCIMConversationKey.createdAt.rawValue)
        generalQuery3?.limit = 5
        generalQuery3?.findConversations { convs, error in
            XCTAssertNil(error)
            XCTAssertLessThanOrEqual(convs?.count ?? .max, 5)
            if let convs = convs {
                let types: [LCIMConvType] = [.system, .transient]
                var date = Date(timeIntervalSince1970: 0)
                for conv in convs {
                    XCTAssertTrue(types.contains(conv.convType))
                    XCTAssertNotNil(conv.createdAt)
                    if let createdAt = conv.createdAt {
                        XCTAssertGreaterThanOrEqual(createdAt, date)
                        date = createdAt
                    }
                }
            }
            generalQueryExp2.fulfill()
        }
        wait(for: [generalQueryExp2], timeout: timeout)
    }

    func testUpdateAttribution() {
        let delegatorA = LCIMClientDelegator.init()
        let clientA = newOpenedClient(delegator: delegatorA)

        LCRTMConnectionManager.shared().imProtobuf1Registry.removeAllObjects()
        LCRTMConnectionManager.shared().imProtobuf3Registry.removeAllObjects()
       
        let delegatorB = LCIMClientDelegator.init()
        let clientB = newOpenedClient(delegator: delegatorB)

        var convA: LCIMConversation? = nil
        var convB: LCIMConversation? = nil

        let nameKey = LCIMConversationKey.name.rawValue
        let attrKey = LCIMConversationKey.attributes.rawValue
        let createKey = "create"
        let deleteKey = "delete"
        let arrayKey = "array"

        let createConvExp = expectation(description: "create conversation")
        let option = LCIMConversationCreationOption.init()
        option.isUnique = false
        option.attributes = [
            deleteKey: uuid,
            arrayKey: [uuid]
        ]
        option.name = uuid
        clientA.createConversation(withClientIds: [clientA.ID, clientB.ID], option: option) { conv, error in
            XCTAssertNil(error)
            XCTAssertNotNil(conv)
            convA = conv
            createConvExp.fulfill()
        }
        wait(for: [createConvExp], timeout: timeout)

        delay()

        let data: [String: Any] = [
            nameKey: uuid,
            "\(attrKey).\(createKey)": uuid,
            "\(attrKey).\(deleteKey)": ["__op": "Delete"],
            "\(attrKey).\(arrayKey)": ["__op": "Add", "objects": [uuid]]
        ]

        let updateExp = expectation(description: "update")
        updateExp.expectedFulfillmentCount = 2
        delegatorB.conversationEvent = { client, conv, event in
            if conv.ID == convA?.ID {
                switch event {
                case let .dataUpdated(updatingData: updatingData, updatedData: updatedData, byClientID: byClientID):
                    XCTAssertNotNil(updatedData)
                    XCTAssertNotNil(updatingData)
                    XCTAssertEqual(byClientID, clientA.ID)

                    convB = conv
                    updateExp.fulfill()
                default:
                    break
                }
            }
        }
        data.forEach { key, value in
            convA?[key] = value
        }
        convA?.update(callback: { ret, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(ret)
            XCTAssertNil(error)
            updateExp.fulfill()
        })
        wait(for: [updateExp], timeout: timeout)

        let check = { (conv: LCIMConversation?) in
            XCTAssertEqual(conv?.name, data[nameKey] as? String)
            XCTAssertEqual(conv?.attributes?[createKey] as? String, data["\(attrKey).\(createKey)"] as? String)
            XCTAssertNil(conv?.attributes?[deleteKey])
            XCTAssertNotNil(conv?.attributes?[arrayKey])
        }
        check(convA)
        check(convB)
        XCTAssertEqual(convA?.attributes?[arrayKey] as? [String], convB?.attributes?[arrayKey] as? [String])
    }

    func testOfflineEvents() {
        let delegatorA = LCIMClientDelegator.init()
        let clientA = newOpenedClient(delegator: delegatorA)

        LCRTMConnectionManager.shared().imProtobuf1Registry.removeAllObjects()
        LCRTMConnectionManager.shared().imProtobuf3Registry.removeAllObjects()
       
        let delegatorB = LCIMClientDelegator.init()
        let clientB = newOpenedClient(delegator: delegatorB)

        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "create conv and send msg with rcp")
            exp.expectedFulfillmentCount = 5
            return exp
        }) { (exp) in
            delegatorA.messageEvent = { client, conv, event in
                switch event {
                case .received:
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case .joined:
                    exp.fulfill()
                    let message = LCIMTextMessage.init()
                    message.text = "text"
                    let msgOpt = LCIMMessageOption.init()
                    msgOpt.receipt = true
                    conv.send(message, option: msgOpt) { ret, error in
                        XCTAssertTrue(ret)
                        XCTAssertNil(error)
                        exp.fulfill()
                    }
                case .message(event: let msgEvent):
                    switch msgEvent {
                    case .delivered:
                        exp.fulfill()
                    default:
                        break
                    }
                default:
                    break
                }
            }
            clientA.createConversation(withClientIds: [clientB.ID]) { conv, error in
                XCTAssertNotNil(conv)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        delegatorA.reset()
        delegatorB.reset()

        delay()
        clientB.connection.disconnect()
        delay()

        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "conv read")
            exp.expectedFulfillmentCount = 1
            return exp
        }) { (exp) in
            let conv = clientA.convCollection.first?.value
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case .unreadMessageCountUpdated:
                    exp.fulfill()
                default:
                    break
                }
            }
            conv?.read()
        }
        delegatorA.reset()

        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "create another normal conv")
            exp.expectedFulfillmentCount = 3
            return exp
        }) { exp in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case .joined:
                    exp.fulfill()
                case .membersJoined:
                    exp.fulfill()
                default:
                    break
                }
            }
            let option = LCIMConversationCreationOption.init()
            option.isUnique = false
            clientA.createConversation(withClientIds: [clientB.ID], option: option) { conv, error in
                XCTAssertNil(error)
                XCTAssertNotNil(conv)
                exp.fulfill()
            }
        }
        delegatorA.reset()

        expecting(description: "update normal conv attr") { (exp) in
            let conv = clientA.convCollection.first?.value
            let name = self.uuid
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case .dataUpdated:
                    XCTAssertEqual(conv.name, name)
                    exp.fulfill()
                default:
                    break
                }
            }
            conv?["name"] = name
            conv?.update(callback: { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            })
        }
        delegatorA.reset()

        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "create temp conv")
            exp.expectedFulfillmentCount = 3
            return exp
        }) { exp in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case .joined:
                    exp.fulfill()
                case .membersJoined:
                    exp.fulfill()
                default:
                    break
                }
            }
            let option = LCIMConversationCreationOption.init()
            option.timeToLive = 3600
            clientA.createTemporaryConversation(withClientIds: [clientB.ID], option: option) { conv, error in
                XCTAssertNil(error)
                XCTAssertNotNil(conv)
                exp.fulfill()
            }
        }
//        delegatorA.reset()
//
//        delay()
//
//        expecting(expectation: { () -> XCTestExpectation in
//            let exp = self.expectation(description: "get offline events")
//            exp.expectedFulfillmentCount = 6
//            return exp
//        }) { (exp) in
//            delegatorB.conversationEvent = { client, conv, event in
//                switch event {
//                case .joined:
//                    if conv is LCIMTemporaryConversation {
//                        exp.fulfill()
//                    } else {
//                        exp.fulfill()
//                    }
//                case .membersJoined:
//                    if conv is LCIMTemporaryConversation {
//                        exp.fulfill()
//                    } else {
//                        exp.fulfill()
//                    }
//                case .dataUpdated:
//                    exp.fulfill()
//                case .message(event: let msgEvent):
//                    switch msgEvent {
//                    case .read:
//                        exp.fulfill()
//                    default:
//                        break
//                    }
//                default:
//                    break
//                }
//            }
//            clientB.connection.testConnect()
//        }
//        delegatorB.reset()
    }

    func testMemberInfo() {
        
        let delegatorA = LCIMClientDelegator.init()
        let clientA = newOpenedClient(delegator: delegatorA)
       
        let delegatorB = LCIMClientDelegator.init()
        let clientB = newOpenedClient(delegator: delegatorB)
       
        let clientCID: String = self.uuid

        var convA: LCIMConversation?

        expecting { (exp) in
            clientA.createConversation(withClientIds: [clientB.ID, clientCID]) { conv, error in
                XCTAssertNil(error)
                XCTAssertNotNil(conv)
                convA = conv
                exp.fulfill()
            }
        }
        
        expecting { (exp) in
            convA?.updateMemberRole(withMemberId: clientB.ID, role: .owner, callback: { ret, error in
                XCTAssertNotNil(error)
                XCTAssertFalse(ret)
                exp.fulfill()
            })
        }

        expecting { (exp) in
            convA?.getAllMemberInfo(callback: {[weak convA] infos, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertNotNil(convA?.memberInfoTable)
                XCTAssertEqual(convA?.memberInfoTable?.count, 1)
                exp.fulfill()
            })
        }

        multiExpecting(expectations: { () -> [XCTestExpectation] in
            let exp = self.expectation(description: "change member role to manager")
            exp.expectedFulfillmentCount = 2
            return [exp]
        }) { (exps) in
            let exp = exps[0]

            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .memberInfoChanged(memberId: memberId, role: role, byClientID: byClientID):
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(role, .manager)
                    XCTAssertEqual(memberId, clientB.ID)
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(convA?.memberInfoTable)
                    exp.fulfill()
                default:
                    break
                }
            }

            convA?.updateMemberRole(withMemberId: clientB.ID, role: .manager, callback: { ret, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertTrue(ret)
                let info = convA?.memberInfoTable?[clientB.ID] as? LCIMConversationMemberInfo
                XCTAssertEqual(info?.role(), .manager)
                exp.fulfill()
            })
        }

        delay()
        
        expecting { (exp) in
            let convB = clientB.convCollection.values.first
            XCTAssertNil(convB?.memberInfoTable)
            convB?.getMemberInfo(withMemberId: clientB.ID, callback: { info, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertNotNil(info)
                exp.fulfill()
            })
        }

        expecting { (exp) in
            convA?.getAllMemberInfo(callback: {[weak convA] infos, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertNotNil(convA?.memberInfoTable)
                XCTAssertEqual(convA?.memberInfoTable?.count, 2)
                exp.fulfill()
            })
        }

        multiExpecting(expectations: { () -> [XCTestExpectation] in
            let exp = self.expectation(description: "change member role to member")
            exp.expectedFulfillmentCount = 2
            return [exp]
        }) { (exps) in
            let exp = exps[0]

            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .memberInfoChanged(memberId: memberId, role: role, byClientID: byClientID):
                    XCTAssertEqual(role, .member)
                    XCTAssertEqual(memberId, clientB.ID)
                    XCTAssertEqual(byClientID, clientA.ID)
                    let info = conv.memberInfoTable?[clientB.ID] as? LCIMConversationMemberInfo
                    XCTAssertEqual(info?.role(), .member)
                    exp.fulfill()
                default:
                    break
                }
            }
            convA?.updateMemberRole(withMemberId: clientB.ID, role: .member, callback: { ret, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertTrue(ret)
                let info = convA?.memberInfoTable?[clientB.ID] as? LCIMConversationMemberInfo
                XCTAssertEqual(info?.role(), .member)
                exp.fulfill()
            })
        }
    }

    func testMemberBlock() {
        let delegatorA = LCIMClientDelegator.init()
        let clientA = newOpenedClient(delegator: delegatorA)
        let delegatorB = LCIMClientDelegator.init()
        let clientB = newOpenedClient(delegator: delegatorB)
        let delegatorC = LCIMClientDelegator.init()
        let clientC = newOpenedClient(delegator: delegatorC)

        var convA: LCIMConversation?

        expecting { (exp) in
            clientA.createConversation(withClientIds: [clientB.ID, clientC.ID]) { conv, error in
                XCTAssertNil(error)
                XCTAssertNotNil(conv)
                convA = conv
                exp.fulfill()
            }
        }

        multiExpecting(expectations: { () -> [XCTestExpectation] in
            let exp = self.expectation(description: "block member")
            exp.expectedFulfillmentCount = 7
            return [exp]
        }) { (exps) in
            let exp = exps[0]

            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersBlocked(members: members, byClientID: byClientID):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertTrue(members.contains(clientC.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                case let .membersLeft(members: members, byClientID: byClientID):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertTrue(members.contains(clientC.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }

            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .blocked(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                case let .left(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }

            delegatorC.conversationEvent = { client, conv, event in
                switch event {
                case let .blocked(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                case let .left(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }

            convA?.blockMembers([clientB.ID, clientC.ID], callback: { ids, oper, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertNotNil(ids)
                exp.fulfill()
            })
        }

        delegatorA.reset()
        delegatorB.reset()
        delegatorC.reset()
        

        var next: String?

        expecting { (exp) in
            convA?.queryBlockedMembers(withLimit: 1, next: nil, callback: { members, _next, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertEqual(members?.count, 1)
                if let member = members?.first {
                    XCTAssertTrue([clientB.ID, clientC.ID].contains(member))
                }
                XCTAssertNotNil(_next)
                next = _next
                exp.fulfill()
            })
        }

        expecting { (exp) in
            convA?.queryBlockedMembers(withLimit: 50, next: next, callback: { members, _next, error in
                XCTAssertNil(error)
                XCTAssertEqual(members?.count, 1)
                if let member = members?.first {
                    XCTAssertTrue([clientB.ID, clientC.ID].contains(member))
                }
                XCTAssertNil(_next)
                exp.fulfill()
            })
        }

        multiExpecting(expectations: { () -> [XCTestExpectation] in
            let exp = self.expectation(description: "unblock member")
            exp.expectedFulfillmentCount = 4
            return [exp]
        }) { (exps) in
            let exp = exps[0]

            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersUnblocked(members: members, byClientID: byClientID):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertTrue(members.contains(clientC.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }

            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .unblocked(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }

            delegatorC.conversationEvent = { client, conv, event in
                switch event {
                case let .unblocked(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }

            convA?.unblockMembers([clientB.ID, clientC.ID], callback: { members, fails, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                exp.fulfill()
            })
        }
    }

    func testMemberMute() {
        let delegatorA = LCIMClientDelegator.init()
        let clientA = newOpenedClient(delegator: delegatorA)
        let delegatorB = LCIMClientDelegator.init()
        let clientB = newOpenedClient(delegator: delegatorB)
        let delegatorC = LCIMClientDelegator.init()
        let clientC = newOpenedClient(delegator: delegatorC)

        var convA: LCIMConversation?

        expecting { (exp) in
            clientA.createConversation(withClientIds: [clientB.ID, clientC.ID]) { conv, error in
                XCTAssertNil(error)
                XCTAssertNotNil(conv)
                convA = conv
                exp.fulfill()
            }
        }

        multiExpecting(expectations: { () -> [XCTestExpectation] in
            let exp = self.expectation(description: "mute member")
            exp.expectedFulfillmentCount = 4
            return [exp]
        }) { (exps) in
            let exp = exps[0]

            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersMuted(members: members, byClientID: byClientID):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertTrue(members.contains(clientC.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }

            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .muted(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }

            delegatorC.conversationEvent = { client, conv, event in
                switch event {
                case let .muted(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }

            convA?.muteMembers([clientB.ID, clientC.ID], callback: { members, fails, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                exp.fulfill()
            })
        }

        delegatorA.reset()
        delegatorB.reset()
        delegatorC.reset()

        var next: String?

        expecting { (exp) in
            convA?.queryMutedMembers(withLimit: 1, next: nil, callback: { members, _next, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertEqual(members?.count, 1)
                if let member = members?.first {
                    XCTAssertTrue([clientB.ID, clientC.ID].contains(member))
                }
                XCTAssertNotNil(_next)
                next = _next
                exp.fulfill()
            })
        }

        expecting { (exp) in
            convA?.queryMutedMembers(withLimit: 50, next: next, callback: { members, _next, error in
                XCTAssertNil(error)
                XCTAssertEqual(members?.count, 1)
                if let member = members?.first {
                    XCTAssertTrue([clientB.ID, clientC.ID].contains(member))
                }
                XCTAssertNil(_next)
                exp.fulfill()
            })
        }

        multiExpecting(expectations: { () -> [XCTestExpectation] in
            let exp = self.expectation(description: "unmute member")
            exp.expectedFulfillmentCount = 4
            return [exp]
        }) { (exps) in
            let exp = exps[0]

            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersUnmuted(members: members, byClientID: byClientID):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertTrue(members.contains(clientC.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }

            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .unmuted(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }

            delegatorC.conversationEvent = { client, conv, event in
                switch event {
                case let .unmuted(byClientID: byClientID):
                    XCTAssertEqual(byClientID, clientA.ID)
                    exp.fulfill()
                default:
                    break
                }
            }
            convA?.unmuteMembers([clientB.ID, clientC.ID], callback: { members, fails, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                exp.fulfill()
            })
        }
    }

}

extension LCIMConversationTestCase {

    
    func newServiceConversation() -> String {
        
        var objectID: String?
        let paasClient = LCPaasClient.sharedInstance()
        let request = paasClient?.request(withPath: "https://s5vdi3ie.lc-cn-n1-shared.com/1.2/rtm/service-conversations", method: "POST", headers: nil, parameters: ["name": uuid])
        expecting { exp in
            paasClient?.perform(request as URLRequest?, success: { response, responseObject in
                guard let response = responseObject as? [String: Any] else {
                    return
                }
                objectID = response["objectId"]  as? String
                exp.fulfill()
            }, failure: { _, _, _ in
                exp.fulfill()
            })
        }
        XCTAssertNotNil(objectID)
        return objectID!
    }
    
    func subscribing(serviceConversation conversationID: String, by clientID: String) -> Bool {
        var success: Bool = false
        let paasClient = LCPaasClient.sharedInstance()
        let request = paasClient?.request(withPath: "https://s5vdi3ie.lc-cn-n1-shared.com/1.2/rtm/service-conversations/\(conversationID)/subscribers", method: "POST", headers: ["X-LC-Key": BaseTestCase.cnApp.masterKey], parameters: ["client_id": clientID])
        expecting { exp in
            paasClient?.perform(request as URLRequest?, success: { response, responseObject in
                success = true
                exp.fulfill()
            }, failure: { _, _, _ in
                exp.fulfill()
            })
        }
        return success
    }

    @discardableResult
    func broadcastingMessage(to conversationID: String, content: String = "test") -> (String, Int64) {
        var tuple: (String, Int64)?
        let paasClient = LCPaasClient.sharedInstance()
        let request = paasClient?.request(withPath: "https://s5vdi3ie.lc-cn-n1-shared.com/1.2/rtm/service-conversations/\(conversationID)/broadcasts", method: "POST", headers: ["X-LC-Key": BaseTestCase.cnApp.masterKey], parameters: ["from_client": "master", "message": content])
        expecting { exp in
            paasClient?.perform(request as URLRequest?, success: { response, responseObject in
        
                if let result = responseObject as? [String: Any],
                   let result = result["result"] as? [String: Any],
                    let messageID: String = result["msg-id"] as? String,
                    let timestamp: Int64 = result["timestamp"] as? Int64 {
                    tuple = (messageID, timestamp)
                }
                exp.fulfill()
            }, failure: { _, _, _ in
                exp.fulfill()
            })
        }
        XCTAssertNotNil(tuple)
        return tuple!
    }
    

}
