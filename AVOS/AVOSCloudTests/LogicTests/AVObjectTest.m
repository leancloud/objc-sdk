
#import "AVTestBase.h"
#import "AVErrorUtils.h"
#import "AVPaasClient.h"
#import <libkern/OSAtomic.h>

@interface AVQuery (Test)

- (NSMutableArray *)processResults:(NSArray *)results className:(NSString *)className;

@end

const void *AVObjectTestDeleteAll = &AVObjectTestDeleteAll;

@interface  AVObjectTest: AVTestBase

@end

@interface AVCustomObject : AVObject<AVSubclassing>

@property (nonatomic, copy)   NSString *objectName;
@property (nonatomic, strong) AVObject *attachedObject;
@property (nonatomic, strong) AVFile   *avatar;
@property (nonatomic, strong) AVFile   *ebook;
@property (nonatomic, strong) NSArray *users; // AVUser array

@end

@implementation AVCustomObject

@dynamic objectName;
@dynamic attachedObject;
@dynamic avatar;
@dynamic ebook;
@dynamic users;

@end

@implementation AVObjectTest

+ (void)load {
    [AVCustomObject registerSubclass];
}

+ (void)setUp {
    [super setUp];
    [self deleteClass:NSStringFromClass([self class])];
    [self deleteClass:NSStringFromClass([AVCustomObject class])];
}

- (AVObject *)objectForAVObjectTest {
    AVObject *object = [AVObject objectWithClassName:self.className];
    object[@"name"] = NSStringFromSelector(_cmd);
    object[@"flag"] = @YES;
    object[@"array"] = @[[NSString stringWithFormat:@"%d", arc4random()]];
    object[@"any"] = @(arc4random());
    object[@"number"] = @(arc4random());
    NSError *error;
    [object save:&error];
    XCTAssertNil(error);
    return object;
}

- (AVObject *)fetchObjectById:(NSString *)objectId {
    AVObject *object = [AVObject objectWithoutDataWithClassName:self.className objectId:objectId];
    NSError *error;
    [object fetch:&error];
    XCTAssertNil(error);
    return object;
}

-(void)testSaveObject {
    AVObject *object = [AVObject objectWithClassName:self.className];
    [object setObject:@"teee" forKey:@"testO"];
    
    [object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"%@", error);
        [self addDeleteObject:object];
        NOTIFY
    }];
    WAIT
}

-(void)testObjectSaveWithNewFile {
    AVObject *object = [AVObject objectWithClassName:NSStringFromClass([self class])];
    
    AVFile *avatar=[AVFile fileWithName:@"avatar.jpg" contentsAtPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"alpacino.jpg" ofType:nil]];
    
    [object setObject:avatar forKey:@"avatar"];
    
    NSError *error;
    XCTAssertTrue([object save:&error], @"%@", error);
    [self addDeleteFile:avatar];
    [self addDeleteObject:object];
}

-(void)testObjectAsyncSaveWithNewFile {
    AVObject *object = [AVObject objectWithClassName:NSStringFromClass([self class])];
    
    AVFile *avatar=[AVFile fileWithName:@"avatar.jpg" contentsAtPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"alpacino.jpg" ofType:nil]];
    
    [object setObject:avatar forKey:@"avatar"];
    
    [object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"%@", error);
        [self addDeleteObject:object];
        [self addDeleteFile:avatar];
        NOTIFY
    }];
    
    NSLog(@"1 %@",[[NSThread currentThread]description]);
    WAIT
}

- (void)testObjectWithDictionary {
    NSDictionary *dict = @{@"afterSave":@"1"};
    AVObject *object = [AVObject objectWithClassName:NSStringFromClass([self class]) dictionary:dict];
    XCTAssertEqualObjects([object objectForKey:@"afterSave"], @"1");
}

- (void)testSyncSaveAll {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:10];
    
    for (int i = 0; i < 10; i++) {
        AVObject *object = [AVObject objectWithClassName:NSStringFromClass([self class])];
        [object setObject:@"jump" forKey:@"action"];
        [array addObject:object];
    }
    
    NSError *error;
    XCTAssertTrue([AVObject saveAll:array error:&error], @"%@", error);
    [self addDeleteObjects:array];
}

- (void)testFetchAll {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:10];
    for (int i = 0; i < 10; i++) {
        AVObject *object = [AVObject objectWithClassName:NSStringFromClass([self class])];
        [object setObject:@"jump" forKey:@"action"];
        [array addObject:object];
    }
    [self addDeleteObjects:array];

    NSError *error;
    XCTAssertTrue([AVObject saveAll:array error:&error], @"%@", error);

//    WAIT_10;
    AVQuery *query = [AVQuery queryWithClassName:NSStringFromClass([self class])];
    query.limit = 5;
    NSArray *data = [query findObjects];
    XCTAssertEqual(data.count, 5, "should have 5 objects");
    
    NSMutableArray *array1 = [NSMutableArray arrayWithCapacity:10];
    NSMutableArray *array2 = [NSMutableArray arrayWithCapacity:10];
    
    for (AVObject *obj in data) {
        AVObject *objToFetch = [AVObject objectWithoutDataWithClassName:NSStringFromClass([self class]) objectId:obj.objectId];
        [array1 addObject:objToFetch];
        [array2 addObject:objToFetch];
    };
    [AVObject fetchAllIfNeededInBackground:array1 block:^(NSArray *objects, NSError *errorInside) {
        XCTAssertFalse([errorInside.domain isEqualToString:kAVErrorDomain], @"%@", errorInside);
        XCTAssertEqual(data.count, objects.count, @"fetch fail");
        NSLog(@"+++++++++++++++++++++++");
        
        NSError *error;
        [AVObject fetchAllIfNeeded:array2 error:&error];
        NSLog(@"--------------------");
        XCTAssertNil(error, @"%@", error);
        NSLog(@"%@",array1);
        
        NOTIFY;
        
    }];
    
    NSLog(@"==========================");
    WAIT_FOREVER;
}

