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
    
    var garbageClients: [AVIMClient] = []
    
    override func setUp() {
        super.setUp()
        
        if self.isUseCustomTestRTMServer {
            
            AVOSCloudIM.defaultOptions().rtmServer = self.customTestRTMServer;
        }
    }
    
    override func tearDown() {
        
        for client in self.garbageClients {
            
            self.runloopTestingAsync(timeout: 10, async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                client.close(callback: { (_, _) in
                    
                    semaphore.decrement()
                })
            })
        }
        
        super.tearDown()
    }
    
    func newOpenedClient(clientId: String, tag: String? = nil, delegate: AVIMClientDelegate? = nil) -> AVIMClient? {
        
        var openedClient: AVIMClient?
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            let client: AVIMClient = AVIMClient(clientId: clientId, tag: tag)
            client.delegate = delegate
            
            semaphore.increment()
            
            client.open(with: .forceOpen, callback: { (succeeded: Bool, error: Error?) in
                
                semaphore.decrement()
                
                if succeeded {
                    
                    openedClient = client
                }
            })
        })
        
        return openedClient
    }
    
    func recycleClient(_ client: AVIMClient) {
        
        self.garbageClients.append(client)
    }
    
}
