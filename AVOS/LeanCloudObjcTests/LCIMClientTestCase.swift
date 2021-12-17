//
//  LCIMClientTestCase.swift
//  LeanCloudObjcTests
//
//  Created by 黄驿峰 on 2021/12/15.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import Foundation
import XCTest
@testable import LeanCloudObjc

extension LCIMClientTestCase {
    func openClient(clientID: String, tag: String? = nil, delegator: LCIMClientDelegator? = nil) -> LCIMClient {
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
    
    //    class SignatureDelegator: NSObject, LCIMSignatureDataSource {
    //
    //        var sessionToken: String?
    //
    //        func getOpenSignature(client: LCIMClient, completion: @escaping (LCIMSignature) -> Void) {
    //            guard let sessionToken = self.sessionToken else {
    //                XCTFail()
    //                return
    //            }
    //            LCHTTPSessionManager.init()
    //            _ = client.application.httpClient.request(
    //                url: client.application.v2router.route(
    //                    path: "rtm/clients/sign",
    //                    module: .api)!,
    //                method: .get,
    //                parameters: ["session_token": sessionToken])
    //            { (response) in
    //                guard let value = response.value as? [String: Any],
    //                      let client_id = value["client_id"] as? String,
    //                      client_id == client.ID,
    //                      let signature = value["signature"] as? String,
    //                      let timestamp = value["timestamp"] as? Int64,
    //                      let nonce = value["nonce"] as? String else {
    //                          XCTFail()
    //                          return
    //                      }
    //                completion(IMSignature(
    //                    signature: signature,
    //                    timestamp: timestamp,
    //                    nonce: nonce))
    //            }
    //        }
    //
    //        func client(_ client: LCIMClient, action: LCIMSignatureAction, conversation: LCIMConversation?, clientIds: [String]?, signatureHandler handler: @escaping (LCIMSignature?) -> Void) {
    //            XCTAssertTrue(Thread.isMainThread)
    //            if action == .open {
    //
    //            } else {
    //
    //            }
    //        }
    //    }
}



class LCIMClientTestCase: BaseTestCase {
    
