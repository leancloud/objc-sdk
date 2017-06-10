//
//  AVRelationTest.m
//  paas
//
//  Created by Travis on 13-11-8.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "AVTestBase.h"
#import "AVPaasClient.h"
#import "Armor.h"
#import "UserArmor.h"
#import "UserInfo.h"

@interface AVRelationTest : AVTestBase {
    
}

@end

@implementation AVRelationTest

-(void)testRelationCount{
    NSString * className = NSStringFromClass([self class]);
    NSError * error = nil;
    AVObject *object1 = [AVObject objectWithClassName:className];
    XCTAssertTrue([object1 save:&error], @"error %@", error);
    [self addDeleteObject:object1];
    
    AVObject *object2 = [AVObject objectWithClassName:className];
    AVRelation *relation = [object2 relationforKey:@"child"];
    [relation addObject:object1];
//    [object2 setObject:object1 forKey:@"child"];
    XCTAssertTrue([object2 save:&error], @"error %@", error);
    [self addDeleteObject:object2];
    
    AVObject *obj=[AVObject objectWithoutDataWithClassName:className objectId:object2.objectId];
    [obj fetchIfNeeded];
    
    AVRelation *postRel=[obj relationforKey:@"child"];
    AVQuery *q=[postRel query];
    
    NSUInteger count= [q countObjects];
   
    XCTAssertTrue(count>0,@"can't get count of like relation");
}

- (void)testRelationalSaveUruluShouldHaveError {
//    if (![[AVPaasClient sharedInstance] isUrulu]) return;
    NSString * className = NSStringFromClass([self class]);
    
    AVObject *post = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Post", className]];
    AVObject *person = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Person", className]];
    [person setObject:@"Summer" forKey:@"name"];
    [person save];
    [post setObject:person forKey:@"who"];
    
    NSError *error;
    XCTAssertTrue([post save:&error], @"should have no error here");
    [self addDeleteObject:post];
    [self addDeleteObject:person];
    post = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Post", className]];
    [post setObject:@"Summer" forKey:@"who"]; // this line is wrong
    
    XCTAssertFalse([post save:&error], @"should have error here");
    [self addDeleteObject:post];
}

- (void)testRelationalSaveUrulu {
//    if (![[AVPaasClient sharedInstance] isUrulu]) return;
    NSString * className = NSStringFromClass([self class]);

    AVObject *post = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Post", className]];
    AVObject *person = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Person", className]];
    [person setObject:@"Summer" forKey:@"name"];
    [post setObject:person forKey:@"who"];
    
    NSError *error;
//    XCTAssertTrue([person save:&error], @"error: %@", error);
    XCTAssertTrue([post save:&error], @"error: %@", error);
    XCTAssertTrue([person hasValidObjectId], @"object id error");
    [self addDeleteObject:post];
    [self addDeleteObject:person];
    AVQuery * query = [AVQuery queryWithClassName:post.className];
    [query includeKey:@"who"];
    [query whereKey:@"objectId" equalTo:post.objectId];
    AVObject * result = [query getFirstObject];
    XCTAssertTrue(result != nil, @"get object failed");
    
    AVObject * nestedObject = (AVObject *)[result objectForKey:@"who"];
    XCTAssertEqualObjects(nestedObject.objectId, person.objectId, @"string test failed");
    XCTAssertEqualObjects([nestedObject objectForKey:@"name"], @"Summer", @"string test failed");
}

