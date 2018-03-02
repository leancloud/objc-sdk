//
//  AppDelegate.swift
//  RuntimeTestDemo
//
//  Created by zapcannon87 on 18/01/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import UIKit
import AVOSCloud
import AVOSCloudIM
import AVOSCloudLiveQuery

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    let kLCTestBase_IsSelectRegion_US: Bool = false
    
    // US
    let kLCTestBase_AppId_US: String = "kknqydxqd9wdq4cboy1dvvug5ha0ce3i2mrerrdrmr6pla1p"
    let kLCTestBase_AppKey_US: String = "fate582pwsfh97s9o99nw91a152i7ndm9tsy866e6wpezth4"
    // CN
    let kLCTestBase_AppId_CN: String = "nq0awk3lh1dpmbkziz54377mryii8ny4xvp6njoygle5nlyg"
    let kLCTestBase_AppKey_CN: String = "6vdnmdkdi4fva9i06lt50s4mcsfhppjpzm3zf5zjc9ty4pdz"

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        let appId: String
        let appKey: String
        
        if kLCTestBase_IsSelectRegion_US {
            
            appId = kLCTestBase_AppId_US
            appKey = kLCTestBase_AppKey_US
            
        } else {
            
            appId = kLCTestBase_AppId_CN
            appKey = kLCTestBase_AppKey_CN
        }
        
        AVOSCloud.setApplicationId(appId, clientKey: appKey)
        AVOSCloud.setAllLogsEnabled(true)
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

}

