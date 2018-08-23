//
//  LCRouterTestCase.swift
//  AVOSCloud-iOSTests
//
//  Created by zapcannon87 on 2018/8/22.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class LCRouterTestCase: LCTestBase {
    
    // MARK: - Server Testing
    
    func tests_get_app_router() {
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            LCRouter.sharedInstance().getAppRouterData(withAppID: AVOSCloud.getApplicationId(), callback: { (data: [AnyHashable : Any]?, error: Error?) in
                semaphore.decrement()
                XCTAssertNotNil(data)
                XCTAssertNil(error)
                XCTAssertNotNil(data?[RouterKey.appAPIServer.rawValue])
                XCTAssertNotNil(data?[RouterKey.appPushServer.rawValue])
                XCTAssertNotNil(data?[RouterKey.appStatsServer.rawValue])
                XCTAssertNotNil(data?[RouterKey.appEngineServer.rawValue])
                XCTAssertNotNil(data?[RouterKey.appRTMRouterServer.rawValue])
                XCTAssertNotNil(data?[RouterKey.TTL.rawValue])
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func tests_get_rtm_router() {
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment(2)
            let appID: String = AVOSCloud.getApplicationId()
            LCRouter.sharedInstance().tryUpdateAppRouter(withAppID: appID, callback: { (error: Error?) in
                semaphore.decrement()
                XCTAssertNil(error)
                let RTMRouterURL: String = LCRouter.sharedInstance().rtmRouterURL(forAppID: appID)
                LCRouter.sharedInstance().getRTMRouterData(withAppID: appID, rtmRouterURL: RTMRouterURL, callback: { (data: [AnyHashable : Any]?, error: Error?) in
                    semaphore.decrement()
                    XCTAssertNotNil(data)
                    XCTAssertNil(error)
                    XCTAssertNotNil(data?[RouterKey.rtmServer.rawValue])
                    XCTAssertNotNil(data?[RouterKey.rtmGroupID.rawValue])
                    XCTAssertNotNil(data?[RouterKey.rtmGroupUrl.rawValue])
                    XCTAssertNotNil(data?[RouterKey.rtmSecondary.rawValue])
                    XCTAssertNotNil(data?[RouterKey.TTL.rawValue])
                })
            })
        }, failure: { XCTFail("timeout") })
    }
    
    // MARK: - Client Testing
    
    func testc_get_app_router() {
        
        if self.isServerTesting {
            return
        }
        
        for appID in [TestApp.ChinaNorth.appInfo.id, TestApp.ChinaEast.appInfo.id, TestApp.US.appInfo.id] {
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                LCRouter.sharedInstance().getAppRouterData(withAppID: appID, callback: { (data: [AnyHashable : Any]?, error: Error?) in
                    semaphore.decrement()
                    XCTAssertNotNil(data)
                    XCTAssertNil(error)
                    XCTAssertNotNil(data?[RouterKey.appAPIServer.rawValue])
                    XCTAssertNotNil(data?[RouterKey.appPushServer.rawValue])
                    XCTAssertNotNil(data?[RouterKey.appStatsServer.rawValue])
                    XCTAssertNotNil(data?[RouterKey.appEngineServer.rawValue])
                    XCTAssertNotNil(data?[RouterKey.appRTMRouterServer.rawValue])
                    XCTAssertNotNil(data?[RouterKey.TTL.rawValue])
                })
            }, failure: { XCTFail("timeout") })
        }
    }
    
    func testc_get_rtm_router() {
        
        if self.isServerTesting {
            return
        }
        
        let originAppID: String = AVOSCloud.getApplicationId()
        let originAppKey: String = AVOSCloud.getClientKey()
        for appInfo in [TestApp.ChinaNorth.appInfo, TestApp.ChinaEast.appInfo, TestApp.US.appInfo] {
            AVOSCloud.setApplicationId(appInfo.id, clientKey: appInfo.key)
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment(2)
                LCRouter.sharedInstance().tryUpdateAppRouter(withAppID: appInfo.id, callback: { (error: Error?) in
                    semaphore.decrement()
                    XCTAssertNil(error)
                    let RTMRouterURL: String = LCRouter.sharedInstance().rtmRouterURL(forAppID: appInfo.id)
                    LCRouter.sharedInstance().getRTMRouterData(withAppID: appInfo.id, rtmRouterURL: RTMRouterURL, callback: { (data: [AnyHashable : Any]?, error: Error?) in
                        semaphore.decrement()
                        XCTAssertNotNil(data)
                        XCTAssertNil(error)
                        XCTAssertNotNil(data?[RouterKey.rtmServer.rawValue])
                        XCTAssertNotNil(data?[RouterKey.rtmGroupID.rawValue])
                        XCTAssertNotNil(data?[RouterKey.rtmGroupUrl.rawValue])
                        XCTAssertNotNil(data?[RouterKey.rtmSecondary.rawValue])
                        XCTAssertNotNil(data?[RouterKey.TTL.rawValue])
                    })
                })
            }, failure: { XCTFail("timeout") })
        }
        AVOSCloud.setApplicationId(originAppID, clientKey: originAppKey)
    }
    
    func testc_router_cache() {
        
        if self.isServerTesting {
            return
        }
        
        let appID: String = AVOSCloud.getApplicationId()
        let appRouterCachePath: String = LCRouter.routerCacheDirectoryPath() + "/" + RouterCacheKey.app.rawValue
        let RTMRouterCachePath: String = LCRouter.routerCacheDirectoryPath() + "/" + RouterCacheKey.RTM.rawValue
        LCRouter.sharedInstance().cleanCache(withKey: .app, error: nil)
        LCRouter.sharedInstance().cleanCache(withKey: .RTM, error: nil)
        XCTAssertFalse(FileManager.default.fileExists(atPath: appRouterCachePath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: RTMRouterCachePath))
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            LCRouter.sharedInstance().tryUpdateAppRouter(withAppID: appID, callback: { (error: Error?) in
                semaphore.decrement()
                XCTAssertNil(error)
                XCTAssertTrue(FileManager.default.fileExists(atPath: appRouterCachePath))
            })
        }, failure: { XCTFail("timeout") })
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            let RTMRouterURL: String = LCRouter.sharedInstance().rtmRouterURL(forAppID: appID)
            semaphore.increment()
            LCRouter.sharedInstance().getAndCacheRTMRouterData(withAppID: appID, rtmRouterURL: RTMRouterURL, callback: { (data: [AnyHashable : Any]?, error: Error?) in
                semaphore.decrement()
                XCTAssertTrue(FileManager.default.fileExists(atPath: RTMRouterCachePath))
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func testc_router_fallback_url() {
        
        if self.isServerTesting {
            return
        }
        
        let appID: String = AVOSCloud.getApplicationId()
        let moduleKeys: [String] = [
            RouterKey.appAPIServer.rawValue,
            RouterKey.appPushServer.rawValue,
            RouterKey.appStatsServer.rawValue,
            RouterKey.appEngineServer.rawValue,
            RouterKey.appRTMRouterServer.rawValue
        ]
        
        RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
            semaphore.increment()
            LCRouter.sharedInstance().getAppRouterData(withAppID: appID, callback: { (data: [AnyHashable : Any]?, error: Error?) in
                semaphore.decrement()
                XCTAssertNotNil(data)
                XCTAssertNil(error)
                for key in moduleKeys {
                    XCTAssertEqual(data?[key] as? String, LCRouter.sharedInstance().appRouterFallbackURL(withKey: key, appID: appID))
                }
            })
        }, failure: { XCTFail("timeout") })
    }
    
    func testc_router_custom_url() {
        
        if self.isServerTesting {
            return
        }
        
        let appID: String = AVOSCloud.getApplicationId()
        let router: LCRouter = LCRouter.sharedInstance()
        
        let modules: [AVServiceModule] = [.API, .push, .engine, .statistics, .RTM]
        let customAPIURLString: String = "beta.leancloud.cn"
        let customRTMRouterURLString: String = "router-g0-push.leancloud.cn"
        for item in modules {
            if item == .RTM {
                AVOSCloud.setServerURLString(customRTMRouterURLString, for: .RTM)
            } else {
                AVOSCloud.setServerURLString(customAPIURLString, for: item)
            }
        }
        
        XCTAssertTrue(router.appURL(forPath: "push", appID: appID).contains(customAPIURLString))
        XCTAssertTrue(router.appURL(forPath: "call", appID: appID).contains(customAPIURLString))
        XCTAssertTrue(router.appURL(forPath: "stats", appID: appID).contains(customAPIURLString))
        XCTAssertTrue(router.appURL(forPath: "user", appID: appID).contains(customAPIURLString))
        XCTAssertTrue(router.rtmRouterURL(forAppID: appID).contains(customRTMRouterURLString))
        
        for item in modules {
            AVOSCloud.setServerURLString(nil, for: item)
        }
        
        XCTAssertFalse(router.appURL(forPath: "push", appID: appID).contains(customAPIURLString))
        XCTAssertFalse(router.appURL(forPath: "call", appID: appID).contains(customAPIURLString))
        XCTAssertFalse(router.appURL(forPath: "stats", appID: appID).contains(customAPIURLString))
        XCTAssertFalse(router.appURL(forPath: "user", appID: appID).contains(customAPIURLString))
        XCTAssertFalse(router.rtmRouterURL(forAppID: appID).contains(customRTMRouterURLString))
    }
    
}