- (void)testRelationalSaveUrulu2 {
//    if (![[AVPaasClient sharedInstance] isUrulu]) return;
    NSString * className = NSStringFromClass([self class]);

    AVObject *animal = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Animal", className]];
    [animal setObject:@"cat" forKey:@"name"];
    [self addDeleteObject:animal];
    
    AVObject *person = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Person", className]];
    [person setObject:@"Summer" forKey:@"name"];
    [person setObject:animal forKey:@"pet"];
    [self addDeleteObject:person];
    
    AVObject *post = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Post", className]];
    [post setObject:person forKey:@"who"];
    [post setObject:@"test tile" forKey:@"title"];
    [self addDeleteObject:post];
    
    NSError *error;
    XCTAssertTrue([post save:&error], @"error: %@", error);
    XCTAssertTrue([person hasValidObjectId], @"object id error");
    XCTAssertTrue([animal hasValidObjectId], @"object id error");
    
    AVQuery * query = [AVQuery queryWithClassName:post.className];
    [query includeKey:@"who"];
    [query whereKey:@"objectId" equalTo:post.objectId];
    AVObject * result = [query getFirstObject];
    XCTAssertTrue(result != nil, @"get object failed");
    XCTAssertEqualObjects([result objectForKey:@"title"], @"test tile", @"string test failed");

    AVObject * nestedObject = (AVObject *)[result objectForKey:@"who"];
    XCTAssertEqualObjects(nestedObject.objectId, person.objectId, @"string test failed");
    XCTAssertEqualObjects([nestedObject objectForKey:@"name"], @"Summer", @"string test failed");
    
    nestedObject = (AVObject *)[nestedObject objectForKey:@"pet"];
    XCTAssertEqualObjects(nestedObject.objectId, animal.objectId, @"string test failed");
//    XCTAssertEqualObjects([nestedObject objectForKey:@"name"], @"cat", @"string test failed");

}

- (void)testRelationalSaveUrulu3 {
//    if (![[AVPaasClient sharedInstance] isUrulu]) return;
    NSString * className = NSStringFromClass([self class]);
    
    AVObject *animal = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Animal", className]];
    [animal setObject:@"cat" forKey:@"name"];
    [animal setObject:[NSDate date] forKey:@"birthday"];
    
    AVObject *person = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Person", className]];
    [person setObject:@"Summer" forKey:@"name"];
    [person setObject:animal forKey:@"pet"];
    [person setObject:[NSDate date] forKey:@"birthday"];
    
    AVObject *post = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Post", className]];
    [post setObject:person forKey:@"who"];
    [post setObject:[AVGeoPoint geoPointWithLatitude:23.12 longitude:113.1] forKey:@"location"];
    
    NSError *error;
    XCTAssertTrue([post save:&error], @"error: %@", error);
    XCTAssertTrue([person hasValidObjectId], @"object id error");
    XCTAssertTrue([animal hasValidObjectId], @"object id error");
    
    [self addDeleteObject:animal];
    [self addDeleteObject:person];
    [self addDeleteObject:post];
    
    AVQuery * query = [AVQuery queryWithClassName:post.className];
    [query includeKey:@"who"];
    [query whereKey:@"objectId" equalTo:post.objectId];
    AVObject * result = [query getFirstObject];
    XCTAssertTrue(result != nil, @"get object failed");
    
    AVObject * nestedObject = (AVObject *)[result objectForKey:@"who"];
    XCTAssertEqualObjects(nestedObject.objectId, person.objectId, @"string test failed");
    XCTAssertEqualObjects([nestedObject objectForKey:@"name"], @"Summer", @"string test failed");
    
}