- (void)testFetchError {
    AVObject * object = [AVObject objectWithoutDataWithClassName:self.className objectId:@"abc"];
    NSError *error;
    BOOL result = [object fetch:&error];
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, kAVErrorObjectNotFound);
}

- (void)testFetchAllError {
    AVObject * object = [AVObject objectWithoutDataWithClassName:self.className objectId:@"abc"];
    NSError *error;
    BOOL result = [AVObject fetchAll:@[object] error:&error];
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, kAVErrorObjectNotFound);
}


- (void)testSaveAllDescendantObjects {
    AVCustomObject *object1 = [[AVCustomObject alloc] init];
    AVCustomObject *object2 = [[AVCustomObject alloc] init];

    object1.objectName = @"Object 1";
    object2.objectName = @"Object 2";

    object1.attachedObject = object2;

    NSError *error = nil;

    [AVObject saveAll:@[object1] error:&error];

    XCTAssert(!error, @"%@", error);
    XCTAssert(object2.objectId != nil, @"Object 2 not saved.");
}

- (void)testSaveAllDescendantFiles {
    AVCustomObject *object = [[AVCustomObject alloc] init];

    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"alpacino.jpg" ofType:nil];

    object.avatar  = [AVFile fileWithName:@"avatar" contentsAtPath:filePath];
    object.ebook = [AVFile fileWithName:@"avatar" contentsAtPath:filePath];

    NSError *error = nil;

    [AVObject saveAll:@[object] error:&error];

    XCTAssert(!error, @"%@", error);
    XCTAssert(object.objectId != nil, @"Object not saved.");
    XCTAssert(object.avatar.url != nil, @"Avatar not uploaded.");
    XCTAssert(object.ebook.url != nil, @"Ebook not uploaded.");
}

- (void)testSaveAllDescendantFilesInBackground {
    AVCustomObject *object = [[AVCustomObject alloc] init];

    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"alpacino.jpg" ofType:nil];

    object.avatar  = [AVFile fileWithName:@"avatar" contentsAtPath:filePath];
    object.ebook = [AVFile fileWithName:@"avatar" contentsAtPath:filePath];

    [AVObject
     saveAllInBackground:@[object]
     block:^(BOOL succeeded, NSError *error) {
         XCTAssert(!error, @"%@", error);
         XCTAssert(object.objectId != nil, @"Object not saved.");
         XCTAssert(object.avatar.url != nil, @"Avatar not uploaded.");
         XCTAssert(object.ebook.url != nil, @"Ebook not uploaded.");

         NOTIFY;
     }];

    WAIT_FOREVER;
}

- (void)testSaveAllAlreadySavedFile {
    AVCustomObject *object = [[AVCustomObject alloc] init];
    
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"alpacino.jpg" ofType:nil];
    AVFile *file = [AVFile fileWithName:@"avatar" contentsAtPath:filePath];

    NSError *error = nil;
    [file save:&error];

    XCTAssert(!error, @"%@", error);
    XCTAssert(file.url != nil, @"File not uploaded.");

    NSString *prevObjectId = file.objectId;

    object.avatar  = file;

    [AVObject saveAll:@[object] error:&error];

    NSString *currObjectId = file.objectId;

    XCTAssert(!error, @"%@", error);
    XCTAssert(object.objectId != nil, @"Object not saved.");
    XCTAssert(object.avatar.url != nil, @"Avatar not uploaded.");
    XCTAssert([prevObjectId isEqualToString:currObjectId], @"File duplicated uploaded.");
}

- (void)testSaveQueriedFile {
    AVCustomObject *object1 = [[AVCustomObject alloc] init];

    object1.objectName = @"The Object";

    object1.avatar = ({
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"alpacino.jpg" ofType:nil];
        [AVFile fileWithName:@"Info-plist" contentsAtPath:filePath];
    });

    NSError *error = nil;
    [AVObject saveAll:@[object1] error:&error];

    XCTAssert(!error, @"%@", error);

    NSString *fileId1 = object1.avatar.objectId;

    AVQuery *object1Query = [AVQuery queryWithClassName:@"AVCustomObject"];
    [object1Query whereKey:@"objectId" equalTo:object1.objectId];

    NSArray *objects = [object1Query findObjects:&error];

    XCTAssert(!error, @"%@", error);
    XCTAssert([objects count] == 1, @"Object not found.");

    AVCustomObject *queriedObject1 = [objects objectAtIndex:0];

    AVFile *queriedAvatar = queriedObject1.avatar;

    AVCustomObject *object2 = [[AVCustomObject alloc] init];
    object2.avatar = queriedAvatar;

    [AVObject saveAll:@[object2] error:&error];

    XCTAssert(!error, @"%@", error);

    NSString *fileId2 = object2.avatar.objectId;

    XCTAssert([fileId1 isEqualToString:fileId2], @"File upload duplicated.");

    AVCustomObject *object3 = [[AVCustomObject alloc] init];
    object3.avatar = queriedAvatar;

    [object3 save:&error];

    XCTAssert(!error, @"%@", error);

    NSString *fileId3 = object3.avatar.objectId;

    XCTAssert([fileId1 isEqualToString:fileId3], @"File upload duplicated.");
}

//- (void)testSetObjectWithInternalKeyName {
//    AVObject *object = [AVObject objectWithClassName:NSStringFromClass([self class])];
//    [object save];
//    NSString *objectId1 = object.objectId;
//    [object setObject:@"xxxx" forKey:@"objectId"];
//    [object save];
//    NSString *objectId2 = object.objectId;
//    [self addDeleteObject:object];
//    NSLog(@"%@", object);
//    XCTAssertEqualObjects(objectId1, objectId2, @"object id should not change");
//}

