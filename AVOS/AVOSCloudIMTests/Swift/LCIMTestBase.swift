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
        LCRouter.sharedInstance().cleanCache(withKey: .app, error: nil)
        LCRouter.sharedInstance().cleanCache(withKey: .RTM, error: nil)
        super.setUp()
        /// custom RTM server URL
        if let RTMServerURL: String = LCTestEnvironment.sharedInstance().url_RTMServer {
            AVOSCloudIM.defaultOptions().rtmServer = RTMServerURL
        }
        AVIMClient.setUnreadNotificationEnabled(true)
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
    
    static var clientDustbin: [AVIMClient] = []
    
    static func newOpenedClient(
        clientId: String,
        tag: String? = nil,
        delegate: AVIMClientDelegate? = nil,
        installation: AVInstallation = AVInstallation.default(),
        openOption: AVIMClientOpenOption = .forceOpen
        ) -> AVIMClient?
    {
        var client: AVIMClient! = AVIMClient(clientId: clientId, tag: tag, installation: installation)
        if let delegate: AVIMClientDelegate = delegate {
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
        client: AVIMClient,
        clientIds: [String],
        name: String? = nil,
        attributes: [AnyHashable : Any]? = nil,
        options: AVIMConversationOption = [],
        temporaryTTL: Int32 = 0
        ) -> AVIMConversation?
    {
        var conversation: AVIMConversation? = nil
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            client.createConversation(withName: name, clientIds: clientIds, attributes: attributes, options: options, temporaryTTL: temporaryTTL, callback: { (conv: AVIMConversation?, error: Error?) in
                semaphore.decrement()
                conversation = conv
            })
        }, failure: { XCTFail("timeout") })
        return conversation
    }
    
}

class AVIMClientDelegateWrapper: NSObject, AVIMClientDelegate {
    
    func imClientPaused(_ imClient: AVIMClient, error: Error?) {
        
    }
    
    var pausedClosure: ((AVIMClient) -> Void)?
    func imClientPaused(_ imClient: AVIMClient) {
        self.pausedClosure?(imClient)
    }
    
    var resumingClosure: ((AVIMClient) -> Void)?
    func imClientResuming(_ imClient: AVIMClient) {
        self.resumingClosure?(imClient)
    }
    
    var resumedClosure: ((AVIMClient) -> Void)?
    func imClientResumed(_ imClient: AVIMClient) {
        self.resumedClosure?(imClient)
    }
    
    var closedClosure: ((AVIMClient, Error?) -> Void)?
    func imClientClosed(_ imClient: AVIMClient, error: Error?) {
        self.closedClosure?(imClient, error)
    }
    
    var didReceiveTypeMessageClosure: ((AVIMConversation, AVIMTypedMessage) -> Void)?
    func conversation(_ conversation: AVIMConversation, didReceive message: AVIMTypedMessage) {
        self.didReceiveTypeMessageClosure?(conversation, message)
    }
    
    var didReceiveCommonMessageClosure: ((AVIMConversation, AVIMMessage) -> Void)?
    func conversation(_ conversation: AVIMConversation, didReceiveCommonMessage message: AVIMMessage) {
        self.didReceiveCommonMessageClosure?(conversation, message)
    }
    
    var didOfflineClosure: ((AVIMClient, Error?) -> Void)?
    func client(_ client: AVIMClient, didOfflineWithError error: Error?) {
        self.didOfflineClosure?(client, error)
    }
    
    var messageHasBeenUpdatedClosure: ((AVIMConversation, AVIMMessage) -> Void)?
    func conversation(_ conversation: AVIMConversation, messageHasBeenUpdated message: AVIMMessage) {
        self.messageHasBeenUpdatedClosure?(conversation, message)
    }
    
    var messageDeliveredClosure: ((AVIMConversation, AVIMMessage) -> Void)?
    func conversation(_ conversation: AVIMConversation, messageDelivered message: AVIMMessage) {
        self.messageDeliveredClosure?(conversation, message)
    }
    