- (void)testRelationalSaveUrulu4 {
//    if (![[AVPaasClient sharedInstance] isUrulu]) return;
    NSString * className = NSStringFromClass([self class]);
    
    AVObject *animal = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Animal", className]];
    [animal setObject:@"cat" forKey:@"name"];
    [animal setObject:[NSDate date] forKey:@"birthday"];
    
    AVObject *person = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Person", className]];
    [person setObject:@"Summer" forKey:@"name"];
    [person setObject:animal forKey:@"pet"];
    [person setObject:[NSDate date] forKey:@"birthday"];
    
    AVObject *post = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Post", className]];
    [post setObject:person forKey:@"who"];
    [post setObject:[AVGeoPoint geoPointWithLatitude:23.12 longitude:113.1] forKey:@"location"];
    
    NSError *error;
    XCTAssertTrue([post save:&error], @"error: %@", error);
    XCTAssertTrue([person hasValidObjectId], @"object id error");
    XCTAssertTrue([animal hasValidObjectId], @"object id error");
    
    [self addDeleteObject:animal];
    [self addDeleteObject:person];
    [self addDeleteObject:post];
    
    AVQuery *query = [AVQuery queryWithClassName:[NSString stringWithFormat:@"%@_Post", className]];
    [query whereKey:@"objectId" equalTo:post.objectId];
    post = [query getFirstObject];
    person = [post objectForKey:@"who"];
    [person fetchIfNeeded];
    
    animal = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Animal", className]];
    [animal setObject:@"dog" forKey:@"name"];
    [animal setObject:[NSDate date] forKey:@"birthday"];
    
    [post setObject:[AVGeoPoint geoPointWithLatitude:23.12 longitude:113.1] forKey:@"location"];
    [post setObject:animal forKey:@"anotherWho"];
    
    XCTAssertTrue([post save:&error], @"%@", error);
    [self addDeleteObject:animal];
}


-(void)testReverseRelationQuery {
    NSString * className = NSStringFromClass([self class]);
    
//    AVObject *child = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Child", className]];
//    [child setObject:@(1) forKey:@"like"];
//    [child setObject:[NSDate date] forKey:@"birthday"];
//    
//    AVObject *parent = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Parent", className]];
//    [parent setObject:child forKey:@"child"];
//    [parent setObject:[NSDate date] forKey:@"birthday"];
//    
//    NSError *error;
//    XCTAssertTrue([parent save:&error], @"error: %@", error);
//    XCTAssertTrue([child hasValidObjectId], @"object id error");
    
    AVObject *parent = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Parent", className]];
    [parent setObject:[NSDate date] forKey:@"birthday"];
    AVRelation * relation = [parent relationforKey:@"child"];
    AVObject *child = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Child", className]];
    [child setObject:@(1) forKey:@"like"];
    [child setObject:[NSDate date] forKey:@"birthday"];
    XCTAssertTrue([child save], @"save failed");
    [relation addObject:child];
    XCTAssertTrue([parent save], @"save failed");
    [self addDeleteObject:child];
    [self addDeleteObject:parent];
    
    AVQuery * query = [AVRelation reverseQuery:parent.className relationKey:@"child" childObject:child];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertTrue(error == nil, @"find error %@", error);
        XCTAssertTrue(objects.count > 0, @"object is empty");
        AVObject * result = [objects objectAtIndex:0];
        XCTAssertTrue([result.objectId isEqualToString:parent.objectId], @"not matched");
        NOTIFY
    }];
    WAIT
}

-(void)testReverseRelationUserQuery {
    NSString * className = NSStringFromClass([self class]);
    NSString *username = NSStringFromSelector(_cmd);
    AVUser *user = [AVUser user];
    user.username = [NSString stringWithFormat:@"%@", username];
    user.password = @"123456";
    [user signUp];
    [self addDeleteObject:user];
    
    AVRelation * relation = [user relationforKey:@"myLikes"];
    AVObject * post = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Post", className]];
    [post setObject:@"article content" forKey:@"content"];
    [post save];
    [relation addObject:post];
    [user save];
    
    [self addDeleteObject:post];
    
    AVQuery * query = [AVRelation reverseQuery:user.className relationKey:@"myLikes" childObject:post];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        // get user list
        XCTAssertTrue(objects.count > 0, @"objects count should larger than 0");
        XCTAssertTrue(error == nil, @"erorr %@", error);
        NOTIFY
    }];
    
    WAIT
}