- (void)testSaveRelation {
    NSString *username = NSStringFromSelector(_cmd);
    AVUser *user = [AVUser user];
    user.username = [NSString stringWithFormat:@"%@", username];
    user.password = @"123456";
    [user signUp:nil];
    [self addDeleteObject:user];
    
    AVObject *object = [AVObject objectWithClassName:NSStringFromClass([self class])];
    [object save];
    [self addDeleteObject:object];
    
    AVObject *student = [AVObject objectWithoutDataWithClassName:NSStringFromClass([self class]) objectId:object.objectId];
    [student fetch];
    
    // don't change anything of user, then save student
    [student setObject:@"testName1" forKey:@"name"];
    [student setObject:user forKey:@"parent"];
    [student save];
    
    // change content of user, then save student
    AVUser *user2 = [student objectForKey:@"parent"];
    [user2 setObject:@"testNickName" forKey:@"nickName"];

    [student setObject:@"testName2" forKey:@"name"];
    [student save];
    
    XCTAssertEqualObjects(user.objectId, user2.objectId, @"user should not change");
    
}

- (void)testCreatedAt {
    AVObject *object1 = [AVObject objectWithClassName:self.className];
    [object1 save];
    [self addDeleteObject:object1];
    
    NSString *objectId = object1.objectId;
    AVObject *object2 = [AVObject objectWithoutDataWithClassName:self.className objectId:objectId];
    [object2 fetch];
    XCTAssertEqualObjects(object1.createdAt, object2.createdAt, @"time is not equal");
}

- (void)testCirculationPointer {
    NSError *error = nil;
    NSString *className = NSStringFromClass([self class]);
    AVObject *object1 = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@1", className]];
//    [object1 save:&error];
//    XCTAssertNil(error, @"%@", error);

    AVObject *object2 = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@2", className]];
    [object2 setObject:object1 forKey:NSStringFromSelector(_cmd)];
    [object1 setObject:object2 forKey:NSStringFromSelector(_cmd)];
    [object2 save:&error];
    XCTAssertNil(error, @"%@", error);
    [self addDeleteObject:object2];

//    [object1 setObject:object2 forKey:NSStringFromSelector(_cmd)];
//    [object1 save:&error];
//    XCTAssertNil(error, @"%@", error);
    [self addDeleteObject:object1];
}

- (AVUser *)registerOrLoginWithUsername:(NSString *)username password:(NSString *)password {
    AVUser *user = [AVUser user];
    user.username = username;
    user.password = password;
    NSError *error = nil;
    [user signUp:&error];
    if (!error) {
        return user;
    } else if (error.code == kAVErrorUsernameTaken) {
        NSError *loginError;
        AVUser *loginUser = [AVUser logInWithUsername:username password:password error:&loginError];
        XCTAssertNil(loginError);
        return loginUser;
    } else {
        XCTAssertNil(error);
        return nil;
    }
}

- (void)testACL {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd) password:@"123456"];
    [self addDeleteObject:user];
    AVACL *acl = [[AVACL alloc] init];
    [acl setReadAccess:YES forUser:user];
    [acl setWriteAccess:YES forUser:user];
    [acl setReadAccess:YES forRoleWithName:@"administrators"];
    [acl setWriteAccess:YES forRoleWithName:@"administrators"];

    NSError *error;
    AVObject *object = [AVObject objectWithClassName:NSStringFromClass([self class])];
    [object setACL:acl];
    [object save:&error];
//    [self addDeleteObject:object];
    XCTAssertNil(error, @"%@", error);
    [object delete];
}

