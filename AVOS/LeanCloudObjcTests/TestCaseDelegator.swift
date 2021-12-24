//
//  LCIMClientDelegator.swift
//  LeanCloudObjcTests
//
//  Created by 黄驿峰 on 2021/12/9.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import UIKit

// MARK: - Event

/// The session event about the client.
public enum IMClientEvent {
    /// Session opened event.
    case sessionDidOpen
    /// Session in resuming event.
    case sessionDidResume
    /// Session paused event.
    case sessionDidPause(error: Error?)
    /// Session closed event.
    case sessionDidClose(error: Error?)
}

/// The events about conversation that belong to the client.
public enum IMConversationEvent {
    /// This client joined this conversation.
    case joined(byClientID: String?)
    /// This client left this conversation.
    case left(byClientID: String?)
    /// The members joined this conversation.
    case membersJoined(members: [String], byClientID: String?)
    /// The members left this conversation.
    case membersLeft(members: [String], byClientID: String?)
    /// The info of the member in this conversaiton has been changed.
    case memberInfoChanged(memberId: String?, role: LCIMConversationMemberRole, byClientID: String?)

    /// The client in this conversation has been blocked.
    case blocked(byClientID: String?)
    /// The client int this conversation has been unblocked.
    case unblocked(byClientID: String?)
    /// The members in this conversation have been blocked.
    case membersBlocked(members: [String], byClientID: String?)
    /// The members in this conversation have been unblocked.
    case membersUnblocked(members: [String], byClientID: String?)
    /// The client in this conversation has been muted.
    case muted(byClientID: String?)
    /// The client in this conversation has been unmuted.
    case unmuted(byClientID: String?)
    /// The members in this conversation have been muted.
    case membersMuted(members: [String], byClientID: String?)
    /// The members in this conversation have been unmuted.
    case membersUnmuted(members: [String], byClientID: String?)
    /// The data of this conversation has been updated.
    case dataUpdated(updatingData: [String: Any]?, updatedData: [String: Any]?, byClientID: String?)
    /// The last message of this conversation has been updated, if *newMessage* is *false*, means the message has been modified.
    case lastMessageUpdated(newMessage: Bool)
    /// The last delivered time of message to other in this conversation has been updated.
    case lastDeliveredAtUpdated
    /// The last read time of message by other in this conversation has been updated.
    case lastReadAtUpdated
    /// The unread message count for this client in this conversation has been updated.
    case unreadMessageCountUpdated
    /// The events about message that belong to this conversation, @see `IMMessageEvent`.
    case message(event: IMMessageEvent)
}

/// The events about message that belong to the conversation.
public enum IMMessageEvent {
    /// The new message received from this conversation.
    case received(message: LCIMMessage)
    /// The message in this conversation has been updated.
    case updated(updatedMessage: LCIMMessage, reason: LCIMMessagePatchedReason?)
    /// The message has been delivered to other.
    case delivered(message: LCIMMessage)
    /// The message sent to other has been read.
    case read(lastReadAt: Date)
}

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
    
    
    var clientEvent: ((_ client: LCIMClient, _ event: IMClientEvent) -> Void)? = nil
    var conversationEvent: ((_ client: LCIMClient, _ conversation: LCIMConversation, _ event: IMConversationEvent) -> Void)? = nil
    var messageEvent: ((_ client: LCIMClient, _ conversation: LCIMConversation, _ event: IMMessageEvent) -> Void)? = nil
    
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
        clientEvent = nil
        conversationEvent = nil
        messageEvent = nil
    }

}


extension LCIMClientDelegator: LCIMClientDelegate {
    
    func callMessageEvent(_ conversation: LCIMConversation, _ event: IMMessageEvent) {
        if let messageEvent = messageEvent {
            messageEvent(conversation.imClient!, conversation, event)
        } else {
            conversationEvent?(conversation.imClient!, conversation, .message(event: event))
        }
    }
    
    func imClientResuming(_ imClient: LCIMClient) {
        imClientResuming?(imClient)
        clientEvent?(imClient, .sessionDidResume)
    }
    
    func imClientResumed(_ imClient: LCIMClient) {
        imClientResumed?(imClient)
        clientEvent?(imClient, .sessionDidOpen)
    }
   
    func imClientPaused(_ imClient: LCIMClient, error: Error?) {
        imClientPaused?(imClient, error)
        clientEvent?(imClient, .sessionDidPause(error: error))
    }
    
    func imClientClosed(_ imClient: LCIMClient, error: Error?) {
        imClientClosed?(imClient, error)
        clientEvent?(imClient, .sessionDidClose(error: error))
    }
    
    func conversation(_ conversation: LCIMConversation, didReceiveCommonMessage message: LCIMMessage) {
        didReceiveCommonMessage?(conversation, message)
        callMessageEvent(conversation, .received(message: message))
    }
    
    func conversation(_ conversation: LCIMConversation, didReceive message: LCIMTypedMessage) {
        didReceiveTypedMessage?(conversation, message)
        callMessageEvent(conversation, .received(message: message))
    }
    
    func conversation(_ conversation: LCIMConversation, messageDelivered message: LCIMMessage) {
        messageDelivered?(conversation, message)
        callMessageEvent(conversation, .delivered(message: message))
    }
    
    func conversation(_ conversation: LCIMConversation, messageHasBeenUpdated message: LCIMMessage, reason: LCIMMessagePatchedReason?) {
        messageHasBeenUpdated?(conversation, message, reason)
        callMessageEvent(conversation, .updated(updatedMessage: message, reason: reason))
    }
    
