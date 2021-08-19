//
//  LCLeaderboardTestCase.swift
//  LeanCloudObjcTests
//
//  Created by pzheng on 2021/08/19.
//  Copyright © 2021 LeanCloud Inc. All rights reserved.
//

import XCTest
@testable import LeanCloudObjc

class LCLeaderboardTestCase: BaseTestCase {
    
    func testWithoutCurrentUser() {
        expecting { exp in
            LCLeaderboard.updateCurrentUserStatistics([uuid : uuid]) { statistics, error in
                XCTAssertNil(statistics)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            LCLeaderboard.deleteCurrentUserStatistics([uuid]) { succeeded, error in
                XCTAssertFalse(succeeded)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
        
        let option = LCLeaderboardQueryOption()
        option.selectKeys = [uuid]
        option.includeKeys = [uuid]
        
        expecting { exp in
            LCLeaderboard.getStatisticsWithUserId(uuid, statisticNames: nil, option: option) { statistics, error in
                XCTAssertNil(statistics)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
        
        let leaderboard = LCLeaderboard(statisticName: uuid)
        
        expecting { exp in
            leaderboard.getStatisticsWithUserIds([uuid], option: option) { statistics, error in
                XCTAssertNil(statistics)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            leaderboard.getUserResults(with: option) { rankings, count, error in
                XCTAssertNil(rankings)
                XCTAssertEqual(count, -1)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            leaderboard.getUserResultsAroundUser(uuid, option: option) { rankings, count, error in
                XCTAssertNil(rankings)
                XCTAssertEqual(count, -1)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testInvalidParameter() {
        let user = LCUser()
        expecting { exp in
            user.login(withAuthData: ["openid" : uuid], platformId: "test", options: nil) { _, error in
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            LCLeaderboard.updateCurrentUserStatistics([:]) { statistics, error in
                XCTAssertNil(statistics)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            LCLeaderboard.deleteCurrentUserStatistics([]) { succeeded, error in
                XCTAssertFalse(succeeded)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            LCLeaderboard.getStatisticsWithUserId("", statisticNames: nil, option: nil) { statistics, error in
                XCTAssertNil(statistics)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
        
        let leaderboard = LCLeaderboard(statisticName: uuid)
        
        expecting { exp in
            leaderboard.getStatisticsWithUserIds([], option: nil) { statistics, error in
                XCTAssertNil(statistics)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
        
        LCUser.logOut()
    }
    
    func testGetUserStatistics() {
        let object = LCObject()
        XCTAssertTrue(object.save())
        let user = LCUser()
        let objectFieldKey = "objectField"
        user[objectFieldKey] = object
        expecting { exp in
            user.login(withAuthData: ["openid" : uuid], platformId: "test", options: nil) { _, error in
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        guard let userObjectId = user.objectId else {
            XCTFail()
            return
        }
        
        let statisticName0 = "test0"
        let statisticName1 = "test1"
        
        expecting { exp in
            LCLeaderboard.updateCurrentUserStatistics(
                [statisticName0 : 100,
                 statisticName1 : 100])
            { statistics, error in
                XCTAssertEqual(statistics?.count, 2)
                XCTAssertNil(error)
                XCTAssertNotEqual(statistics?.first?.name, statistics?.last?.name)
                for item in statistics ?? [] {
                    XCTAssertTrue([statisticName0, statisticName1].contains(item.name ?? ""))
                    XCTAssertEqual(item.value, 100)
                    XCTAssertGreaterThanOrEqual(item.version, 0)
                }
                exp.fulfill()
            }
        }
        
        let option = LCLeaderboardQueryOption()
        option.selectKeys = ["username", objectFieldKey]
        option.includeKeys = [objectFieldKey]
        
        expecting { exp in
            LCLeaderboard.getStatisticsWithUserId(
                userObjectId,
                statisticNames: [statisticName0, statisticName1],
                option: option)
            { statistics, error in
                XCTAssertEqual(statistics?.count, 2)
                XCTAssertNil(error)
                XCTAssertNotEqual(statistics?.first?.name, statistics?.last?.name)
                for item in statistics ?? [] {
                    XCTAssertTrue([statisticName0, statisticName1].contains(item.name ?? ""))
                    XCTAssertEqual(item.value, 100)
                    XCTAssertGreaterThanOrEqual(item.version, 0)
                    XCTAssertNotNil(item.user?["username"])
                    XCTAssertTrue(item.user?[objectFieldKey] is LCObject)
                    XCTAssertNil(item.object)
                    XCTAssertNil(item.entity)
                }
                exp.fulfill()
            }
        }
        
        let leaderboard0 = LCLeaderboard(statisticName: statisticName0)
        let leaderboard1 = LCLeaderboard(statisticName: statisticName1)
        
        expecting(count: 2) { exp in
            leaderboard0.getStatisticsWithUserIds([userObjectId], option: option) { statistics, error in
//                XCTAssertEqual(statistics?.count, 1)
//                XCTAssertNil(error)
//                XCTAssertEqual(leaderboard0.statisticName, statistics?.first?.name)
//                XCTAssertEqual(statistics?.first?.value, 100)
//                XCTAssertGreaterThanOrEqual(statistics?.first?.version ?? -1, 0)
//                XCTAssertNotNil(statistics?.first?.user?["username"])
//                XCTAssertTrue(statistics?.first?.user?[objectFieldKey] is LCObject)
//                XCTAssertNil(statistics?.first?.object)
//                XCTAssertNil(statistics?.first?.entity)
                exp.fulfill()
            }
            leaderboard1.getStatisticsWithUserIds([userObjectId], option: option) { statistics, error in
//                XCTAssertEqual(statistics?.count, 1)
//                XCTAssertNil(error)
//                XCTAssertEqual(leaderboard1.statisticName, statistics?.first?.name)
//                XCTAssertEqual(statistics?.first?.value, 100)
//                XCTAssertGreaterThanOrEqual(statistics?.first?.version ?? -1, 0)
//                XCTAssertNotNil(statistics?.first?.user?["username"])
//                XCTAssertTrue(statistics?.first?.user?[objectFieldKey] is LCObject)
//                XCTAssertNil(statistics?.first?.object)
//                XCTAssertNil(statistics?.first?.entity)
                exp.fulfill()
            }
        }
        
        expecting { exp in
            LCLeaderboard.deleteCurrentUserStatistics([statisticName0, statisticName1]) { succeeded, error in
                XCTAssertTrue(succeeded)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
        
        LCUser.logOut()
    }
    
    
}