- (void)testObjectFromDictionary {
    NSString *json = @"{\"result\":[{\"gender\":true,\"profileThumbnail\":{\"__type\":\"File\",\"id\":\"5416e87fe4b0f645f29e15cd\",\"name\":\"ugQgIhsiRCBmAyUXPiJBIXvMEQHmq2zoRV6RVabF\",\"url\":\"http://ac-mgqe2oiy.qiniudn.com/4nTUcDbKVGDZymrd\"},\"profilePicture\":{\"__type\":\"File\",\"id\":\"5416e877e4b0f645f29e15b6\",\"name\":\"fdrWE627VCPGB8pi1p343XiYk3f2m93mEtU3IvLD\",\"url\":\"http://ac-mgqe2oiy.qiniudn.com/eyeFsPgmhxlaPfK8\"},\"activeness\":0,\"nickName\":\"璇璇\",\"likedCount\":750,\"pickiness\":0.15086206896551724,\"username\":\"18588888888\",\"viewedCount\":962,\"viewCount\":232,\"mobilePhoneVerified\":false,\"nearestOnline\":0,\"peerId\":\"18588888888\",\"importFromParse\":false,\"emailVerified\":false,\"signature\":\"~大家好~!希望在钟情交到一些朋友!喜欢我的话就赞我吧！\",\"likeCount\":35,\"recommendIndex\":0.6376030539823643,\"postCount\":3,\"hotness\":0.7796257796257796,\"meetedUser\":{\"__type\":\"Relation\",\"className\":\"_User\"},\"playlistRel\":{\"__type\":\"Relation\",\"className\":\"Playlist\"},\"lastOnlineDate\":{\"__type\":\"Date\",\"iso\":\"2014-10-01T03:55:28.163Z\"},\"birthday\":{\"__type\":\"Date\",\"iso\":\"1991-03-15T13:22:12.000Z\"},\"post0\":{\"media\":{\"__type\":\"File\",\"name\":\"media.mp4\",\"url\":\"http://ac-mgqe2oiy.qiniudn.com/k4TO50kRytl2YTAR.mp4\"},\"cover\":{\"__type\":\"File\",\"name\":\"QOoUkunpDf8LwRAegol7M07Pia3p8umgBSJtsXqn\",\"url\":\"http://ac-mgqe2oiy.qiniudn.com/Gu6uLsGds6FqKnWJ\"},\"posterRlt\":{\"__type\":\"Relation\",\"className\":\"_User\"},\"objectId\":\"5412c79be4b080380a4895b6\",\"createdAt\":\"2014-09-12T10:14:51.102Z\",\"updatedAt\":\"2014-09-12T10:14:51.108Z\"},\"post1\":{\"media\":{\"__type\":\"File\",\"name\":\"media.mp4\",\"url\":\"http://ac-mgqe2oiy.qiniudn.com/aNm5STA2uuVAXrJi.mp4\"},\"cover\":{\"__type\":\"File\",\"name\":\"CtGjAUT1JoKo9JI5CL0xWMsm0NVjjU0CWL9UO4DB\",\"url\":\"http://ac-mgqe2oiy.qiniudn.com/GPWno3YM2L6D08ub\"},\"posterRlt\":{\"__type\":\"Relation\",\"className\":\"_User\"},\"objectId\":\"541934ece4b013b181daab26\",\"createdAt\":\"2014-09-17T07:14:52.461Z\",\"updatedAt\":\"2014-09-17T07:14:52.473Z\"},\"post2\":{\"media\":{\"__type\":\"File\",\"name\":\"media.mp4\",\"url\":\"http://ac-mgqe2oiy.qiniudn.com/KwsYBMOzyGXZGzDU.mp4\"},\"cover\":{\"__type\":\"File\",\"name\":\"lUNfftRFnu2xJ7IONu1wAoMtAQFEERTADkLmKST7\",\"url\":\"http://ac-mgqe2oiy.qiniudn.com/YOR7l2ws58DlJYiG\"},\"posterRlt\":{\"__type\":\"Relation\",\"className\":\"_User\"},\"objectId\":\"5419a7d2e4b0002e6997c743\",\"createdAt\":\"2014-09-17T15:25:06.765Z\",\"updatedAt\":\"2014-09-17T15:25:06.782Z\"},\"objectId\":\"5416e880e4b0f645f29e15ce\",\"createdAt\":\"2014-09-15T13:24:16.128Z\",\"updatedAt\":\"2014-10-09T07:50:40.971Z\"}]}";
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
    NSDictionary *o = [[dict objectForKey:@"result"] objectAtIndex:0];
    AVUser *user = [AVUser user];
    [user objectFromDictionary:o];
    NSLog(@"user:%@", user);
}
//- (void)testArrayObjects {
//    AVObject *comment = [AVObject objectWithClassName:@"Comment"];
//    AVObject *post = 
//    comment.text = commentText;
//    comment.owner = [AVUser currentUser];
//    comment.post = self.post;
//    comment.gender = [[AVUser currentUser] objectForKey:@"gender"];
//    [comment saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
//        if (succeeded) {
//        } else {
//            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"抱歉"
//                                                                message:@"评论发送失败"
//                                                               delegate:nil
//                                                      cancelButtonTitle:@"再试一次?"
//                                                      otherButtonTitles:nil];
//            [alertView show];
//        }
//    }];
//}

- (void)testPointer {
    AVObject *shareItem = [AVObject objectWithClassName:@"ShareItem"];
    [shareItem setObject:@"test" forKey:@"shareItemDescription"];
    
    AVObject *location = [AVObject objectWithClassName:@"Location"];
    [location setObject:@(1) forKey:@"latitude"];
    [location setObject:@(2) forKey:@"longitude"];
    [location setObject:shareItem forKey:@"parent"];
    [location saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        NOTIFY;
    }];
    WAIT;
    AVObject *post = [AVObject objectWithClassName:@"QINPost"];
    [post setObject:@"rthuh" forKey:@"text"];
    
    AVObject *comment = [AVObject objectWithClassName:@"QINComment"];
    [comment setObject:@"text" forKey:@"text"];
    [comment setObject:post forKey:@"post"];
    [post addUniqueObject:comment forKey:@"comments"];
    [comment saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        // Todo, error in [post addUniqueObject:comment forKey:@"comments"]
        XCTAssertEqual(error.code, 106);
        XCTAssertEqualObjects(error.localizedDescription, @"Malformed pointer. Pointers must be arrays of a classname and an object id.");
        NOTIFY;
    }];
    WAIT;
}

- (void)testSaveComplexObject {
    AVObject *c221 = [AVObject objectWithClassName:@"C221classes"];
    [c221 setObject:@"c221" forKey:@"value"];
    
    AVObject *c22 = [AVObject objectWithClassName:@"C22classes"];
    [c22 setObject:@"c22" forKey:@"value"];
    [c22 setObject:c221 forKey:@"c221"];
    
    AVObject *c2 = [AVObject objectWithClassName:@"C2classes"];
    [c2 setObject:@"c2" forKey:@"value"];
    [c2 setObject:c22 forKey:@"c22"];
    // c2 <- c22 <- c221
    
    AVObject *c1 = [AVObject objectWithClassName:@"C1Classes"];
    [c1 setObject:@"c1" forKey:@"value"];
    
    AVObject *parentClass = [AVObject objectWithClassName:@"parentClass"];
    [parentClass setObject:@(999999) forKey:@"score"];
    [parentClass setObject:c1 forKey:@"c1"];
    [parentClass setObject:c2 forKey:@"c2"];

    XCTAssertTrue([parentClass save]);
    
    [self addDeleteObjects:@[parentClass, c1, c2, c22,c221]];
    
    XCTAssertEqualObjects([parentClass objectForKey:@"score"], @(999999));
    AVObject *returnC1 = [parentClass objectForKey:@"c1"];
    AVObject *returnC2 = [parentClass objectForKey:@"c2"];
    AVObject *returnC22 = [returnC2 objectForKey:@"c22"];
    AVObject *returnC221 = [returnC22 objectForKey:@"c221"];
    XCTAssertEqual(c221, c221);
    XCTAssertEqualObjects([returnC1 objectForKey:@"value"], @"c1");
    XCTAssertEqualObjects([returnC2 objectForKey:@"value"], @"c2");
    XCTAssertEqualObjects([returnC22 objectForKey:@"value"], @"c22");
    XCTAssertEqualObjects([returnC221 objectForKey:@"value"], @"c221");
}