    func testInit() {
        do {
            let invalidID: String = Array<String>.init(repeating: "a", count: 65).joined()
            let _ = try LCIMClient.init(clientId: invalidID)
            XCTFail()
        } catch {
            
        }
        
        do {
            let invalidTag: String = "default"
            let _ = try LCIMClient(clientId: uuid, tag: invalidTag)
            XCTFail()
        } catch {
        }
        
        do {
            let _ = try LCIMClient.init(clientId: uuid)
            let _ = try LCIMClient.init(clientId: uuid, tag: uuid)
        } catch {
            XCTFail("\(error)")
        }
    }
    

    
    func testInitWithUser() {
        let user = LCUser()
        user.username = uuid
        user.password = uuid

        expecting { exp in
            user.signUpInBackground { ret, error in
                XCTAssertNil(error)
                XCTAssertTrue(ret)
                exp.fulfill()
            }
        }

        do {
            let client = try LCIMClient.init(user: user)
            XCTAssertNotNil(client.user)
            XCTAssertEqual(client.clientId, user.objectId)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testDeinit() {
        var client: LCIMClient? = try? LCIMClient.init(clientId: uuid, tag: uuid)
        XCTAssertNotNil(client)
        weak var wClient: LCIMClient? = client
        client = nil
        delay()
        XCTAssertNil(wClient)
    }

    func testOpenAndClose() {
        let client: LCIMClient! = try? LCIMClient.init(clientId: uuid)
        XCTAssertNotNil(client)

        expecting { (exp) in
            client.open { ret, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                XCTAssertNotNil(client.sessionToken)
                XCTAssertNotNil(client.sessionTokenExpiration)
                XCTAssertNil(client.openingCompletion)
                XCTAssertEqual(client.status, .opened)
                XCTAssertNotNil(client.connectionDelegator.delegate)
                exp.fulfill()
            }
        }

        expecting { (exp) in
            client.open { ret, error in
                XCTAssertFalse(ret)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }

        expecting { (exp) in
            client.close { ret, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                XCTAssertNil(client.sessionToken)
                XCTAssertNil(client.sessionTokenExpiration)
                XCTAssertNil(client.openingCompletion)
                XCTAssertEqual(client.status, .closed)
                XCTAssertNil(client.connectionDelegator.delegate)
                exp.fulfill()
            }
        }
    }

//    func testOpenWithSignature() {
//        let user = LCUser()
//        user.username = uuid
//        user.password = uuid
//        expecting { exp in
//            user.signUpInBackground { ret, error in
//                XCTAssertNil(error)
//                XCTAssertTrue(ret)
//                exp.fulfill()
//            }
//        }
//
//        guard let objectID = user.objectId,
//              let sessionToken = user.sessionToken else {
//                  XCTFail()
//                  return
//              }
//
////        do {
////            let client = try LCIMClient.init(user: user)
////            XCTAssertNotNil(client.user)
////            XCTAssertEqual(client.clientId, user.objectId)
////        } catch {
////            XCTFail("\(error)")
////        }
//        var clientFromUser: LCIMClient! = try? LCIMClient.init(user: user)
//        XCTAssertNotNil(clientFromUser)
//
//        expecting { (exp) in
//            clientFromUser.open { ret, error in
//                XCTAssertTrue(ret)
//                XCTAssertNil(error)
//                exp.fulfill()
//            }
//        }
//        clientFromUser = nil
//        delay()
//
//        let signatureDelegator = SignatureDelegator()
//        signatureDelegator.sessionToken = sessionToken
//        let clientFromID = try! IMClient(
//            ID: objectID,
//            options: [],
//            signatureDelegate: signatureDelegator)
//        expecting { (exp) in
//            clientFromID.open(completion: { (result) in
//                XCTAssertTrue(result.isSuccess)
//                XCTAssertNil(result.error)
//                exp.fulfill()
//            })
//        }
//    }
//



    func testDelegateEvent() {
        let delegator = LCIMClientDelegator.init()
        let client = openClient(clientID: uuid, delegator: delegator)
        
        expecting { exp in
            client.connection.disconnect()
            delegator.imClientPaused = {
                imClient, error in
                XCTAssertEqual(imClient, client)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
        
        expecting(count: 2) { exp in
            client.connection.testConnect()
            delegator.imClientResumed = {
                imClient in
                XCTAssertEqual(imClient, client)
                exp.fulfill()
            }
            
            delegator.imClientResuming = {
                imClient in
                XCTAssertEqual(imClient, client)
                exp.fulfill()
            }
        }

    }
    
    

    func testSessionConflict() {


        let clientID: String = uuid
        let tag: String = "tag"

        let installation1: LCInstallation! = LCInstallation.init()
        installation1.setDeviceTokenHexString(uuid, teamId: "LeanCloud")
        XCTAssertTrue(installation1.save())
        
        let delegator1 = LCIMClientDelegator.init()
        let client1: LCIMClient! = try? LCIMClient.init(clientId: clientID, tag: tag, installation: installation1)
        XCTAssertNotNil(client1)
        client1.delegate = delegator1
        expecting { (exp) in
            client1.open { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }

        LCRTMConnectionManager.shared().imProtobuf1Registry.removeAllObjects()
        LCRTMConnectionManager.shared().imProtobuf3Registry.removeAllObjects()
        
        let installation2 = LCInstallation.init()
        installation2.setDeviceTokenHexString(uuid, teamId: "LeanCloud")
        XCTAssertTrue(installation2.save())

        let delegator2 = LCIMClientDelegator.init()
        let client2: LCIMClient! = try? LCIMClient.init(clientId: clientID, tag: tag, installation: installation2)
        XCTAssertNotNil(client2)
        client2.delegate = delegator2

        expecting(
            description: "client2 open success & kick client1 success",
            count: 2) { exp in
                client2.open { ret, error in
                    XCTAssertTrue(ret)
                    XCTAssertNil(error)
                    exp.fulfill()
                }
                delegator1.imClientClosed = {
                    imClient, error in
                    XCTAssertNotNil(error)
                    if let error = error as NSError? {
                        XCTAssertEqual(LCIMErrorCode.sessionConflict.rawValue, error.code)
                    } else {
                        XCTFail()
                    }
                    exp.fulfill()
                }
            }
        
        expecting(
            description: "client1 resume with deviceToken1 fail",
            count: 1)
        { (exp) in
            client1.open(with: .reopen) { ret, error in
                if let error = error as NSError? {
                    XCTAssertEqual(LCIMErrorCode.sessionConflict.rawValue, error.code)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }
        
        expecting(
            description: "client1 set deviceToken2 then resume success",
            count: 1)
        { (exp) in
            client1.open(with: .reopen) { ret, error in
                if let error = error as NSError? {
                    XCTAssertEqual(LCIMErrorCode.sessionConflict.rawValue, error.code)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
           
        }
        
        installation1.setDeviceTokenHexString(installation2.deviceToken!, teamId: "LeanCloud")
        XCTAssertTrue(installation1.save())
        
        expecting(
            description: "client1 set deviceToken2 then resume success",
            count: 1)
        { (exp) in
            client1.open(with: .reopen) { ret, error in
                XCTAssertTrue(ret)
                XCTAssertNil(error)
                exp.fulfill()
            }
           
        }
    }



    func testSessionTokenExpired() {
        let delegator = LCIMClientDelegator.init()
        let client = openClient(clientID: uuid, tag: nil, delegator: delegator)

        client.sessionToken = self.uuid
        client.sessionTokenExpiration = Date(timeIntervalSinceNow: 36000)

//        var ob: NSObjectProtocol? = nil
        expecting(
            description: "Pause -> Resume -> First-Reopen Then session token expired, Final Second-Reopen success",
            count: 3)
        { (exp) in
            delegator.imClientPaused = {
                imClient, error in
                XCTAssertEqual(imClient, client)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
            delegator.imClientResumed = {
                imClient in
                XCTAssertEqual(imClient, client)
                exp.fulfill()
            }
            
            delegator.imClientResuming = {
                imClient in
                XCTAssertEqual(imClient, client)
                exp.fulfill()
            }

//            ob = NotificationCenter.default.addObserver(
//                forName: IMClient.TestSessionTokenExpiredNotification,
//                object: client,
//                queue: .main
//            ) { (notification) in
//                XCTAssertEqual(
//                    (notification.userInfo?["error"] as? LCError)?.code,
//                    LCError.ServerErrorCode.sessionTokenExpired.rawValue)
//                exp.fulfill()
//            }
            client.connection.disconnect()
            client.connection.testConnect()
        }
        
//        if let ob = ob {
//            NotificationCenter.default.removeObserver(ob)
//        }
    }

//    func testReportDeviceToken() {
//        let application = LCApplication.default
//        let currentDeviceToken = application.currentInstallation.deviceToken?.value
//        let client: IMClient = try! IMClient(application: application, ID: uuid, options: [])
//        delay()
//        XCTAssertEqual(currentDeviceToken, client.currentDeviceToken)
//
//        let exp = expectation(description: "client report device token success")
//        exp.expectedFulfillmentCount = 2
//        let otherDeviceToken: String = uuid
//        let ob = NotificationCenter.default.addObserver(forName: IMClient.TestReportDeviceTokenNotification, object: client, queue: OperationQueue.main) { (notification) in
//            let result = notification.userInfo?["result"] as? RTMConnection.CommandCallback.Result
//            XCTAssertEqual(result?.command?.cmd, .report)
//            XCTAssertEqual(result?.command?.op, .uploaded)
//            exp.fulfill()
//        }
//        client.open { (result) in
//            XCTAssertTrue(result.isSuccess)
//            client.installation.set(deviceToken: otherDeviceToken, apnsTeamId: "")
//            exp.fulfill()
//        }
//        wait(for: [exp], timeout: timeout)
//        XCTAssertEqual(otherDeviceToken, client.currentDeviceToken)
//        NotificationCenter.default.removeObserver(ob)
//    }

    func testSessionQuery() {

        let client1ID = uuid
        let client2ID = uuid
        let client1 = openClient(clientID: client1ID)
        expecting { exp in
            client1.queryOnlineClients(inClients: []) { inClients, error in
                XCTAssertEqual(inClients, [])
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        var set = [String]()
        for _ in 0...20 {
            set.append(uuid)
        }
        
        expecting { exp in
            client1.queryOnlineClients(inClients: set) { inClients, error in
                XCTAssertNotNil(error)
                XCTAssertNil(inClients)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            client1.queryOnlineClients(inClients: [client2ID]) { inClients, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertEqual(inClients?.count, 0)
                exp.fulfill()
            }
        }
        
        let client2 = openClient(clientID: client2ID)

        expecting { exp in
            client1.queryOnlineClients(inClients: [client2ID]) { inClients, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertEqual(inClients?.count, 1)
                XCTAssertEqual(inClients?.first, client2.clientId)
                exp.fulfill()
            }
        }
    }

//#if canImport(GRDB)
//    func testPrepareLocalStorage() {
//        expecting { (exp) in
//            let notUseLocalStorageClient = try! IMClient(ID: uuid, options: [])
//            do {
//                try notUseLocalStorageClient.prepareLocalStorage(completion: { (_) in })
//                XCTFail()
//            } catch {
//                XCTAssertTrue(error is LCError)
//            }
//            exp.fulfill()
//        }
//
//        let client = try! IMClient(ID: uuid)
//
//        expecting { (exp) in
//            try! client.prepareLocalStorage(completion: { (result) in
//                XCTAssertTrue(Thread.isMainThread)
//                XCTAssertTrue(result.isSuccess)
//                XCTAssertNil(result.error)
//                exp.fulfill()
//            })
//        }
//    }
//
//    func testGetAndLoadStoredConversations() {
//        expecting { (exp) in
//            let notUseLocalStorageClient = try! IMClient(ID: uuid, options: [])
//            do {
//                try notUseLocalStorageClient.getAndLoadStoredConversations(completion: { (_) in })
//                XCTFail()
//            } catch {
//                XCTAssertTrue(error is LCError)
//            }
//            exp.fulfill()
//        }
//
//        let client = try! IMClient(ID: uuid)
//
//        expecting { (exp) in
//            try! client.prepareLocalStorage(completion: { (result) in
//                XCTAssertTrue(result.isSuccess)
//                XCTAssertNil(result.error)
//                exp.fulfill()
//            })
//        }
//
//        expecting { (exp) in
//            try! client.getAndLoadStoredConversations(completion: { (result) in
//                XCTAssertTrue(Thread.isMainThread)
//                XCTAssertTrue(result.isSuccess)
//                XCTAssertNil(result.error)
//                XCTAssertEqual(result.value?.count, 0)
//                XCTAssertTrue(client.convCollection.isEmpty)
//                exp.fulfill()
//            })
//        }
//
//        expecting { (exp) in
//            client.open(completion: { (result) in
//                XCTAssertTrue(result.isSuccess)
//                XCTAssertNil(result.error)
//                exp.fulfill()
//            })
//        }
//
//        for _ in 0...1 {
//            var conv: IMConversation!
//
//            expecting { (exp) in
//                try! client.createConversation(clientIDs: [uuid], completion: { (result) in
//                    XCTAssertTrue(result.isSuccess)
//                    XCTAssertNil(result.error)
//                    conv = result.value
//                    exp.fulfill()
//                })
//            }
//
//            delay(seconds: 0.1)
//
//            expecting { (exp) in
//                try! conv.refresh(completion: { (result) in
//                    XCTAssertTrue(result.isSuccess)
//                    XCTAssertNil(result.error)
//                    exp.fulfill()
//                })
//            }
//
//            delay(seconds: 0.1)
//
//            expecting { (exp) in
//                let message = IMMessage()
//                try! message.set(content: .string("test"))
//                try! conv.send(message: message, completion: { (result) in
//                    XCTAssertTrue(result.isSuccess)
//                    XCTAssertNil(result.error)
//                    exp.fulfill()
//                })
//            }
//        }
//
//        let checker: (IMClient.StoredConversationOrder) -> Void = { order in
//            self.expecting { (exp) in
//                try! client.getAndLoadStoredConversations(order: order, completion: { (result) in
//                    XCTAssertTrue(result.isSuccess)
//                    XCTAssertNil(result.error)
//                    XCTAssertEqual(result.value?.count, 2)
//                    switch order {
//                    case let .lastMessageSentTimestamp(descending: descending):
//                        let firstTimestamp = result.value?.first?.lastMessage?.sentTimestamp
//                        let lastTimestamp = result.value?.last?.lastMessage?.sentTimestamp
//                        if descending {
//                            XCTAssertGreaterThanOrEqual(firstTimestamp!, lastTimestamp!)
//                        } else {
//                            XCTAssertGreaterThanOrEqual(lastTimestamp!, firstTimestamp!)
//                        }
//                    case let .createdTimestamp(descending: descending):
//                        let firstTimestamp = result.value?.first?.createdAt?.timeIntervalSince1970
//                        let lastTimestamp = result.value?.last?.createdAt?.timeIntervalSince1970
//                        if descending {
//                            XCTAssertGreaterThanOrEqual(firstTimestamp!, lastTimestamp!)
//                        } else {
//                            XCTAssertGreaterThanOrEqual(lastTimestamp!, firstTimestamp!)
//                        }
//                    case let .updatedTimestamp(descending: descending):
//                        let firstTimestamp = result.value?.first?.updatedAt?.timeIntervalSince1970
//                        let lastTimestamp = result.value?.last?.updatedAt?.timeIntervalSince1970
//                        if descending {
//                            XCTAssertGreaterThanOrEqual(firstTimestamp!, lastTimestamp!)
//                        } else {
//                            XCTAssertGreaterThanOrEqual(lastTimestamp!, firstTimestamp!)
//                        }
//                    }
//                    exp.fulfill()
//                })
//            }
//        }
//
//        checker(.lastMessageSentTimestamp(descending: true))
//        checker(.lastMessageSentTimestamp(descending: false))
//        checker(.updatedTimestamp(descending: true))
//        checker(.updatedTimestamp(descending: false))
//        checker(.createdTimestamp(descending: true))
//        checker(.createdTimestamp(descending: false))
//
//        XCTAssertEqual(client.convCollection.count, 2)
//    }
//#endif
}


