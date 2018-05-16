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

    let isUseCustomTestRTMServer: Bool = true;
    let customTestRTMServer: String = "wss://rtm51.leancloud.cn"; /* internal test server */
    
    var clientDustbin: [AVIMClient] = []
    
    override func setUp() {
        super.setUp()
        AVOSCloudIM.defaultOptions().rtmServer = self.isUseCustomTestRTMServer ? self.customTestRTMServer : nil
    }
    
    override func tearDown() {
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
        return openedClient
    }
    
    func recycleClient(_ client: AVIMClient?) {
        if let _client: AVIMClient = client {
            self.clientDustbin.append(_client)
        }
    }
    
}