// 需要管理台创建 Any Type 的列
- (void)testAnyType {
    AVObject *object = [AVObject objectWithClassName:self.className];
    [object setObject:@(1) forKey:@"any"];
    XCTAssertTrue([object save]);
    XCTAssertEqualObjects(@(1), [object objectForKey:@"any"]);
    
    [object setObject:@"hello world" forKey:@"any"];
    XCTAssertTrue([object save]);
    XCTAssertEqualObjects(@"hello world", [object objectForKey:@"any"]);
    
    [object setObject:@{@"score":@(100), @"name":@"shit"} forKey:@"any"];
    XCTAssertTrue([object save]);
    XCTAssertEqualObjects(@(100), [object objectForKey:@"any"][@"score"]);
    XCTAssertEqualObjects(@"shit", [object objectForKey:@"any"][@"name"]);
    
    AVObject *fetchObject = [AVObject objectWithoutDataWithClassName:self.className objectId:object.objectId];
    XCTAssertTrue([fetchObject fetch]);
    XCTAssertEqualObjects(@(100), [fetchObject objectForKey:@"any"][@"score"]);
    XCTAssertEqualObjects(@"shit", [fetchObject objectForKey:@"any"][@"name"]);
    
    [self addDeleteObject:object];
}

- (void)testBooleanType {
    AVObject *object1 = [AVObject objectWithClassName:self.className];
    [object1 setObject:@YES forKey:@"flag"];
    XCTAssertTrue([object1 save]);
    
    AVQuery *q = [AVQuery queryWithClassName:self.className];
    [q whereKey:@"flag" equalTo:@YES];
    [q orderByDescending:@"createdAt"];
    AVObject *object2 = [q getFirstObject];
    XCTAssertNotNil(object2);
    XCTAssertEqualObjects(object2.objectId, object1.objectId);
    
    [self addDeleteObject:object1];
}

#pragma mark - delete

- (void)testDelete {
    AVObject *object = [AVObject objectWithClassName:self.className];
    [object setObject:@"jump" forKey:@"action"];
    XCTAssertTrue([object save]);
    
    XCTAssertTrue([object delete]);
    
    AVObject *deletedObject = [AVObject objectWithoutDataWithClassName:self.className objectId:object.objectId];
    NSError *error;
    XCTAssertFalse([deletedObject fetch:&error]);
    XCTAssertEqual(error.code, kAVErrorObjectNotFound);
}

- (void)testDeleteAll {
    NSMutableArray *objects = [NSMutableArray array];
    for (NSInteger i = 0; i < 6; i++) {
        AVObject *object = [AVObject objectWithClassName:self.className];
        [object setObject:@(i) forKey:@"any"];
        XCTAssertTrue([object save]);
        [objects addObject:object];
    }
    
    [AVObject deleteAllInBackground:[objects subarrayWithRange:NSMakeRange(0, 2)] block:^(BOOL succeeded, NSError *error) {
        XCTAssertNil(error);
        [self postNotification:AVObjectTestDeleteAll];
    }];
    [self waitNotification:AVObjectTestDeleteAll];
    
    NSError *error;
    XCTAssertTrue([AVObject deleteAll:[objects subarrayWithRange:NSMakeRange(2, 2)] error:&error]);
    XCTAssertNil(error);
    
    XCTAssertTrue([AVObject deleteAll:[objects subarrayWithRange:NSMakeRange(4, 2)]]);
    
    for (AVObject *object in objects) {
        AVObject *deletedObject = [AVObject objectWithoutDataWithClassName:self.className objectId:object.objectId];
        NSError *error;
        XCTAssertFalse([deletedObject fetch:&error]);
        XCTAssertEqual(error.code, kAVErrorObjectNotFound);
    }
}

- (void)testParseDescriptionKey {
    NSDictionary *dict = [self jsonWithFileName:@"TestDescriptionKey"];
    AVObject *object = [AVObject objectWithClassName:@"term_taxonomy"];
    [object objectFromDictionary:dict];
    XCTAssertEqualObjects(object[@"description"], @"description");
}

- (void)testSaveAllWithInstallationChild {
    NSDictionary *json = [self jsonWithFileName:@"TestSaveAll"];
    NSArray *results = json[@"results"];
    AVQuery *query = [AVQuery queryWithClassName:@"AddRequest"];
    NSArray *objects= [query processResults:results className:nil];
    for (AVObject *obj in objects) {
        obj[@"isRead"] = @(YES);
    }
    for (AVObject *obj in objects) {
        NSArray *saveRequests = [obj buildSaveRequests];
        XCTAssertEqual(saveRequests.count, 1);
    }
}

- (void)testSaveError {
    AVObject *obj = [AVObject objectWithClassName:self.className];
    [obj setObject:@(YES) forKey:@"flag"];
    NSError *error;
    [obj save:&error];
    XCTAssertNil(error);
    
    [obj setObject:@"string" forKey:@"flag"];
    [obj save:&error];
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 111);
    XCTAssertEqualObjects(error.localizedDescription, @"Invalid value type for field 'flag',expect type is {:type \"Boolean\"},but it is '{:type \"String\"}'.");
}

- (void)testSaveAllError {
    AVObject *obj = [AVObject objectWithClassName:self.className];
    [obj setObject:@(YES) forKey:@"flag"];
    NSError *error;
    [obj save:&error];
    XCTAssertNil(error);
    
    [obj setObject:@"string" forKey:@"flag"];
    
    [AVObject saveAll:@[obj] error:&error];
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 111);
    XCTAssertEqualObjects(error.localizedDescription, @"Invalid value type for field 'flag',expect type is {:type \"Boolean\"},but it is '{:type \"String\"}'.");
}

- (void)testSaveAllBatchRequest {
    NSMutableArray *objects = [NSMutableArray array];
    for (NSInteger i = 0; i < 150; i ++) {
        AVObject *obj = [AVObject objectWithClassName:self.className];
        obj[@"any"] = @(i);
        [objects addObject:obj];
    }
    NSError *error;
    [AVObject saveAll:objects error:&error];
    XCTAssertNil(error);
    for (AVObject *obj in objects) {
        XCTAssertNotNil(obj.objectId);
        XCTAssertNotNil(obj.createdAt);
        XCTAssertNotNil(obj[@"any"]);
    }
}