    var didUpdateForKeyClosure: ((AVIMConversation, AVIMConversationUpdatedKey) -> Void)?
    func conversation(_ conversation: AVIMConversation, didUpdateForKey key: AVIMConversationUpdatedKey) {
        self.didUpdateForKeyClosure?(conversation, key)
    }
    
    var updateByClosure: ((AVIMConversation, Date?, String?, [AnyHashable : Any]?) -> Void)?
    func conversation(_ conversation: AVIMConversation, didUpdateAt date: Date?, byClientId clientId: String?, updatedData data: [AnyHashable : Any]?) {
        self.updateByClosure?(conversation, date, clientId, data)
    }
    
    var invitedByClosure: ((AVIMConversation, String?) -> Void)?
    func conversation(_ conversation: AVIMConversation, invitedByClientId clientId: String?) {
        self.invitedByClosure?(conversation, clientId)
    }
    
    var kickedByClosure: ((AVIMConversation, String?) -> Void)?
    func conversation(_ conversation: AVIMConversation, kickedByClientId clientId: String?) {
        self.kickedByClosure?(conversation, clientId)
    }
    
    var membersAddedClosure: ((AVIMConversation, [String]?, String?) -> Void)?
    func conversation(_ conversation: AVIMConversation, membersAdded clientIds: [String]?, byClientId clientId: String?) {
        self.membersAddedClosure?(conversation, clientIds, clientId)
    }
    
    var membersRemovedClosure: ((AVIMConversation, [String]?, String?) -> Void)?
    func conversation(_ conversation: AVIMConversation, membersRemoved clientIds: [String]?, byClientId clientId: String?) {
        self.membersRemovedClosure?(conversation, clientIds, clientId)
    }
    
    var memberInfoChangeClosure: ((AVIMConversation, String?, String?, AVIMConversationMemberRole) -> Void)?
    func conversation(_ conversation: AVIMConversation, didMemberInfoUpdateBy byClientId: String?, memberId: String?, role: AVIMConversationMemberRole) {
        self.memberInfoChangeClosure?(conversation, byClientId, memberId, role)
    }
    
    var blockByClosure: ((AVIMConversation, String?) -> Void)?
    func conversation(_ conversation: AVIMConversation, didBlockBy byClientId: String?) {
        self.blockByClosure?(conversation, byClientId)
    }
    
    var unblockByClosure: ((AVIMConversation, String?) -> Void)?
    func conversation(_ conversation: AVIMConversation, didUnblockBy byClientId: String?) {
        self.unblockByClosure?(conversation, byClientId)
    }
    
    var membersBlockByClosure: ((AVIMConversation, String?, [String]?) -> Void)?
    func conversation(_ conversation: AVIMConversation, didMembersBlockBy byClientId: String?, memberIds: [String]?) {
        self.membersBlockByClosure?(conversation, byClientId, memberIds)
    }
    
    var membersUnblockByClosure: ((AVIMConversation, String?, [String]?) -> Void)?
    func conversation(_ conversation: AVIMConversation, didMembersUnblockBy byClientId: String?, memberIds: [String]?) {
        self.membersUnblockByClosure?(conversation, byClientId, memberIds)
    }
    
    var muteByClosure: ((AVIMConversation, String?) -> Void)?
    func conversation(_ conversation: AVIMConversation, didMuteBy byClientId: String?) {
        self.muteByClosure?(conversation, byClientId)
    }
    
    var unmuteByClosure: ((AVIMConversation, String?) -> Void)?
    func conversation(_ conversation: AVIMConversation, didMembersMuteBy byClientId: String?, memberIds: [String]?) {
        self.membersMuteByClosure?(conversation, byClientId, memberIds)
    }
    
    var membersMuteByClosure: ((AVIMConversation, String?, [String]?) -> Void)?
    func conversation(_ conversation: AVIMConversation, didUnmuteBy byClientId: String?) {
        self.unmuteByClosure?(conversation, byClientId)
    }
    
    var membersUnmuteByClosure: ((AVIMConversation, String?, [String]?) -> Void)?
    func conversation(_ conversation: AVIMConversation, didMembersUnmuteBy byClientId: String?, memberIds: [String]?) {
        self.membersUnmuteByClosure?(conversation, byClientId, memberIds)
    }
    
}
