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
    
    static var clientDustbin: [AVIMClient] = []
    
    override class func setUp() {
        super.setUp()
        AVOSCloudIM.defaultOptions().rtmServer = "wss://rtm51.leancloud.cn"
        AVIMClient.setUnreadNotificationEnabled(true)
    }
    
    override class func tearDown() {
        for client in self.clientDustbin {
            self.runloopTestingAsync(timeout: 10, async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                client.close(callback: { (_, _) in
                    semaphore.decrement()
                })
            })
        }
        super.tearDown()
    }
    
    func newOpenedClient(
        clientId: String,
        tag: String? = nil,
        delegate: AVIMClientDelegate? = nil,
        installation: AVInstallation = AVInstallation.default()
        ) -> AVIMClient?
    {
        var openedClient: AVIMClient?
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            let client: AVIMClient = AVIMClient(clientId: clientId, tag: tag, installation: installation)
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
