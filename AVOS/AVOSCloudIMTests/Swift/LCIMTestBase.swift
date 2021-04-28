//
//  LCIMTestBase.swift
//  AVOS
//
//  Created by zapcannon87 on 19/12/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

import Foundation
import XCTest

class LCIMTestBase: LCTestBase {
    
    override class func setUp() {
        super.setUp()
        /// custom RTM server URL
        if let RTMServerURL: String = LCTestEnvironment.sharedInstance().url_RTMServer {
            AVOSCloudIM.defaultOptions().rtmServer = RTMServerURL
        }
        LCIMClient.setUnreadNotificationEnabled(true)
    }
    
    override class func tearDown() {
        super.tearDown()
    }
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        for client in LCIMTestBase.clientDustbin {
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                client.close(callback: { (_, _) in
                    semaphore.decrement()
                })
            })
        }
        LCIMTestBase.clientDustbin.removeAll()
        super.tearDown()
    }
    
}

extension LCIMTestBase {
    
    static var clientDustbin: [LCIMClient] = []
    
    static func newOpenedClient(
        clientId: String,
        tag: String? = nil,
        delegate: LCIMClientDelegate? = nil,
        installation: LCInstallation = LCInstallation.default(),
        openOption: LCIMClientOpenOption = .forceOpen
        ) -> LCIMClient?
    {
        var client: LCIMClient! = try! LCIMClient(clientId: clientId, tag: tag, installation: installation)
        if let delegate: LCIMClientDelegate = delegate {
            client.delegate = delegate
        }
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.open(with: openOption, callback: { (succeeded: Bool, error: Error?) in
                semaphore.decrement()
                if !succeeded { client = nil }
            })
        }, failure: { client = nil })
        if client != nil {
            LCIMTestBase.clientDustbin.append(client)
        }
        return client
    }
    
    static func newConversation(
        client: LCIMClient,
        clientIds: [String],
        name: String? = nil,
        attributes: [AnyHashable : Any]? = nil,
        options: LCIMConversationOption = [],
        temporaryTTL: Int32 = 0
        ) -> LCIMConversation?
    {
        var conversation: LCIMConversation? = nil
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.createConversation(withName: name, clientIds: clientIds, attributes: attributes, options: options, temporaryTTL: temporaryTTL, callback: { (conv: LCIMConversation?, error: Error?) in
                semaphore.decrement()
                conversation = conv
            })
        }, failure: { XCTFail("timeout") })
        return conversation
    }
    
}

class LCIMClientDelegateWrapper: NSObject, LCIMClientDelegate {
    
    func imClientPaused(_ imClient: LCIMClient, error: Error?) {
        
    }
    
    var pausedClosure: ((LCIMClient) -> Void)?
    func imClientPaused(_ imClient: LCIMClient) {
        self.pausedClosure?(imClient)
    }
    
    var resumingClosure: ((LCIMClient) -> Void)?
    func imClientResuming(_ imClient: LCIMClient) {
        self.resumingClosure?(imClient)
    }
    
    var resumedClosure: ((LCIMClient) -> Void)?
    func imClientResumed(_ imClient: LCIMClient) {
        self.resumedClosure?(imClient)
    }
    
    var closedClosure: ((LCIMClient, Error?) -> Void)?
    func imClientClosed(_ imClient: LCIMClient, error: Error?) {
        self.closedClosure?(imClient, error)
    }
    
    var didReceiveTypeMessageClosure: ((LCIMConversation, AVIMTypedMessage) -> Void)?
    func conversation(_ conversation: LCIMConversation, didReceive message: AVIMTypedMessage) {
        self.didReceiveTypeMessageClosure?(conversation, message)
    }
    
    var didReceiveCommonMessageClosure: ((LCIMConversation, LCIMMessage) -> Void)?
    func conversation(_ conversation: LCIMConversation, didReceiveCommonMessage message: LCIMMessage) {
        self.didReceiveCommonMessageClosure?(conversation, message)
    }
    
    var didOfflineClosure: ((LCIMClient, Error?) -> Void)?
    func client(_ client: LCIMClient, didOfflineWithError error: Error?) {
        self.didOfflineClosure?(client, error)
    }
    
    var messageHasBeenUpdatedClosure: ((LCIMConversation, LCIMMessage) -> Void)?
    func conversation(_ conversation: LCIMConversation, messageHasBeenUpdated message: LCIMMessage) {
        self.messageHasBeenUpdatedClosure?(conversation, message)
    }
    
