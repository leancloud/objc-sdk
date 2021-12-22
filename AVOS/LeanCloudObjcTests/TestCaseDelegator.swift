//
//  LCIMClientDelegator.swift
//  LeanCloudObjcTests
//
//  Created by 黄驿峰 on 2021/12/9.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import UIKit

class LCIMClientDelegator: NSObject {
    
    var imClientResuming: ((LCIMClient) -> Void)?
    var imClientResumed: ((LCIMClient) -> Void)?
    var imClientPaused: ((LCIMClient, Error?) -> Void)?
    var imClientClosed: ((LCIMClient, Error?) -> Void)?
    var didReceiveCommonMessage: ((LCIMConversation, LCIMMessage) -> Void)?
    var didReceiveTypedMessage: ((LCIMConversation, LCIMTypedMessage) -> Void)?
    var messageDelivered: ((LCIMConversation, LCIMMessage) -> Void)?
    var messageHasBeenUpdated: ((LCIMConversation, LCIMMessage, LCIMMessagePatchedReason?) -> Void)?
    var messageHasBeenRecalled: ((LCIMConversation, LCIMRecalledMessage, LCIMMessagePatchedReason?) -> Void)?
    var membersAdded: ((LCIMConversation, [String]?, String?) -> Void)?
    var didMuteBy: ((LCIMConversation, String?) -> Void)?
    var didBlockBy: ((LCIMConversation, String?) -> Void)?
    var didUnmuteBy: ((LCIMConversation, String?) -> Void)?
    var didUnblockBy: ((LCIMConversation, String?) -> Void)?
    var kickedByClientId: ((LCIMConversation, String?) -> Void)?
    var invitedByClientId: ((LCIMConversation, String?) -> Void)?
    var didUpdateForKey: ((LCIMConversation, LCIMConversationUpdatedKey) -> Void)?
    var didMembersMuteBy: ((LCIMConversation, String?, [String]?) -> Void)?
    var didMembersBlockBy: ((LCIMConversation, String?, [String]?) -> Void)?
    var didMembersUnmuteBy: ((LCIMConversation, String?, [String]?) -> Void)?
    var didMembersUnblockBy: ((LCIMConversation, String?, [String]?) -> Void)?
    var membersRemoved: ((LCIMConversation, [String]?, String?) -> Void)?
    var didMemberInfoUpdateBy: ((LCIMConversation, String?, String?, LCIMConversationMemberRole) -> Void)?
    var didUpdateAt: ((LCIMConversation, Date?, String?, [AnyHashable : Any]?, [AnyHashable : Any]?) -> Void)?
    
    
    func reset() {
        imClientResuming = nil
        imClientResumed = nil
        imClientPaused = nil
        imClientClosed = nil
        didReceiveCommonMessage = nil
        didReceiveTypedMessage = nil
        messageDelivered = nil
        messageHasBeenUpdated = nil
        messageHasBeenRecalled = nil
        membersAdded = nil
        didMuteBy = nil
        didBlockBy = nil
        didUnmuteBy = nil
        didUnblockBy = nil
        kickedByClientId = nil
        invitedByClientId = nil
        didUpdateForKey = nil
        didMembersMuteBy = nil
        didMembersBlockBy = nil
        didMembersUnmuteBy = nil
        didMembersUnblockBy = nil
        membersRemoved = nil
        didMemberInfoUpdateBy = nil
        didUpdateAt = nil
    }

}


extension LCIMClientDelegator: LCIMClientDelegate {
    func imClientResuming(_ imClient: LCIMClient) {
        imClientResuming?(imClient)
    }
    
    func imClientResumed(_ imClient: LCIMClient) {
        imClientResumed?(imClient)
    }
   
    func imClientPaused(_ imClient: LCIMClient, error: Error?) {
        imClientPaused?(imClient, error)
    }
    
    func imClientClosed(_ imClient: LCIMClient, error: Error?) {
        imClientClosed?(imClient, error)
    }
    
    func conversation(_ conversation: LCIMConversation, didReceiveCommonMessage message: LCIMMessage) {
        didReceiveCommonMessage?(conversation, message)
    }
    
    func conversation(_ conversation: LCIMConversation, didReceive message: LCIMTypedMessage) {
        didReceiveTypedMessage?(conversation, message)
    }
    
    func conversation(_ conversation: LCIMConversation, messageDelivered message: LCIMMessage) {
        messageDelivered?(conversation, message)
    }
    
    func conversation(_ conversation: LCIMConversation, messageHasBeenUpdated message: LCIMMessage, reason: LCIMMessagePatchedReason?) {
        messageHasBeenUpdated?(conversation, message, reason)
    }
    
    func conversation(_ conversation: LCIMConversation, messageHasBeenRecalled message: LCIMRecalledMessage, reason: LCIMMessagePatchedReason?) {
        messageHasBeenRecalled?(conversation, message, reason)
    }
    
    func conversation(_ conversation: LCIMConversation, membersAdded clientIds: [String]?, byClientId clientId: String?) {
        membersAdded?(conversation, clientIds, clientId)
    }
    
    func conversation(_ conversation: LCIMConversation, didMuteBy byClientId: String?) {
        didMuteBy?(conversation, byClientId)
    }

    func conversation(_ conversation: LCIMConversation, didBlockBy byClientId: String?) {
        didBlockBy?(conversation, byClientId)
    }

    func conversation(_ conversation: LCIMConversation, didUnmuteBy byClientId: String?) {
        didUnmuteBy?(conversation, byClientId)
    }

    func conversation(_ conversation: LCIMConversation, didUnblockBy byClientId: String?) {
        didUnblockBy?(conversation, byClientId)
    }

    func conversation(_ conversation: LCIMConversation, kickedByClientId clientId: String?) {
        kickedByClientId?(conversation, clientId)
    }

    func conversation(_ conversation: LCIMConversation, invitedByClientId clientId: String?) {
        invitedByClientId?(conversation, clientId)
    }

    func conversation(_ conversation: LCIMConversation, didUpdateForKey key: LCIMConversationUpdatedKey) {
        didUpdateForKey?(conversation, key)
    }

    func conversation(_ conversation: LCIMConversation, didMembersMuteBy byClientId: String?, memberIds: [String]?) {
        didMembersMuteBy?(conversation, byClientId, memberIds)
    }

    func conversation(_ conversation: LCIMConversation, didMembersBlockBy byClientId: String?, memberIds: [String]?) {
        didMembersBlockBy?(conversation, byClientId, memberIds)
    }

    func conversation(_ conversation: LCIMConversation, didMembersUnmuteBy byClientId: String?, memberIds: [String]?) {
        didMembersUnmuteBy?(conversation, byClientId, memberIds)
    }

    func conversation(_ conversation: LCIMConversation, didMembersUnblockBy byClientId: String?, memberIds: [String]?) {
        didMembersUnblockBy?(conversation, byClientId, memberIds)
    }

    func conversation(_ conversation: LCIMConversation, membersRemoved clientIds: [String]?, byClientId clientId: String?) {
        membersRemoved?(conversation, clientIds, clientId)
    }

    func conversation(_ conversation: LCIMConversation, didMemberInfoUpdateBy byClientId: String?, memberId: String?, role: LCIMConversationMemberRole) {
        didMemberInfoUpdateBy?(conversation, byClientId, memberId, role)
    }

    func conversation(_ conversation: LCIMConversation, didUpdateAt date: Date?, byClientId clientId: String?, updatedData: [AnyHashable : Any]?, updatingData: [AnyHashable : Any]?) {
        didUpdateAt?(conversation, date, clientId, updatedData, updatingData)
    }
}