    func conversation(_ conversation: LCIMConversation, messageHasBeenRecalled message: LCIMRecalledMessage, reason: LCIMMessagePatchedReason?) {
        messageHasBeenRecalled?(conversation, message, reason)
        callMessageEvent(conversation, .updated(updatedMessage: message, reason: reason))
    }
    
    func conversation(_ conversation: LCIMConversation, membersAdded clientIds: [String]?, byClientId clientId: String?) {
        membersAdded?(conversation, clientIds, clientId)
        conversationEvent?(conversation.imClient!, conversation, .membersJoined(members: clientIds!, byClientID: clientId))
    }
    
    func conversation(_ conversation: LCIMConversation, didMuteBy byClientId: String?) {
        didMuteBy?(conversation, byClientId)
        conversationEvent?(conversation.imClient!, conversation, .muted(byClientID: byClientId))
    }

    func conversation(_ conversation: LCIMConversation, didBlockBy byClientId: String?) {
        didBlockBy?(conversation, byClientId)
        conversationEvent?(conversation.imClient!, conversation, .blocked(byClientID: byClientId))
    }

    func conversation(_ conversation: LCIMConversation, didUnmuteBy byClientId: String?) {
        didUnmuteBy?(conversation, byClientId)
        conversationEvent?(conversation.imClient!, conversation, .unmuted(byClientID: byClientId))
    }

    func conversation(_ conversation: LCIMConversation, didUnblockBy byClientId: String?) {
        didUnblockBy?(conversation, byClientId)
        conversationEvent?(conversation.imClient!, conversation, .unblocked(byClientID: byClientId))
    }

    func conversation(_ conversation: LCIMConversation, kickedByClientId clientId: String?) {
        kickedByClientId?(conversation, clientId)
        conversationEvent?(conversation.imClient!, conversation, .left(byClientID: clientId))
    }

    func conversation(_ conversation: LCIMConversation, invitedByClientId clientId: String?) {
        invitedByClientId?(conversation, clientId)
        conversationEvent?(conversation.imClient!, conversation, .joined(byClientID: clientId))
    }

    func conversation(_ conversation: LCIMConversation, didUpdateForKey key: LCIMConversationUpdatedKey) {
        didUpdateForKey?(conversation, key)
        guard let client = conversation.imClient else {
            return
        }
        switch key {
        case .lastReadAt:
            callMessageEvent(conversation, .read(lastReadAt: conversation.lastReadAt!))
        case .lastMessage:
            conversationEvent?(client, conversation, .lastMessageUpdated(newMessage: true))
        case .lastMessageAt:
            break
//            conversationEvent?(conversation.imClient!, conversation, .lastMessageUpdated(newMessage: true))
        case .lastDeliveredAt:
            conversationEvent?(client, conversation, .lastDeliveredAtUpdated)
        case .unreadMessagesCount:
            conversationEvent?(client, conversation, .unreadMessageCountUpdated)
//        case .unreadMessagesMentioned:
//            conversationEvent?(conversation.imClient!, conversation, .unreadMessageCountUpdated)
        default: break
            
        }
    }

    func conversation(_ conversation: LCIMConversation, didMembersMuteBy byClientId: String?, memberIds: [String]?) {
        didMembersMuteBy?(conversation, byClientId, memberIds)
        conversationEvent?(conversation.imClient!, conversation, .membersMuted(members: memberIds!, byClientID: byClientId))
    }

    func conversation(_ conversation: LCIMConversation, didMembersBlockBy byClientId: String?, memberIds: [String]?) {
        didMembersBlockBy?(conversation, byClientId, memberIds)
        conversationEvent?(conversation.imClient!, conversation, .membersBlocked(members: memberIds!, byClientID: byClientId))
    }

    func conversation(_ conversation: LCIMConversation, didMembersUnmuteBy byClientId: String?, memberIds: [String]?) {
        didMembersUnmuteBy?(conversation, byClientId, memberIds)
        guard let client = conversation.imClient else {
            return
        }
        conversationEvent?(client, conversation, .membersUnmuted(members: memberIds!, byClientID: byClientId))
    }

    func conversation(_ conversation: LCIMConversation, didMembersUnblockBy byClientId: String?, memberIds: [String]?) {
        didMembersUnblockBy?(conversation, byClientId, memberIds)
        conversationEvent?(conversation.imClient!, conversation, .membersUnblocked(members: memberIds!, byClientID: byClientId))
    }

    func conversation(_ conversation: LCIMConversation, membersRemoved clientIds: [String]?, byClientId clientId: String?) {
        membersRemoved?(conversation, clientIds, clientId)
        conversationEvent?(conversation.imClient!, conversation, .membersLeft(members: clientIds!, byClientID: clientId))
    }

    func conversation(_ conversation: LCIMConversation, didMemberInfoUpdateBy byClientId: String?, memberId: String?, role: LCIMConversationMemberRole) {
        didMemberInfoUpdateBy?(conversation, byClientId, memberId, role)
        conversationEvent?(conversation.imClient!, conversation, .memberInfoChanged(memberId: memberId, role: role, byClientID: byClientId))
    }

    func conversation(_ conversation: LCIMConversation, didUpdateAt date: Date?, byClientId clientId: String?, updatedData: [AnyHashable : Any]?, updatingData: [AnyHashable : Any]?) {
        didUpdateAt?(conversation, date, clientId, updatedData, updatingData)
        conversationEvent?(conversation.imClient!, conversation, .dataUpdated(updatingData: updatingData as? [String : Any], updatedData: updatedData as? [String : Any], byClientID: clientId))
    }
}

