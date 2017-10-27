//
//  AVStatusTest.m
//  paas
//
//  Created by Travis on 13-12-25.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "AVTestBase.h"
#import "AVStatus.h"
#import "AVPaasClient.h"

@interface FriendUser : AVUser<AVSubclassing>
@property (nonatomic, assign) int age;
@end


@implementation FriendUser

@dynamic age;


@end

@interface AVStatusTest : AVTestBase

@end

@implementation AVStatusTest

+(void)setUp{
    [super setUp];
    NSError *err = nil;
    AVUser *user = [AVUser user];
    user.username = @"travis";
    user.password = @"123456";
    [user signUp:&err];
    [self addDeleteObject:user];
    
    user = [AVUser user];
    user.username = @"zeng";
    user.password = @"123456";
    err = nil;
    [user signUp:&err];
    [self addDeleteObject:user];

}

//+(void)tearDown {
//    [super tearDown];
//    [AVUser logInWithUsername:@"travis" password:@"123456"];
//    [[AVUser currentUser] delete];
//    [AVUser logInWithUsername:@"zeng" password:@"123456"];
//    [[AVUser currentUser] delete];
//}

- (void)user:(NSString *)user1 follow:(NSString *)user2 {
    [self user:user1 follow:user2 userDictionary:nil];
}

- (void)user:(NSString *)user1 follow:(NSString *)user2 userDictionary:(NSDictionary *)dict {
    NSError *err = nil;
    NSString *user2Id=[AVUser logInWithUsername:user2 password:@"123456" error:&err].objectId;
    err = nil;
    [[AVUser logInWithUsername:user1 password:@"123456" error:&err] follow:user2Id userDictionary:dict andCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error, @"%@",[error description]);
        NOTIFY;
    }];
    WAIT;
}
- (void)user:(NSString *)user1 unfollow:(NSString *)user2 {
    NSError *err = nil;
    NSString *user2Id=[AVUser logInWithUsername:user2 password:@"123456" error:&err].objectId;
    err = nil;
    [[AVUser logInWithUsername:user1 password:@"123456" error:&err] unfollow:user2Id andCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error, @"%@",[error description]);
        NOTIFY;
    }];
    WAIT;
}

-(void)testFolloweeQuery{
    [FriendUser registerSubclass];
    NSError *err = nil;
    NSString *travisId=[FriendUser logInWithUsername:@"travis" password:@"123456" error:&err].objectId;
    
    XCTAssertNotNil(travisId, @"can't login");
    
    NSString *zengId=[FriendUser logInWithUsername:@"zeng" password:@"123456" error:&err].objectId;
    
    [[FriendUser currentUser] follow:travisId andCallback:^(BOOL succeeded, NSError *error) {
        if (error.code!=kAVErrorDuplicateValue) {
            XCTAssertNil(error, @"%@",[error description]);
        }
        
        AVQuery *query= [FriendUser followeeQuery:zengId];
        
        [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
            XCTAssertNil(error, @"%@",[error description]);
            XCTAssertTrue(objects.count>0, @"friend query not work");
            XCTAssertTrue([objects[0] isKindOfClass:[FriendUser class]], @"subclass of user not work");
            NSLog(@"got Users:%@",[objects description]);
            
            NOTIFY
        }];
        
    }];
    
    WAIT;
    [self user:@"zeng" unfollow:@"travis"];
}

-(void)testFollowerQuery{
    NSError *err = nil;
    NSString *travisId=[AVUser logInWithUsername:@"travis" password:@"123456" error:&err].objectId;
    
    XCTAssertNotNil(travisId, @"can't login");
    err = nil;
    [[AVUser logInWithUsername:@"zeng" password:@"123456" error:&err] follow:travisId andCallback:^(BOOL succeeded, NSError *error) {
        if (error.code!=kAVErrorDuplicateValue) {
            XCTAssertNil(error, @"%@",[error description]);
        }
        
        AVQuery *query= [AVUser followerQuery:travisId];
        
        [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
            XCTAssertNil(error, @"%@",[error description]);
            XCTAssertTrue(objects.count>0, @"friend query not work");
            
            NSLog(@"got Users:%@",[objects description]);
            
            NOTIFY
        }];
        
    }];
    
    WAIT;
    [self user:@"zeng" unfollow:@"travis"];
}

