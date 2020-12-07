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
        AVIMClient.setUnreadNotificationEnabled(true)
    }
    
    func purgeConnectionRegistry() {
        LCRTMConnectionManager.shared().liveQueryRegistry.removeAllObjects()
        LCRTMConnectionManager.shared().imProtobuf1Registry.removeAllObjects()
        LCRTMConnectionManager.shared().imProtobuf3Registry.removeAllObjects()
    }
}