    var messageDeliveredClosure: ((LCIMConversation, LCIMMessage) -> Void)?
    func conversation(_ conversation: LCIMConversation, messageDelivered message: LCIMMessage) {
        self.messageDeliveredClosure?(conversation, message)
    }
    
    var didUpdateForKeyClosure: ((LCIMConversation, LCIMConversationUpdatedKey) -> Void)?
    func conversation(_ conversation: LCIMConversation, didUpdateForKey key: LCIMConversationUpdatedKey) {
        self.didUpdateForKeyClosure?(conversation, key)
    }
    
    var updateByClosure: ((LCIMConversation, Date?, String?, [AnyHashable : Any]?) -> Void)?
    func conversation(_ conversation: LCIMConversation, didUpdateAt date: Date?, byClientId clientId: String?, updatedData data: [AnyHashable : Any]?) {
        self.updateByClosure?(conversation, date, clientId, data)
    }
    
    var invitedByClosure: ((LCIMConversation, String?) -> Void)?
    func conversation(_ conversation: LCIMConversation, invitedByClientId clientId: String?) {
        self.invitedByClosure?(conversation, clientId)
    }
    
    var kickedByClosure: ((LCIMConversation, String?) -> Void)?
    func conversation(_ conversation: LCIMConversation, kickedByClientId clientId: String?) {
        self.kickedByClosure?(conversation, clientId)
    }
    
    var membersAddedClosure: ((LCIMConversation, [String]?, String?) -> Void)?
    func conversation(_ conversation: LCIMConversation, membersAdded clientIds: [String]?, byClientId clientId: String?) {
        self.membersAddedClosure?(conversation, clientIds, clientId)
    }
    
    var membersRemovedClosure: ((LCIMConversation, [String]?, String?) -> Void)?
    func conversation(_ conversation: LCIMConversation, membersRemoved clientIds: [String]?, byClientId clientId: String?) {
        self.membersRemovedClosure?(conversation, clientIds, clientId)
    }
    
    var memberInfoChangeClosure: ((LCIMConversation, String?, String?, LCIMConversationMemberRole) -> Void)?
    func conversation(_ conversation: LCIMConversation, didMemberInfoUpdateBy byClientId: String?, memberId: String?, role: LCIMConversationMemberRole) {
        self.memberInfoChangeClosure?(conversation, byClientId, memberId, role)
    }
    
    var blockByClosure: ((LCIMConversation, String?) -> Void)?
    func conversation(_ conversation: LCIMConversation, didBlockBy byClientId: String?) {
        self.blockByClosure?(conversation, byClientId)
    }
    
    var unblockByClosure: ((LCIMConversation, String?) -> Void)?
    func conversation(_ conversation: LCIMConversation, didUnblockBy byClientId: String?) {
        self.unblockByClosure?(conversation, byClientId)
    }
    
    var membersBlockByClosure: ((LCIMConversation, String?, [String]?) -> Void)?
    func conversation(_ conversation: LCIMConversation, didMembersBlockBy byClientId: String?, memberIds: [String]?) {
        self.membersBlockByClosure?(conversation, byClientId, memberIds)
    }
    
    var membersUnblockByClosure: ((LCIMConversation, String?, [String]?) -> Void)?
    func conversation(_ conversation: LCIMConversation, didMembersUnblockBy byClientId: String?, memberIds: [String]?) {
        self.membersUnblockByClosure?(conversation, byClientId, memberIds)
    }
    
    var muteByClosure: ((LCIMConversation, String?) -> Void)?
    func conversation(_ conversation: LCIMConversation, didMuteBy byClientId: String?) {
        self.muteByClosure?(conversation, byClientId)
    }
    
    var unmuteByClosure: ((LCIMConversation, String?) -> Void)?
    func conversation(_ conversation: LCIMConversation, didMembersMuteBy byClientId: String?, memberIds: [String]?) {
        self.membersMuteByClosure?(conversation, byClientId, memberIds)
    }
    
    var membersMuteByClosure: ((LCIMConversation, String?, [String]?) -> Void)?
    func conversation(_ conversation: LCIMConversation, didUnmuteBy byClientId: String?) {
        self.unmuteByClosure?(conversation, byClientId)
    }
    
    var membersUnmuteByClosure: ((LCIMConversation, String?, [String]?) -> Void)?
    func conversation(_ conversation: LCIMConversation, didMembersUnmuteBy byClientId: String?, memberIds: [String]?) {
        self.membersUnmuteByClosure?(conversation, byClientId, memberIds)
    }
    
}