-(void)testUserUnfollow {
    NSError *err = nil;
    NSString *travisId=[AVUser logInWithUsername:@"travis" password:@"123456" error:&err].objectId;
    [self user:@"zeng" follow:@"travis"];
    err = nil;
    [[AVUser logInWithUsername:@"zeng" password:@"123456" error:&err] unfollow:travisId andCallback:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error, @"%@",[error description]);
        
//        //follow it back for other test case
//        [[AVUser currentUser] follow:travisId andCallback:^(BOOL succeeded, NSError *error) {
//            if (error.code!=kAVErrorDuplicateValue) {
//                XCTAssertNil(error, @"%@",[error description]);
//            }
//            
//            NOTIFY
//        }];
        
        NOTIFY
        
    }];
    
    WAIT;
}

-(void)testUserFollow {
    NSError *err = nil;
    NSString *travisId=[AVUser logInWithUsername:@"travis" password:@"123456" error:&err].objectId;
    err = nil;
    [[AVUser logInWithUsername:@"zeng" password:@"123456" error:&err] follow:travisId andCallback:^(BOOL succeeded, NSError *error) {
        if (error.code!=kAVErrorDuplicateValue) {
            XCTAssertNil(error, @"%@",[error description]);
        }
        NOTIFY
    }];
    
    WAIT;
    [self user:@"zeng" unfollow:@"travis"];
}

-(void)testGetFollowers{
    NSError *err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
    [self user:@"zeng" follow:@"travis"];
    err = nil;
    [[AVUser logInWithUsername:@"travis" password:@"123456" error:&err] getFollowers:^(NSArray *objects, NSError *error) {
        XCTAssertNil(error, @"%@",[error description]);
        
        XCTAssertTrue(objects.count>0, @"%@",[error description]);
        NOTIFY
    }];
    
    WAIT;
    [self user:@"zeng" unfollow:@"travis"];
}

-(void)testGetFollowees{
    NSError *err = nil;
    [AVUser logInWithUsername:@"travis"
                     password:@"123456"
                        error:&err];
    [self user:@"zeng" follow:@"travis"];
    
    err = nil;
    [[AVUser logInWithUsername:@"zeng" password:@"123456" error:&err] getFollowees:^(NSArray *objects, NSError *error) {
        NSLog(@"Get %lu followees", (unsigned long)objects.count);
        XCTAssertTrue(objects.count > 0, @"objects should large than 0");
        XCTAssertNil(error, @"%@",[error description]);
        NOTIFY
    }];
    
    WAIT;
    [self user:@"zeng" unfollow:@"travis"];
}

-(void)testGetFollowersAndFollowees{
    NSError *err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
    [self user:@"zeng" follow:@"travis"];
    [self user:@"travis" follow:@"zeng"];
    err = nil;
    [[AVUser logInWithUsername:@"zeng" password:@"123456" error:&err] getFollowersAndFollowees:^(NSDictionary *dict, NSError *error) {
        NSArray *followers=dict[@"followers"];
        NSArray *followees=dict[@"followees"];
        
        NSLog(@"Get %lu followers, and %lu followees",(unsigned long)followers.count, (unsigned long)followees.count);
        XCTAssertTrue(followees.count > 0, @"followees should large than 0");
        XCTAssertTrue(followers.count > 0, @"followers should large than 0");
        XCTAssertNil(error, @"%@",[error description]);
        NOTIFY
    }];
    

    WAIT;
    [self user:@"zeng" unfollow:@"travis"];
    [self user:@"travis" unfollow:@"zeng"];
}