- (AVObject *)objectForTest {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    [object setObject:@"test string" forKey:@"string"];
    [object setObject:@1 forKey:@"number"];
    NSError *error = nil;
    [object save:&error];
    XCTAssertNil(error);
    [self addDeleteObject:object];
    return object;
}

- (void)testObjectWithClassName {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    XCTAssertNotNil(object);
}

- (void)testObjectWithoutDataWithClassName_objectId {
    NSString *className = @"TestObject";
    NSString *objectId = @"anTestObjectId";
    AVObject *object = [AVObject objectWithoutDataWithClassName:className objectId:objectId];
    XCTAssertEqualObjects(object.objectId, objectId);
}

- (void)testObjectWithClassName_dictionary {
    NSString *className = @"TestObject";
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:@"val1" forKey:@"key1"];
    [dict setObject:@2 forKey:@"key2"];
    AVObject *object = [AVObject objectWithClassName:className dictionary:dict];
    XCTAssertEqualObjects(object[@"key1"], @"val1");
    XCTAssertEqualObjects(object[@"key2"], @2);
}

- (void)testInitWithClassName {
    NSString *className = @"TestObject";
    AVObject *object = [[AVObject alloc] initWithClassName:className];
    XCTAssertEqualObjects(object.className, className);
}

- (void)testAllKeys {
    AVObject *testObject = [self objectForTest];
    NSArray *allKeys = [testObject allKeys];
    //    NSLog(@"allKeys:%@", allKeys);
    XCTAssertTrue([allKeys containsObject:@"string"]);
    XCTAssertTrue([allKeys containsObject:@"number"]);
    XCTAssertFalse([allKeys containsObject:@"createdAt"]);
    XCTAssertFalse([allKeys containsObject:@"updatedAt"]);
    XCTAssertFalse([allKeys containsObject:@"authData"]);
    XCTAssertFalse([allKeys containsObject:@"objectId"]);
}

- (void)testObjectForKey {
    AVObject *testObject = [self objectForTest];
    NSString *val = [testObject objectForKey:@"string"];
    XCTAssertEqualObjects(val, @"test string");
}

- (void)testSetObject_forKey {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    XCTAssertNoThrow([object setObject:@"test string" forKey:@"string"]);
    NSArray *invalidKeys = @[@"code",
                             @"uuid",
                             @"className",
                             @"keyValues",
                             @"fetchWhenSave",
                             @"running",
                             @"acl",
                             @"ACL",
                             @"pendingKeys",
                             @"createdAt",
                             @"updatedAt",
                             @"objectId"];
    for (NSString *key in invalidKeys) {
        XCTAssertThrows([object setObject:@"test object" forKey:key]);
    }
}

- (void)testRemoveObjectForKey {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    [object setObject:@"test string" forKey:@"string"];
    
    XCTAssertNoThrow([object removeObjectForKey:@"string"]);
    XCTAssertNil([object objectForKey:@"string"]);
    XCTAssertThrows([object removeObjectForKey:nil]);
}

- (void)testObjectForKeyedSubscript {
    AVObject *testObject = [self objectForTest];
    NSString *val = testObject[@"string"];
    XCTAssertEqualObjects(val, @"test string");
}

- (void)testSetObject_forKeyedSubscript {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    XCTAssertNoThrow(object[@"string"] = @"test string");
    NSArray *invalidKeys = @[@"code",
                             @"uuid",
                             @"className",
                             @"keyValues",
                             @"fetchWhenSave",
                             @"running",
                             @"acl",
                             @"ACL",
                             @"pendingKeys",
                             @"createdAt",
                             @"updatedAt",
                             @"objectId"];
    for (NSString *key in invalidKeys) {
        XCTAssertThrows(object[key] = @"test object");
    }
}

- (void)testRelationForKey {
    NSString *className = @"TestObject";
    AVObject *objectA = [AVObject objectWithClassName:className];
    AVObject *objectB = [AVObject objectWithClassName:className];
    
    AVRelation *relation = [objectA relationforKey:@"relation"];
    XCTAssertThrows([relation addObject:objectB]);
    NSError *error = nil;
    [objectB save:&error];
    XCTAssertNil(error);
    XCTAssertNoThrow([relation addObject:objectB]);
    [objectA save:&error];
    XCTAssertNil(error);
    [self addDeleteObject:objectA];
    [self addDeleteObject:objectB];
}

- (void)testAddObject_forKey {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    [object addObject:@"test string 1" forKey:@"array"];
    NSError *error = nil;
    [object save:&error];
    XCTAssertNil(error);
    object = [AVObject objectWithoutDataWithClassName:className objectId:object.objectId];
    [object addObject:@"test string 2" forKey:@"array"];
    [object save:&error];
    XCTAssertNil(error);
    [object fetch:&error];
    XCTAssertNil(error);
    NSArray *array = [object objectForKey:@"array"];
    XCTAssertEqual(array.count, 2);
    [self addDeleteObject:object];
}

- (void)testAddObjectsFromArray_forKey {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    [object addObjectsFromArray:@[@"test string 1", @"test string 2"] forKey:@"array"];
    NSError *error = nil;
    [object save:&error];
    XCTAssertNil(error);
    object = [AVObject objectWithoutDataWithClassName:className objectId:object.objectId];
    [object addObjectsFromArray:@[@"test string 3", @"test string 4"] forKey:@"array"];
    [object save:&error];
    XCTAssertNil(error);
    [object fetch:&error];
    XCTAssertNil(error);
    NSArray *array = [object objectForKey:@"array"];
    XCTAssertEqual(array.count, 4);
    [self addDeleteObject:object];
}