-(void)testReverseRelationQuery2 {
    NSString * className = NSStringFromClass([self class]);
    
    AVObject *child = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Child", className]];
    [child setObject:@(100) forKey:@"like"];
    [child save];

    [self addDeleteObject:child];
    const int max = 10;
    for(int i = 0; i < max; ++i) {
        AVObject * parent = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Parent", className]];
        [parent setObject:@(i) forKey:@"myValue"];
        AVRelation * relation = [parent relationforKey:@"child"];
        [relation addObject:child];
        XCTAssertTrue([parent save], @"save failed");
        [self addDeleteObject:parent];
    }
    
    AVQuery * query = [AVRelation reverseQuery:[NSString stringWithFormat:@"%@_Parent", className] relationKey:@"child" childObject:child];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertTrue(error == nil, @"find error %@", error);
        XCTAssertTrue(objects.count  == max, @"object not matched");
        NOTIFY
    }];
    WAIT
}

// sub class
-(void)testReverseRelationQuery3 {
    [Armor registerSubclass];
    [UserInfo registerSubclass];
    [UserArmor registerSubclass];
    
    NSError *error;
    
    Armor *shield = [Armor object];
    shield.displayName = @"Wooden Shield";
    
    AVRelation * relation = [shield relationforKey:@"relation"];
    UserInfo * info = [UserInfo object];
    info.company = @"test";
    XCTAssertTrue([info save:&error], @"save failed %@", error);
    [relation addObject:info];
    XCTAssertTrue([shield save:&error], @"%@", error);
    
    [self addDeleteObject:info];
    [self addDeleteObject:shield];
    
    AVQuery * query = [AVRelation reverseQuery:shield.className relationKey:@"relation" childObject:info];

    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertTrue(objects.count > 0, @"error %@", error);
        AVObject * first = [objects objectAtIndex:0];
        XCTAssertTrue([first isKindOfClass:[Armor class]], @"object type error");
        NOTIFY;
    }];
    WAIT;
    
}


-(void)testRelationWithErrorObjectId {
    NSString * className = NSStringFromClass([self class]);
    
    AVObject *child = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Child", className]];
    AVObject * parent = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_Parent", className]];
    AVRelation * relation = [parent relationforKey:@"child"];
    XCTAssertThrows([relation addObject:child], @"should raise exception when adding object without objectId to relation");
}

- (void)testRelationalQuery {
    NSError *error = nil;
    NSString * className = NSStringFromClass([self class]);
    
    AVObject *a = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_A", className]];
    [a setObject:@"a" forKey:@"a"];
    [a setObject:@"b" forKey:@"b"];
    
    AVObject *b = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_B", className]];
    [b setObject:a forKey:@"c"];
    [b setObject:@"d" forKey:@"d"];
    [b save:&error];
    XCTAssertNil(error, @"%@", error);
    
    AVObject *c = [AVObject objectWithClassName:[NSString stringWithFormat:@"%@_C", className]];
    [c setObject:@"e" forKey:@"e"];
    AVRelation *relation = [c relationforKey:@"f"];
    [relation addObject:b];
    [c save:&error];
    XCTAssertNil(error, @"%@", error);

    AVQuery *query = [relation query];
    [query includeKey:@"c"];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        XCTAssertNil(error, @"%@", error);
        NSLog(@"%@", objects);
        AVObject *rb = [objects objectAtIndex:0];
        XCTAssertNotNil(rb, @"%@", @"result b should not nil");
        if (rb) {
            [rb fetchInBackgroundWithKeys:@[@"c"] block:^(AVObject *object, NSError *error) {
                XCTAssertNil(error, @"%@", error);
                AVObject *ra = [object objectForKey:@"c"];
                XCTAssertNotNil(ra, @"%@", @"result a should not nil");
                NSLog(@"%@", ra);
                NOTIFY;
            }];
        } else {
            NOTIFY;
        }
    }];
    WAIT;
    
    [query countObjectsInBackgroundWithBlock:^(NSInteger number, NSError *error) {
        XCTAssertGreaterThan(number, 0);
        NSLog(@"%ld", (long)number);
        NOTIFY;
    }];
    WAIT;
    [self addDeleteObject:a];
    [self addDeleteObject:b];
    [self addDeleteObject:c];
}