-(void)testGetUserUnreadTimelineCount{
    [self user:@"zeng" follow:@"travis"];
    [self user:@"travis" follow:@"zeng"];
    AVStatus *status=[[AVStatus alloc] init];
    
    status.data=@{@"text":[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), [[NSDate date] description]]};
    NSError *err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
    [AVStatus sendStatusToFollowers:status andCallback:^(BOOL succeeded, NSError *error) {
        NSLog(@"============ Send %@", [status debugDescription]);
        XCTAssertNil(error, @"%@",[error description]);
        NOTIFY;
    }];
    WAIT;
    [self addDeleteStatus:status];
    err = nil;
    [AVUser logInWithUsername:@"zeng" password:@"123456" error:&err];

    [AVStatus getUnreadStatusesCountWithType:kAVStatusTypeTimeline andCallback:^(NSInteger number, NSError *error) {
        XCTAssertTrue(number > 0);
        XCTAssertNil(error, @"%@", [error description]);
        NOTIFY
    }];
    WAIT;

    [AVStatus resetUnreadStatusesCountWithType:kAVStatusTypeTimeline andCallback:^(BOOL succeeded, NSError * _Nullable error) {
        XCTAssertTrue(succeeded);
        XCTAssertNil(error, @"%@", [error description]);
        NOTIFY
    }];
    WAIT;

    [AVStatus getUnreadStatusesCountWithType:kAVStatusTypeTimeline andCallback:^(NSInteger number, NSError *error) {
        XCTAssertTrue(number == 0);
        XCTAssertNil(error, @"%@", [error description]);
        NOTIFY
    }];
    WAIT;

    [self user:@"zeng" unfollow:@"travis"];
    [self user:@"travis" unfollow:@"zeng"];
}

-(void)testSendStatusToFollowers{
    [self user:@"zeng" follow:@"travis"];
    [self user:@"travis" follow:@"zeng"];
    AVStatus *status=[[AVStatus alloc] init];
    
    status.data=@{@"text":[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), [[NSDate date] description]]};
    NSError *err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
    [AVStatus sendStatusToFollowers:status andCallback:^(BOOL succeeded, NSError *error) {
        NSLog(@"============ Send %@", [status debugDescription]);
        XCTAssertNil(error, @"%@",[error description]);
        NOTIFY
    }];
    
    WAIT;
    [self addDeleteStatus:status];
    [self user:@"zeng" unfollow:@"travis"];
    [self user:@"travis" unfollow:@"zeng"];
}

-(void)testGetUserTimeline {
    [self user:@"zeng" follow:@"travis"];
    [self user:@"travis" follow:@"zeng"];
    NSError *err = nil;
    [AVUser logInWithUsername:@"zeng" password:@"123456" error:&err];
    int max = 10;
    __block int c = max;
    for (int i = 0; i < max; ++i) {
        AVStatus *status=[[AVStatus alloc] init];
        
        status.data=@{@"text":[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), [[NSDate date] description]]};
        
        [AVStatus sendStatusToFollowers:status andCallback:^(BOOL succeeded, NSError *error) {
            --c;
            NSLog(@"============ Send %@", [status debugDescription]);
            XCTAssertNil(error, @"%@",[error description]);
            [self addDeleteStatus:status];
            if (c == 0) {
                NOTIFY;
            }
        }];
    }
    WAIT;
    err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
//    [AVStatus getStatusesWithType:kAVStatusTypeTimeline skip:0 limit:5 andCallback:^(NSArray *objects, NSError *error) {
//        NSLog(@"============== Get %lu Timline statuses:\n%@", (unsigned long)objects.count,[objects debugDescription]);
//        XCTAssertEqual(objects.count, 5, @"objects count should equal to 5");
//        XCTAssertNil(error, @"%@",[error description]);
//        NOTIFY
//    }];
    
    WAIT;
    [self user:@"zeng" unfollow:@"travis"];
    [self user:@"travis" unfollow:@"zeng"];
}

