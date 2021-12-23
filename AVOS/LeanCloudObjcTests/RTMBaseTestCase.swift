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




