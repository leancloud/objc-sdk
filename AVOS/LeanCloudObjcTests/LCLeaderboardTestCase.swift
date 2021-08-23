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
    }
    
    func testInvalidParameter() {
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
            LCLeaderboard.getStatisticsWithUserId("", statisticNames: nil) { statistics, error in
                XCTAssertNil(statistics)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
        
        let leaderboard = LCLeaderboard(statisticName: uuid)
        
        expecting { exp in
            leaderboard.getStatisticsWithUserIds([]) { statistics, error in
                XCTAssertNil(statistics)
                XCTAssertNotNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testGetUserStatistics() {
        defer {
            LCUser.logOut()
        }
        let user = LCUser()
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
        
        let statisticName0 = "test-user-0"
        let statisticName1 = "test-user-1"
        
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
        
        expecting { exp in
            LCLeaderboard.getStatisticsWithUserId(
                userObjectId,
                statisticNames: [statisticName0, statisticName1])
            { statistics, error in
                XCTAssertEqual(statistics?.count, 2)
                XCTAssertNil(error)
                XCTAssertNotEqual(statistics?.first?.name, statistics?.last?.name)
                for item in statistics ?? [] {
                    XCTAssertTrue([statisticName0, statisticName1].contains(item.name ?? ""))
                    XCTAssertEqual(item.value, 100)
                    XCTAssertGreaterThanOrEqual(item.version, 0)
                    XCTAssertNotNil(item.user)
                    XCTAssertNil(item.object)
                    XCTAssertNil(item.entity)
                }
                exp.fulfill()
            }
        }
        
        let leaderboard0 = LCLeaderboard(statisticName: statisticName0)
        let leaderboard1 = LCLeaderboard(statisticName: statisticName1)
        
        expecting(count: 2) { exp in
            leaderboard0.getStatisticsWithUserIds([userObjectId]) { statistics, error in
                XCTAssertEqual(statistics?.count, 1)
                XCTAssertNil(error)
                XCTAssertEqual(leaderboard0.statisticName, statistics?.first?.name)
                XCTAssertEqual(statistics?.first?.value, 100)
                XCTAssertGreaterThanOrEqual(statistics?.first?.version ?? -1, 0)
                XCTAssertNotNil(statistics?.first?.user)
                XCTAssertNil(statistics?.first?.object)
                XCTAssertNil(statistics?.first?.entity)
                exp.fulfill()
            }
            leaderboard1.getStatisticsWithUserIds([userObjectId]) { statistics, error in
                XCTAssertEqual(statistics?.count, 1)
                XCTAssertNil(error)
                XCTAssertEqual(leaderboard1.statisticName, statistics?.first?.name)
                XCTAssertEqual(statistics?.first?.value, 100)
                XCTAssertGreaterThanOrEqual(statistics?.first?.version ?? -1, 0)
                XCTAssertNotNil(statistics?.first?.user)
                XCTAssertNil(statistics?.first?.object)
                XCTAssertNil(statistics?.first?.entity)
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
    }
    
    func testGetObjectStatistics() {
        let object = LCObject()
        let objectFieldKey = "objectField"
        object[objectFieldKey] = LCObject()
        XCTAssertTrue(object.save())
        guard let objectId = object.objectId else {
            XCTFail()
            return
        }
        
        let statisticName0 = "test-object-0"
        let statisticName1 = "test-object-1"
        
        useMasterKey()
        expecting { exp in
            LCLeaderboard.update(
                withIdentity: objectId,
                leaderboardPath: .objects,
                statistics: [
                    statisticName0 : 100,
                    statisticName1 : 100,
                ])
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
        useCommonKey()
        
        let option = LCLeaderboardQueryOption()
        option.selectKeys = [objectFieldKey]
        option.includeKeys = [objectFieldKey]
        
        expecting { exp in
            LCLeaderboard.getStatisticsWithObjectId(
                objectId,
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
                    XCTAssertNotNil((item.object?[objectFieldKey] as? LCObject)?.createdAt)
                    XCTAssertNil(item.user)
                    XCTAssertNil(item.entity)
                }
                exp.fulfill()
            }
        }
        
        let leaderboard0 = LCLeaderboard(statisticName: statisticName0)
        let leaderboard1 = LCLeaderboard(statisticName: statisticName1)
        
        expecting(count: 2) { exp in
            leaderboard0.getStatisticsWithObjectIds([objectId], option: option) { statistics, error in
                XCTAssertEqual(statistics?.count, 1)
                XCTAssertNil(error)
                XCTAssertEqual(leaderboard0.statisticName, statistics?.first?.name)
                XCTAssertEqual(statistics?.first?.value, 100)
                XCTAssertGreaterThanOrEqual(statistics?.first?.version ?? -1, 0)
                XCTAssertNotNil((statistics?.first?.object?[objectFieldKey] as? LCObject)?.createdAt)
                XCTAssertNil(statistics?.first?.user)
                XCTAssertNil(statistics?.first?.entity)
                exp.fulfill()
            }
            leaderboard1.getStatisticsWithObjectIds([objectId], option: option) { statistics, error in
                XCTAssertEqual(statistics?.count, 1)
                XCTAssertNil(error)
                XCTAssertEqual(leaderboard1.statisticName, statistics?.first?.name)
                XCTAssertEqual(statistics?.first?.value, 100)
                XCTAssertGreaterThanOrEqual(statistics?.first?.version ?? -1, 0)
                XCTAssertNotNil((statistics?.first?.object?[objectFieldKey] as? LCObject)?.createdAt)
                XCTAssertNil(statistics?.first?.user)
                XCTAssertNil(statistics?.first?.entity)
                exp.fulfill()
            }
        }
    }
    
    func testGetEntityStatistics() {
        let entityId = uuid
        
        let statisticName0 = "test-entity-0"
        let statisticName1 = "test-entity-1"
        
        useMasterKey()
        expecting { exp in
            LCLeaderboard.update(
                withIdentity: entityId,
                leaderboardPath: .entities,
                statistics: [
                    statisticName0 : 100,
                    statisticName1 : 100,
                ])
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
        useCommonKey()
        
        expecting { exp in
            LCLeaderboard.getStatisticsWithEntity(
                entityId,
                statisticNames: [statisticName0, statisticName1])
            { statistics, error in
                XCTAssertEqual(statistics?.count, 2)
                XCTAssertNil(error)
                XCTAssertNotEqual(statistics?.first?.name, statistics?.last?.name)
                for item in statistics ?? [] {
                    XCTAssertTrue([statisticName0, statisticName1].contains(item.name ?? ""))
                    XCTAssertEqual(item.value, 100)
                    XCTAssertGreaterThanOrEqual(item.version, 0)
                    XCTAssertNotNil(item.entity)
                    XCTAssertEqual(item.entity, entityId)
                    XCTAssertNil(item.user)
                    XCTAssertNil(item.object)
                }
                exp.fulfill()
            }
        }
        
        let leaderboard0 = LCLeaderboard(statisticName: statisticName0)
        let leaderboard1 = LCLeaderboard(statisticName: statisticName1)
        
        expecting(count: 2) { exp in
            leaderboard0.getStatisticsWithEntities([entityId]) { statistics, error in
                XCTAssertEqual(statistics?.count, 1)
                XCTAssertNil(error)
                XCTAssertEqual(leaderboard0.statisticName, statistics?.first?.name)
                XCTAssertEqual(statistics?.first?.value, 100)
                XCTAssertGreaterThanOrEqual(statistics?.first?.version ?? -1, 0)
                XCTAssertEqual(statistics?.first?.entity, entityId)
                XCTAssertNil(statistics?.first?.user)
                XCTAssertNil(statistics?.first?.object)
                exp.fulfill()
            }
            leaderboard1.getStatisticsWithEntities([entityId]) { statistics, error in
                XCTAssertEqual(statistics?.count, 1)
                XCTAssertNil(error)
                XCTAssertEqual(leaderboard1.statisticName, statistics?.first?.name)
                XCTAssertEqual(statistics?.first?.value, 100)
                XCTAssertGreaterThanOrEqual(statistics?.first?.version ?? -1, 0)
                XCTAssertEqual(statistics?.first?.entity, entityId)
                XCTAssertNil(statistics?.first?.user)
                XCTAssertNil(statistics?.first?.object)
                exp.fulfill()
            }
        }
    }
    
    func testGetUserRankings() {
        defer {
            LCUser.logOut()
        }
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
        
        let statisticName0 = "test-user-0"
        let statisticName1 = "test-user-1"
        var statistic0version = -1
        var statistic1version = -1
        
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
                    if (item.name ?? "") == statisticName0 {
                        statistic0version = item.version
                    } else {
                        statistic1version = item.version
                    }
                }
                exp.fulfill()
            }
        }
        
        let leaderboard0 = LCLeaderboard(statisticName: statisticName0)
        let leaderboard1 = LCLeaderboard(statisticName: statisticName1)
        let option = LCLeaderboardQueryOption()
        option.selectKeys = [objectFieldKey]
        option.includeKeys = [objectFieldKey]
        
        expecting(count: 2) { exp in
            leaderboard0.limit = 1
            leaderboard0.includeStatistics = [statisticName1]
            leaderboard0.version = statistic0version
            leaderboard0.returnCount = true
            leaderboard0.getUserResultsAroundUser(userObjectId, option: option) { rankings, count, error in
                XCTAssertEqual(rankings?.count, 1)
                XCTAssertGreaterThanOrEqual(count, 1)
                XCTAssertNil(error)
                for item in rankings ?? [] {
                    XCTAssertEqual(item.statisticName, leaderboard0.statisticName)
                    XCTAssertGreaterThanOrEqual(item.rank, 0)
                    XCTAssertEqual(item.value, 100)
                    XCTAssertEqual(item.includedStatistics?.first?.name, statisticName1)
                    XCTAssertEqual(item.includedStatistics?.first?.value, 100)
                    XCTAssertEqual(item.user?.objectId, userObjectId)
                    XCTAssertNotNil((item.user?[objectFieldKey] as? LCObject)?.createdAt)
                    XCTAssertNil(item.object)
                    XCTAssertNil(item.entity)
                }
                exp.fulfill()
            }
            leaderboard1.skip = 1
            leaderboard1.version = statistic1version
            leaderboard1.getUserResults(with: nil) { rankings, count, error in
                for item in rankings ?? [] {
                    XCTAssertNotEqual(item.rank, 0)
                }
                XCTAssertEqual(count, 0)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testGetObjectRankings() {
        let object = LCObject()
        let objectFieldKey = "objectField"
        object[objectFieldKey] = LCObject()
        XCTAssertTrue(object.save())
        guard let objectId = object.objectId else {
            XCTFail()
            return
        }
        
        let statisticName0 = "test-object-0"
        let statisticName1 = "test-object-1"
        var statistic0version = -1
        var statistic1version = -1
        
        useMasterKey()
        expecting { exp in
            LCLeaderboard.update(
                withIdentity: objectId,
                leaderboardPath: .objects,
                statistics: [
                    statisticName0 : 100,
                    statisticName1 : 100,
                ])
            { statistics, error in
                XCTAssertEqual(statistics?.count, 2)
                XCTAssertNil(error)
                XCTAssertNotEqual(statistics?.first?.name, statistics?.last?.name)
                for item in statistics ?? [] {
                    XCTAssertTrue([statisticName0, statisticName1].contains(item.name ?? ""))
                    XCTAssertEqual(item.value, 100)
                    XCTAssertGreaterThanOrEqual(item.version, 0)
                    if (item.name ?? "") == statisticName0 {
                        statistic0version = item.version
                    } else {
                        statistic1version = item.version
                    }
                }
                exp.fulfill()
            }
        }
        useCommonKey()
        
        let leaderboard0 = LCLeaderboard(statisticName: statisticName0)
        let leaderboard1 = LCLeaderboard(statisticName: statisticName1)
        let option = LCLeaderboardQueryOption()
        option.selectKeys = [objectFieldKey]
        option.includeKeys = [objectFieldKey]
        
        expecting(count: 2) { exp in
            leaderboard0.limit = 1
            leaderboard0.includeStatistics = [statisticName1]
            leaderboard0.version = statistic0version
            leaderboard0.returnCount = true
            leaderboard0.getObjectResultsAroundObject(objectId, option: option) { rankings, count, error in
                XCTAssertEqual(rankings?.count, 1)
                XCTAssertGreaterThanOrEqual(count, 1)
                XCTAssertNil(error)
                for item in rankings ?? [] {
                    XCTAssertEqual(item.statisticName, leaderboard0.statisticName)
                    XCTAssertGreaterThanOrEqual(item.rank, 0)
                    XCTAssertEqual(item.value, 100)
                    XCTAssertEqual(item.includedStatistics?.first?.name, statisticName1)
                    XCTAssertEqual(item.includedStatistics?.first?.value, 100)
                    XCTAssertEqual(item.object?.objectId, objectId)
                    XCTAssertNotNil((item.object?[objectFieldKey] as? LCObject)?.createdAt)
                    XCTAssertNil(item.user)
                    XCTAssertNil(item.entity)
                }
                exp.fulfill()
            }
            leaderboard1.skip = 1
            leaderboard1.version = statistic1version
            leaderboard1.getObjectResults(with: nil) { rankings, count, error in
                for item in rankings ?? [] {
                    XCTAssertNotEqual(item.rank, 0)
                }
                XCTAssertEqual(count, 0)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
    
    func testGetEntityRankings() {
        let entityId = uuid
        
        let statisticName0 = "test-entity-0"
        let statisticName1 = "test-entity-1"
        var statistic0version = -1
        var statistic1version = -1
        
        useMasterKey()
        expecting { exp in
            LCLeaderboard.update(
                withIdentity: entityId,
                leaderboardPath: .entities,
                statistics: [
                    statisticName0 : 100,
                    statisticName1 : 100,
                ])
            { statistics, error in
                XCTAssertEqual(statistics?.count, 2)
                XCTAssertNil(error)
                XCTAssertNotEqual(statistics?.first?.name, statistics?.last?.name)
                for item in statistics ?? [] {
                    XCTAssertTrue([statisticName0, statisticName1].contains(item.name ?? ""))
                    XCTAssertEqual(item.value, 100)
                    XCTAssertGreaterThanOrEqual(item.version, 0)
                    if (item.name ?? "") == statisticName0 {
                        statistic0version = item.version
                    } else {
                        statistic1version = item.version
                    }
                }
                exp.fulfill()
            }
        }
        useCommonKey()
        
        let leaderboard0 = LCLeaderboard(statisticName: statisticName0)
        let leaderboard1 = LCLeaderboard(statisticName: statisticName1)
        
        expecting(count: 2) { exp in
            leaderboard0.limit = 1
            leaderboard0.includeStatistics = [statisticName1]
            leaderboard0.version = statistic0version
            leaderboard0.returnCount = true
            leaderboard0.getEntityResultsAroundEntity(entityId) { rankings, count, error in
                XCTAssertEqual(rankings?.count, 1)
                XCTAssertGreaterThanOrEqual(count, 1)
                XCTAssertNil(error)
                for item in rankings ?? [] {
                    XCTAssertEqual(item.statisticName, leaderboard0.statisticName)
                    XCTAssertGreaterThanOrEqual(item.rank, 0)
                    XCTAssertEqual(item.value, 100)
                    XCTAssertEqual(item.includedStatistics?.first?.name, statisticName1)
                    XCTAssertEqual(item.includedStatistics?.first?.value, 100)
                    XCTAssertEqual(item.entity, entityId)
                    XCTAssertNil(item.user)
                    XCTAssertNil(item.object)
                }
                exp.fulfill()
            }
            leaderboard1.skip = 1
            leaderboard1.version = statistic1version
            leaderboard1.getEntityResults { rankings, count, error in
                for item in rankings ?? [] {
                    XCTAssertNotEqual(item.rank, 0)
                }
                XCTAssertEqual(count, 0)
                XCTAssertNil(error)
                exp.fulfill()
            }
        }
    }
}