//
//-(void)testGetUserTimeline2{
//    
//    [AVUser logInWithUsername:@"zeng" password:@"123456"];
//    [AVStatus getStatusesWithType:kAVStatusTypeTimeline skip:0 limit:50 andCallback:^(NSArray *objects, NSError *error) {
//        NSLog(@"============== Get %d Timline statuses:\n%@", objects.count,[objects debugDescription]);
//        XCTAssertNil(error, @"%@",[error description]);
//        NOTIFY
//    }];
//    
//    WAIT;
//}


-(void)testSendPrivateStatus{
    AVStatus *status=[[AVStatus alloc] init];
    status.data=@{@"text":[NSString stringWithFormat:@"private msg %@",[[NSDate date] description]]};
    NSError *err = nil;
    NSString *userId= [AVUser logInWithUsername:@"zeng" password:@"123456" error:&err].objectId;
    err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
    [AVStatus sendPrivateStatus:status toUserWithID:userId andCallback:^(BOOL succeeded, NSError *error) {
        NSLog(@"============ Send %@", [status debugDescription]);
        XCTAssertNil(error, @"%@",[error description]);
        NOTIFY
    }];
    
    WAIT;
    [self addDeleteStatus:status];
}
-(void)testGetPrivateStatus{
    int max = 10;
    __block int c = max;
    NSError *err = nil;
    NSString *userId= [AVUser logInWithUsername:@"zeng" password:@"123456" error:&err].objectId;
    err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
    for (int i = 0; i < max; ++i) {
        AVStatus *status=[[AVStatus alloc] init];
        
        status.data=@{@"text":[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), [[NSDate date] description]]};
        [AVStatus sendPrivateStatus:status toUserWithID:userId andCallback:^(BOOL succeeded, NSError *error) {
            --c;
            NSLog(@"============ Send %@", [status debugDescription]);
            XCTAssertNil(error, @"%@",[error description]);
            [self addDeleteStatus:status];
            if (c == 0) {
                NOTIFY;
            }
        }];
    }
    WAIT;
    err = nil;
    [AVUser logInWithUsername:@"zeng" password:@"123456" error:&err];
//    [AVStatus getStatusesWithType:kAVStatusTypePrivateMessage skip:0 limit:5 andCallback:^(NSArray *objects, NSError *error) {
//        NSLog(@"============== Get %lu private statuses:\n%@", (unsigned long)objects.count,[objects debugDescription]);
////        XCTAssertEqual(objects.count, 5, @"objects count should equal to 5");
//        XCTAssertNil(error, @"%@",[error description]);
//        NOTIFY
//    }];
    WAIT;
    sleep(2);
//    [AVStatus getStatusesWithType:kAVStatusTypePrivateMessage skip:0 limit:5 andCallback:^(NSArray *objects, NSError *error) {
//        NSLog(@"============== Get %lu private statuses:\n%@", (unsigned long)objects.count,[objects debugDescription]);
//        XCTAssertEqual(objects.count, 5, @"objects count should equal to 5");
//        XCTAssertNil(error, @"%@",[error description]);
//        NOTIFY
//    }];
    WAIT;
}
-(void)testDeleteStatus{
    NSError *err = nil;
    NSString *userId= [AVUser logInWithUsername:@"zeng" password:@"123456" error:&err].objectId;
    AVStatus *status=[[AVStatus alloc] init];
    
    status.data=@{@"text":[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), [[NSDate date] description]]};
    err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
    [AVStatus sendPrivateStatus:status toUserWithID:userId andCallback:^(BOOL succeeded, NSError *error) {
        NSLog(@"============ Send %@", [status debugDescription]);
        XCTAssertNil(error, @"%@",[error description]);
        NOTIFY;
    }];
    
    WAIT;
    [AVStatus deleteStatusWithID:status.objectId andCallback:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            [AVStatus getStatusWithID:status.objectId andCallback:^(AVStatus *status, NSError *error) {
                XCTAssertNil(error, @"%@",[error description]);
                XCTAssertNil(status, @"status not deleted %@",[status description]);
                NOTIFY;
            }];
            
        } else {
            
            XCTAssertNil(error, @"%@",[error description]);
            NOTIFY;
        }
    }];
    
    WAIT;
}