- (void)testAddUniqueObject_forKey {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    [object addUniqueObject:@"test string 1" forKey:@"array"];
    NSError *error = nil;
    [object save:&error];
    XCTAssertNil(error);
    object = [AVObject objectWithoutDataWithClassName:className objectId:object.objectId];
    [object addUniqueObject:@"test string 1" forKey:@"array"];
    [object save:&error];
    XCTAssertNil(error);
    object = [AVObject objectWithoutDataWithClassName:className objectId:object.objectId];
    [object addUniqueObject:@"test string 2" forKey:@"array"];
    [object save:&error];
    XCTAssertNil(error);
    [object fetch:&error];
    XCTAssertNil(error);
    NSArray *array = [object objectForKey:@"array"];
    XCTAssertEqual(array.count, 2);
    [self addDeleteObject:object];
}

- (void)testAddUniqueObjectsFromArray_forKey {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    [object addUniqueObjectsFromArray:@[@"test string 1", @"test string 2"] forKey:@"array"];
    NSError *error = nil;
    [object save:&error];
    XCTAssertNil(error);
    object = [AVObject objectWithoutDataWithClassName:className objectId:object.objectId];
    [object addUniqueObjectsFromArray:@[@"test string 2", @"test string 3"] forKey:@"array"];
    [object save:&error];
    XCTAssertNil(error);
    [object fetch:&error];
    XCTAssertNil(error);
    NSArray *array = [object objectForKey:@"array"];
    XCTAssertEqual(array.count, 3);
    [self addDeleteObject:object];
}

- (void)testRemoveObject_forKey {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    [object addObjectsFromArray:@[@"test string 1", @"test string 2", @"test string 2", @"test string 3"] forKey:@"array"];
    NSError *error = nil;
    [object save:&error];
    XCTAssertNil(error);
    object = [AVObject objectWithoutDataWithClassName:className objectId:object.objectId];
    [object removeObject:@"test string 2" forKey:@"array"];
    [object save:&error];
    XCTAssertNil(error);
    [object fetch:&error];
    XCTAssertNil(error);
    NSArray *array = [object objectForKey:@"array"];
    XCTAssertEqual(array.count, 2);
    [self addDeleteObject:object];
}

/**
 *  For https://forum.leancloud.cn/t/ios-avobject/3728/3
 */
- (void)testRemoveObject_forKey_RemoveAVObject {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd) password:@"123456"];
    AVCustomObject *object = [AVCustomObject object];
    object.users = @[user];
    NSError *error;
    [object save:&error];
    assertNil(error);
    assertTrue([object.users containsObject:user]);
    
    [object removeObject:user forKey:@"users"];
    [object save:&error];
    assertNil(error);
    assertEqual(object.users.count, 0);
    assertFalse([object.users containsObject:user]);
}

- (void)testRemoveObjectsInArray_forKey {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    [object addObjectsFromArray:@[@"test string 1", @"test string 2", @"test string 2", @"test string 3"] forKey:@"array"];
    NSError *error = nil;
    [object save:&error];
    XCTAssertNil(error);
    object = [AVObject objectWithoutDataWithClassName:className objectId:object.objectId];
    [object removeObjectsInArray:@[@"test string 2", @"test string 3", @"test string 4"] forKey:@"array"];
    [object save:&error];
    XCTAssertNil(error);
    [object fetch:&error];
    XCTAssertNil(error);
    NSArray *array = [object objectForKey:@"array"];
    XCTAssertEqual(array.count, 1);
    [self addDeleteObject:object];
}

- (void)testIncrementKey {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    NSError *error = nil;
    [object save:&error];
    XCTAssertNil(error);
    object = [AVObject objectWithoutDataWithClassName:className objectId:object.objectId];
    [object incrementKey:@"number"];
    [object save:&error];
    XCTAssertNil(error);
    [object fetch:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects([object objectForKey:@"number"], @1);
    [self addDeleteObject:object];
}

- (void)testIncrementKey_byAmount {
    NSString *className = @"TestObject";
    AVObject *object = [AVObject objectWithClassName:className];
    NSError *error = nil;
    [object save:&error];
    XCTAssertNil(error);
    object = [AVObject objectWithoutDataWithClassName:className objectId:object.objectId];
    [object incrementKey:@"number" byAmount:@3];
    object.fetchWhenSave = YES;
    [object save:&error];
    XCTAssertNil(error);
    [object fetch:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects([object objectForKey:@"number"], @3);
    [self addDeleteObject:object];
}

- (void)testSave {
    NSString *className = @"TestObject";
    AVObject *objectA = [AVObject objectWithClassName:className];
    AVObject *objectB = [AVObject objectWithClassName:className];
    [objectA setObject:objectB forKey:@"object"];
    [objectA save];
    [self addDeleteObject:objectA];
    [self addDeleteObject:objectB];
}

- (void)testSetTwoTimesForOneKey {
    AVObject *obj = [AVObject objectWithClassName:self.className];
    [obj addObject:@"swimming" forKey:@"array"];
    [obj addUniqueObject:@"running" forKey:@"array"];
    NSError *error;
    [obj save:&error];
    XCTAssertNil(error);
    
    AVObject *fetchObj = [AVObject objectWithoutDataWithClassName:self.className objectId:obj.objectId];
    [fetchObj fetch];
    NSArray *array = obj[@"array"];
    XCTAssertEqual(array.count, 2);
    XCTAssertTrue([array containsObject:@"swimming"]);
    XCTAssertTrue([array containsObject:@"running"]);
}


- (void)testRemoveKey {
    AVObject *obj = [self objectForTest];
    [obj removeObjectForKey:@"string"];
    [obj setObject:nil forKey:@"number"];
    NSError *error;
    [obj save:&error];
    
    AVObject *fetchObj = [AVObject objectWithoutDataWithClassName:@"TestObject" objectId:obj.objectId];
    [fetchObj fetch];
    XCTAssertNil(fetchObj[@"string"]);
    XCTAssertNil(fetchObj[@"number"]);
}

- (void)testDictionaryForObject {
    AVObject *obj = [self objectForTest];
    NSDictionary *dict = [obj dictionaryForObject];
    XCTAssertNotNil(dict);
    XCTAssertEqual(dict.count, 6);
    XCTAssertEqual(dict[@"__type"], @"Object");
    XCTAssertEqualObjects(dict[@"string"], @"test string");
    XCTAssertEqual([dict[@"number"] intValue], 1);
    XCTAssertEqual(dict[@"className"], @"TestObject");
    XCTAssertNotNil(dict[@"objectId"]);
    XCTAssertNotNil(dict[@"createdAt"]);
}

- (void)testComplexDictionaryForObject {
    NSMutableDictionary *serverJson = [[self jsonWithFileName:@"TestDictionaryForObject"] mutableCopy];
    AVUser *user = [AVUser user];
    [user objectFromDictionary:serverJson];
    NSDictionary *snapshot = [user dictionaryForObject];
    serverJson[@"className"] = @"_User";
    XCTAssertEqual(serverJson.count, snapshot.count - 1); // the 1 is __type:Object
    for (NSString *key in [serverJson allKeys]) {
        XCTAssertNotNil(snapshot[key], @"%@ 's value is nil", key);
        if ([key isEqualToString:@"updatedAt"] || [key isEqualToString:@"createdAt"]) {
            XCTAssertEqualObjects(snapshot[key][@"iso"], serverJson[key]);
        } else {
            XCTAssertEqualObjects(snapshot[key], serverJson[key], @"%@'s value not equal", key);
        }
    }
}

- (void)testSaveSimultaneously {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd)];
    NSString *nickName = [NSString stringWithFormat:@"%ud", arc4random()];
    user[@"nickName"] = nickName;
    __block BOOL calledFirstBlock = 0;
    [user saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        calledFirstBlock = YES;
        XCTAssertNil(error);
    }];
    
    NSString *username = [NSString stringWithFormat:@"%@%@",NSStringFromSelector(_cmd), nickName];
    user.username = username;
    [user saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(calledFirstBlock);
        XCTAssertNil(error);
        NOTIFY;
    }];
    WAIT
    
    AVUser *fetchedUser = [AVUser objectWithoutDataWithObjectId:user.objectId];
    NSError *error;
    [fetchedUser fetch:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(fetchedUser.username, username);
    XCTAssertEqualObjects(fetchedUser[@"nickName"], nickName);
}

