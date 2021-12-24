//
//  RTMBaseTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2020/06/26.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

class RTMBaseTestCase: BaseTestCase {
    
    static let testableRTMServer = "wss://cn-n1-prod-k8s-cell-12.leancloud.cn"
    
    override class func setUp() {
        super.setUp()
    }
    
    static func purgeConnectionRegistry() {
        LCRTMConnectionManager.shared().liveQueryRegistry.removeAllObjects()
        LCRTMConnectionManager.shared().imProtobuf1Registry.removeAllObjects()
        LCRTMConnectionManager.shared().imProtobuf3Registry.removeAllObjects()
    }
    
    func newOpenedClient(clientID: String = RTMBaseTestCase.uuid, tag: String? = nil, delegator: LCIMClientDelegator? = nil) -> LCIMClient {
        let client: LCIMClient! = try? LCIMClient.init(clientId: clientID, tag: tag)
        XCTAssertNotNil(client)
        client.delegate = delegator
        expecting { (exp) in
            client.open { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        return client
    }
    
    
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

extension LCIMClient {
    var ID: String {
        return clientId
    }
    
    var convCollection: [String: LCIMConversation] {
        set {
            conversationManager.conversationMap = newValue as? NSMutableDictionary ?? [:]
        }
        
        get {
            return conversationManager.conversationMap as? [String: LCIMConversation] ?? [:]
        }
        
    }
    
    var convQueryCallbackCollection: [String: Array<(LCIMConversation, Error) -> Void>] {
        set {
            conversationManager.callbacksMap = newValue as? NSMutableDictionary ?? [:]
        }
        
        get {
            return conversationManager.callbacksMap as? [String : Array<(LCIMConversation, Error) -> Void>] ?? [:]
        }
    }
    
    static func date(fromMillisecond timestamp: Int64?) -> Date? {
        guard let timestamp = timestamp else {
            return nil
        }
        let second = TimeInterval(timestamp) / 1000.0
        return Date(timeIntervalSince1970: second)
    }

}

extension LCIMConversation {
    var ID: String {
        return conversationId ?? ""
    }
    
    var uniqueID: String? {
        return uniqueId
    }
    
    var clientID: String {
        return clientId ?? ""
    }
    
    var unreadMessageCount: Int {
        return Int(unreadMessagesCount)
    }
  
    var isUnreadMessageContainMention: Bool {
        return unreadMessagesMentioned
    }
    
    var isMuted: Bool {
        return muted
    }
    
    func read() {
        readInBackground()
    }
    
    
    
 
}

extension LCIMTemporaryConversation {
    
    var timeToLive: Int? {
        return Int(temporaryTTL)
    }
 
}


extension LCIMMessage {
    
    var conversationID: String? {
        return conversationId
    }
    
    var currentClientID: String? {
        return localClientId
    }
    
    var fromClientID: String? {
        return clientId
    }
    
    var sentTimestamp: Int64? {
        return sendTimestamp == 0 ? nil : sendTimestamp
    }
    
    var ID: String? {
        return messageId
    }
    
    var isTransient: Bool {
        return transient
    }
    
//    var isWill: Bool {
//        return offline
//    }
    var isAllMembersMentioned: Bool? {
        set {
            mentionAll = newValue ?? false
        }
        get {
            return mentionAll
        }
        
    }
    
    var sentDate: Date? {
        return LCIMClient.date(fromMillisecond: self.sentTimestamp)
    }
//
//    var isUnreadMessageContainMention: Bool {
//        return mentioned
//    }
 
}


extension LCIMTypedMessage {
    
    
}

extension LCObject {

}