-(void)testGetCurrentUserStatus{
    [self user:@"zeng" follow:@"travis"];
    [self user:@"travis" follow:@"zeng"];
    NSError *err = nil;
    [AVUser logInWithUsername:@"zeng" password:@"123456" error:&err];
    int max = 10;
    __block int c = max;
    for (int i = 0; i < max; ++i) {
        AVStatus *status=[[AVStatus alloc] init];
        
        status.data=@{@"text":[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), [[NSDate date] description]]};
        
        [AVStatus sendStatusToFollowers:status andCallback:^(BOOL succeeded, NSError *error) {
            --c;
            NSLog(@"============ Send %@", [status debugDescription]);
            XCTAssertNil(error, @"%@",[error description]);
            [self addDeleteStatus:status];
            if (c == 0) {
                NOTIFY;
            }
        }];
    }
    WAIT;
    sleep(3);
    err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
//    [AVStatus getStatusesWithType:kAVStatusTypeTimeline skip:0 limit:2 andCallback:^(NSArray *objects, NSError *error) {
//        NSLog(@"============== Get %lu statuses:\n%@", (unsigned long)objects.count,[objects debugDescription]);
//        XCTAssertTrue(objects.count > 0, @"objects count should larger than 0");
//        XCTAssertNil(error, @"%@",[error description]);
//        NOTIFY
//    }];
    
    WAIT;
    [self user:@"zeng" unfollow:@"travis"];
    [self user:@"travis" unfollow:@"zeng"];
}


-(void)testGetStatusOfCurrentUser{
    NSError *err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
//    [AVStatus getStatusesFromCurrentUserWithType:kAVStatusTypeTimeline skip:0 limit:100 andCallback:^(NSArray *objects, NSError *error) {
//        NSLog(@"============== Get %lu statuses:\n%@", (unsigned long)objects.count,[objects debugDescription]);
//        XCTAssertTrue(objects.count > 0, @"objects count should larger than 0");
//        XCTAssertNil(error, @"%@",[error description]);
//        NOTIFY
//    }];
    
    WAIT;
}

//-(void)testGetStatusOfUser{
//    [AVStatus getStatusesFromUser:[AVUser logInWithUsername:@"travis" password:@"123456"].objectId skip:0 limit:100 andCallback:^(NSArray *objects, NSError *error) {
//        NSLog(@"============== Get %lu statuses:\n%@", (unsigned long)objects.count,[objects debugDescription]);
//        XCTAssertTrue(objects.count > 0, @"objects count should larger than 0");
//        XCTAssertNil(error, @"%@",[error description]);
//        NOTIFY
//    }];
//
//    WAIT;
//}

-(void)testGetStatusWithID{
    NSError *err = nil;
    NSString *userId= [AVUser logInWithUsername:@"zeng" password:@"123456" error:&err].objectId;
    AVStatus *status=[[AVStatus alloc] init];
    
    status.data=@{@"text":[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), [[NSDate date] description]]};
    err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
    [AVStatus sendPrivateStatus:status toUserWithID:userId andCallback:^(BOOL succeeded, NSError *error) {
        NSLog(@"============ Send %@", [status debugDescription]);
        XCTAssertNil(error, @"%@",[error description]);
        NOTIFY;
    }];
    
    WAIT;

    [AVStatus getStatusWithID:status.objectId andCallback:^(AVStatus *status, NSError *error) {
        XCTAssertNil(error, @"%@",[error description]);
        NOTIFY
    }];
    
    WAIT;
    [self addDeleteStatus:status];
}