- (void)testArrayRelation {
    AVObject *scimitar = [AVObject objectWithClassName:@"Relation_Weapon"];
    [scimitar setObject:@"scimitar" forKey:@"name"];
    [scimitar save];
    AVObject *plasmaRifle = [AVObject objectWithClassName:@"Relation_Weapon"];
    [plasmaRifle setObject:@"plasmaRifle" forKey:@"name"];
    [plasmaRifle save];
    AVObject *grenade = [AVObject objectWithClassName:@"Relation_Weapon"];
    [grenade setObject:@"grenade" forKey:@"name"];
    [grenade save];
    AVObject *bunnyRabbit = [AVObject objectWithClassName:@"Relation_Weapon"];
    [bunnyRabbit setObject:@"bunnyRabbit" forKey:@"name"];
    [bunnyRabbit save];
    
    // stick the objects in an array
    NSArray *weapons = @[scimitar, plasmaRifle, grenade, bunnyRabbit];
    
    // store the weapons for the user
    AVObject *package = [AVObject objectWithClassName:@"Relation_Package"];
    [package setObject:weapons forKey:@"weaponsList"];
    [package saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        // set up our query for a User object
        AVQuery *packageQuery = [AVQuery queryWithClassName:@"Relation_Package"];
        
        // configure any constraints on your query...
        // for example, you may want users who are also playing with or against you
        
        // tell the query to fetch all of the Weapon objects along with the user
        // get the "many" at the same time that you're getting the "one"
        [packageQuery includeKey:@"weaponsList"];
        [packageQuery whereKey:@"weaponsList" equalTo:scimitar];
        // execute the query
        [packageQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
            // objects contains all of the User objects, and their associated Weapon objects, too
            NSLog(@"%@", objects);
            NOTIFY;
        }];
    }];
    WAIT;
}

//FIXME:Test Fails
// 测试 {"__type":"Relation","className":"_User"}
- (void)testParseRelation {
    NSDictionary *dict = [self jsonWithFileName:@"TestRelation"];
    XCTAssertNotNil(dict);
    AVObject * object = [AVObjectUtils avObjectForClass:@"AddRequest"];
    [AVObjectUtils copyDictionary:dict toObject:object];
    AVUser *fromUser = object[@"fromUser"];
    NSArray *friends = fromUser.relationData[@"friends"];
    XCTAssertEqual(friends.count, 1);
}

- (void)testRedirectClassNameForKey {
    NSString * className = NSStringFromClass([self class]);
    NSError * error = nil;
    AVObject *child = [AVObject objectWithClassName:className];
    XCTAssertTrue([child save:&error], @"error %@", error);
    
    AVObject *parent = [AVObject objectWithClassName:@"AVRelationTest_A"];
    AVRelation *relation = [parent relationforKey:@"child"];
    [relation addObject:child];
    XCTAssertTrue([parent save:&error], @"error %@", error);
    
    relation.targetClass = nil;
    
    AVQuery *query = [relation query];
    query.cachePolicy = kAVCachePolicyNetworkOnly;
    NSArray *objects = [query findObjects];
    XCTAssertEqual(objects.count, 1);
    AVObject *relationChild = objects[0];
    XCTAssertEqualObjects(relationChild.objectId, child.objectId);
    
    query.cachePolicy = kAVCachePolicyCacheOnly;
    NSArray *cacheObjects = [query findObjects];
    XCTAssertEqual(cacheObjects.count, 1);
    AVObject *cacheChild = cacheObjects[0];
    XCTAssertEqualObjects(relationChild.objectId, child.objectId);
    
    [self addDeleteObject:child];
    [self addDeleteObject:parent];
}

@end