- (void)testSaveInMutipleThreads {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd)];
    NSInteger taskN = 20;
    __block int32_t total = (int32_t)taskN;
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = taskN;
    for (NSInteger i = 0; i < taskN; i++) {
        NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
            user[@"nickName"] = [NSString stringWithFormat:@"%ud", arc4random()];
            [user saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                XCTAssertNil(error);
                if (OSAtomicDecrement32(&total) == 0) {
                    NOTIFY
                }
            }];
        }];
        [queue addOperation:operation];
    }
    WAIT
}

- (void)testSaveFailedForTwoTimes {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd)];
    [AVUser logOut];
    user[@"nickName"] = [NSString stringWithFormat:@"%ud", arc4random()];
    __block NSInteger callbackCount = 0;
    [user saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        callbackCount++;
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, kAVErrorUserCannotBeAlteredWithoutSession);
        user[@"nickName"] = [NSString stringWithFormat:@"%ud", arc4random()];
        [user saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            callbackCount++;
            XCTAssertNotNil(error);
            XCTAssertEqual(error.code, kAVErrorUserCannotBeAlteredWithoutSession);
            NOTIFY
        }];
    }];
    WAIT
    XCTAssertEqual(callbackCount, 2);
}

- (void)testPostDelete {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd)];
    NSError *error;
    [user delete:&error];
    XCTAssertNil(error);
    XCTAssertNil([AVUser currentUser]);
    XCTAssertNil([AVPaasClient sharedInstance].currentUser);
}

- (void)testPostDeleteWhenDeleteAll {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd)];
    AVObject *object = [AVObject objectWithClassName:@"TestObject"];
    NSError *error;
    [object save:&error];
    XCTAssertNil(error);
    [AVObject deleteAll:@[user, object] error:&error];
    XCTAssertNil(error);
    XCTAssertNil([AVUser currentUser]);
    XCTAssertNil([AVPaasClient sharedInstance].currentUser);
}

- (void)testPostDeleteWhenDeleteAllFailed {
    AVUser *user = [self registerOrLoginWithUsername:NSStringFromSelector(_cmd)];
    AVObject *object = [AVObject objectWithClassName:@"TestObject"];
    AVACL *acl = [AVACL ACL];
    // no one can read or write
    object.ACL = acl;
    NSError *error;
    [object save:&error];
    XCTAssertNil(error);
    [AVObject deleteAll:@[user, object] error:&error];
    XCTAssertNil(error);
    XCTAssertNil([AVUser currentUser]);
    XCTAssertNil([AVPaasClient sharedInstance].currentUser);
}

- (void)testSaveDescriptionKey {
    NSString * className = NSStringFromClass([self class]);
    NSError * error = nil;
    AVObject * object = [AVObject objectWithClassName:className];
    [object setObject:@"test" forKey:@"description"];
    [object save:&error];
    XCTAssertNil(error, @"%@", error);
    AVQuery* query = [AVQuery queryWithClassName:className];
    [query getObjectInBackgroundWithId:object.objectId block:^(AVObject *model, NSError *error) {
        XCTAssertNil(error, @"%@", error);
        XCTAssertEqualObjects([model objectForKey:@"description"], @"test");
        NOTIFY
    }];
    WAIT
}

- (void)testDispatchTwoSecondsLater {
    AVObject *object = [self objectForAVObjectTest];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        AVQuery *query = [AVQuery queryWithClassName:object.className];
        AVObject *queriedObject = [query getObjectWithId:object.objectId];
        assertNotNil(queriedObject);
        NOTIFY
    });
    WAIT
}

@end