-(void)testSetQueryPublicStatus{
    AVStatus *status=[[AVStatus alloc] init];
    [status setData:@{@"text":[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), [[NSDate date] description]]}];
    
    AVQuery *query=[AVUser query];
    [status setQuery:query];
    
    [status sendInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error, @"%@",[error description]);
        NOTIFY
    }];
    
    WAIT;
    [self addDeleteStatus:status];
}

-(void)testSetQueryPrivateStatus{
    AVStatus *status=[[AVStatus alloc] init];
    [status setData:@{@"text":[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), [[NSDate date] description]]}];
    [status setType:kAVStatusTypePrivateMessage];
    
    AVQuery *query=[AVUser query];
    [status setQuery:query];
    
    [status sendInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error, @"%@",[error description]);
        NOTIFY
    }];
    
    WAIT;
    [self addDeleteStatus:status];
}

-(void)testInboxQuery{
    [self user:@"zeng" follow:@"travis"];
    [self user:@"travis" follow:@"zeng"];
    NSError *err = nil;
    [AVUser logInWithUsername:@"zeng" password:@"123456" error:&err];
    int max = 10;
    __block int c = max;
    for (int i = 0; i < max; ++i) {
        AVStatus *status=[[AVStatus alloc] init];
        
        status.data=@{@"text":[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), [[NSDate date] description]]};
        
        [AVStatus sendStatusToFollowers:status andCallback:^(BOOL succeeded, NSError *error) {
            --c;
            NSLog(@"============ Send %@", [status debugDescription]);
            XCTAssertNil(error, @"%@",[error description]);
            [self addDeleteStatus:status];
            if (c == 0) {
                NOTIFY;
            }
        }];
    }
    WAIT;
    err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
    AVStatusQuery *query= [AVStatus inboxQuery:kAVStatusTypeTimeline];
    query.limit=3;
//    query.maxId=8;
    [query includeKey:@"source"];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertNil(error, @"%@", error);
        NOTIFY;
    }];
    WAIT;
    sleep(2);
    query= [AVStatus inboxQuery:kAVStatusTypeTimeline];
    query.limit=3;
    //    query.maxId=8;
    [query includeKey:@"source"];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertEqual(query.limit,objects.count, @"返回个数不对");
        XCTAssertEqualObjects(@"AVStatus", NSStringFromClass([objects[0] class]), @"返回类型不对");
        NOTIFY;
    }];

    WAIT;
    [self user:@"zeng" unfollow:@"travis"];
    [self user:@"travis" unfollow:@"zeng"];
}

-(void)testStatusQuery{
    int max = 10;
    __block int c = max;
    NSError *err = nil;
    NSString *userId= [AVUser logInWithUsername:@"zeng" password:@"123456" error:&err].objectId;
    err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
    for (int i = 0; i < max; ++i) {
        AVStatus *status=[[AVStatus alloc] init];
        
        status.data=@{@"text":[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), [[NSDate date] description]]};
        [AVStatus sendPrivateStatus:status toUserWithID:userId andCallback:^(BOOL succeeded, NSError *error) {
            --c;
            NSLog(@"============ Send %@", [status debugDescription]);
            XCTAssertNil(error, @"%@",[error description]);
            [self addDeleteStatus:status];
            if (c == 0) {
                NOTIFY;
            }
        }];
    }
    WAIT;
    err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
    AVStatusQuery *query=[AVStatus statusQuery];
    [query whereKey:@"source" equalTo:[AVUser currentUser]];
    query.limit=2;
    query.inboxType=kAVStatusTypePrivateMessage;
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertTrue(query.limit==objects.count, @"返回个数不对");
        XCTAssertEqualObjects(@"AVStatus", NSStringFromClass([objects[0] class]), @"返回类型不对");
        NOTIFY;
    }];
    
    WAIT;
}

/* 目前服务端暂时有这个问题，subscribe/statuses/count 数字只会增加不会减少，会导致 end 始终返回 false。 */

#if 0

