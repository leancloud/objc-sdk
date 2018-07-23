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
    
    static var sharedIM: Int = {
        AVIMClient.setUnreadNotificationEnabled(true)
        return 0
    }()
    
    override class func setUp() {
        super.setUp()
        let _ = LCIMTestBase.sharedIM
    }
    
    static var clientDustbin: [AVIMClient] = []
    
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
    
    func newOpenedClient(
        clientId: String,
        tag: String? = nil,
        delegate: AVIMClientDelegate? = nil,
        installation: AVInstallation = AVInstallation.default(),
        assertInternalQuietCallback: Bool = true
        ) -> AVIMClient?
    {
        var openedClient: AVIMClient? = nil
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            let client: AVIMClient = AVIMClient(clientId: clientId, tag: tag, installation: installation)
            if assertInternalQuietCallback {
                client.assertInternalQuietCallback = { XCTAssertNil($0) }
            }
            client.delegate = delegate
            semaphore.increment()
            client.open(with: .forceOpen, callback: { (succeeded: Bool, error: Error?) in
                semaphore.decrement()
                openedClient = succeeded ? client : nil
            })
        })
        if let client: AVIMClient = openedClient {
            LCIMTestBase.clientDustbin.append(client)
        }
        return openedClient
    }
    
}