-(void)testStatusQueryEnd{
    int max = 10;
    __block int c = max;
    NSString *zengId = [AVUser logInWithUsername:@"zeng" password:@"123456"].objectId;

    AVStatusQuery *query=[AVStatus inboxQuery:kAVStatusTypePrivateMessage];
    query.limit = 100;
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        NSLog(@"%d", query.end);
        for (AVStatus *status in objects) {
            BOOL success = [AVStatus deleteInboxStatusForMessageId:status.messageId inboxType:kAVStatusTypePrivateMessage receiver:zengId error:&error];
            XCTAssertTrue(success && !error, @"Delete status failed");
        }
        NOTIFY;
    }];
    WAIT;

    [AVUser logInWithUsername:@"travis" password:@"123456"].objectId;

    for (int i = 0; i < max; ++i) {
        AVStatus *status=[[AVStatus alloc] init];
        
        status.data=@{@"text":[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), [[NSDate date] description]]};
        [AVStatus sendPrivateStatus:status toUserWithID:zengId andCallback:^(BOOL succeeded, NSError *error) {
            --c;
            NSLog(@"============ Send %@", [status debugDescription]);
            XCTAssertNil(error, @"%@",[error description]);
            [self addDeleteStatus:status];
            if (c == 0) {
                NOTIFY;
            }
        }];
    }
    WAIT;

    [AVUser logInWithUsername:@"zeng" password:@"123456"];

    query=[AVStatus inboxQuery:kAVStatusTypePrivateMessage];
    query.limit=100;
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertTrue(query.end, @"结束");
        XCTAssertEqualObjects(@"AVStatus", NSStringFromClass([objects[0] class]), @"返回类型不对");
        NOTIFY;
    }];
    
    WAIT;
}

#endif

-(void)testFollowerQuery2{
    [self user:@"zeng" follow:@"travis" userDictionary:@{@"aaa":@"bbb",@"ccc":@"ddd"}];
    [self user:@"travis" follow:@"zeng" userDictionary:@{@"aaa":@"vvv",@"eee":@"fff"}];
    NSError *err = nil;
    [AVUser logInWithUsername:@"travis" password:@"123456" error:&err];
    AVQuery *query=[AVUser followerQuery:[AVUser currentUser].objectId];
    [query whereKey:@"aaa" equalTo:@"bbb"];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertTrue(objects.count > 0, @"返回个数不对");
        //        XCTAssertEqualObjects(@"AVStatus", NSStringFromClass([objects[0] class]), @"返回类型不对");
        NOTIFY;
    }];
    
    WAIT;
    [self user:@"zeng" unfollow:@"travis"];
    [self user:@"travis" unfollow:@"zeng"];
}

-(void)testFolloweeQuery2{
    [self user:@"zeng" follow:@"travis" userDictionary:@{@"aaa":@"bbb",@"ccc":@"ddd"}];
    [self user:@"travis" follow:@"zeng" userDictionary:@{@"aaa":@"vvv",@"eee":@"fff"}];
    NSError *err = nil;
    [AVUser logInWithUsername:@"zeng" password:@"123456" error:&err];
    AVQuery *query=[AVUser followeeQuery:[AVUser currentUser].objectId];
    [query whereKey:@"aaa" equalTo:@"bbb"];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertTrue(objects.count > 0, @"返回个数不对");
        //        XCTAssertEqualObjects(@"AVStatus", NSStringFromClass([objects[0] class]), @"返回类型不对");
        NOTIFY;
    }];
    
    WAIT;
    [self user:@"zeng" unfollow:@"travis"];
    [self user:@"travis" unfollow:@"zeng"];
}

-(void)testFollowWithUserDictionary {
    [self user:@"zeng" follow:@"travis" userDictionary:@{@"aaa":@"bbb",@"ccc":@"ddd"}];
    [self user:@"travis" follow:@"zeng" userDictionary:@{@"aaa":@"vvv",@"eee":@"fff"}];
    [self user:@"zeng" unfollow:@"travis"];
    [self user:@"travis" unfollow:@"zeng"];
}
@end
