//
//  AVSubclassTest.m
//  paas
//
//  Created by Travis on 13-12-18.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "AVTestBase.h"

#import "AVSubclassing.h"
#import "AVObjectUtils.h"
#import "Armor.h"
#import "AVObjectUtils.h"
#import "AVObject_Internal.h"


//@interface Armor : AVObject<AVSubclassing>
//
//@property (retain) NSString *displayName;
//@property TypeEnum type;
//
//@property(nonatomic) AVObject *seller;
//
//@end
//
//@implementation Armor
//
//@dynamic displayName,type,seller;
//
//@end


@interface AVTest : AVObject<AVSubclassing>
@property (nonatomic,strong) NSString * tagName;
+ (NSString *)parseClassName;
@end

@implementation AVTest
@dynamic tagName;
+(NSString*)parseClassName {
    return @"TestObject";
}
@end

@interface AVSubclassTest : AVTestBase

@end

@implementation AVSubclassTest
+(void)setUp{
    [super setUp];
    [Armor registerSubclass];
    AVUser *user = [AVUser user];
    user.username = @"travis";
    user.password = @"123456";
    [user signUp];
    [self addDeleteObject:user];
}

-(void)testNullProperty{
    Armor *a=[Armor object];
    a.displayName=@"Tester1";
    a.type=Type2;
    
    NSMutableDictionary *dict=[AVObjectUtils objectSnapshot:a];
    [dict setObject:[NSNull null] forKey:@"seller"];
    
    Armor *b=(id)[AVObjectUtils objectFromDictionary:dict];
    XCTAssertNil(b.seller, @"Null Value");
    NSError *err = nil;
    [b save:&err];
    XCTAssertNil(err, @"should have no error");
    XCTAssertNil(b.seller, @"Null Value");
}

-(void)testEnumProperty{
    Armor *a=[Armor object];
    a.displayName=@"Tester1";
    a.type=Type2;
    
    NSError *err=nil;
    XCTAssertTrue([a save:&err], @"Cant save:%@",[err description]);
    [self addDeleteObject:a];
    Armor *b=[Armor objectWithoutDataWithObjectId:a.objectId];
    
    XCTAssertTrue([b fetch:&err], @"Cant save:%@",[err description]);
    XCTAssertEqual(b.type, a.type, @"Enum Save fail!");
    XCTAssertEqualObjects(b.displayName, a.displayName, @"Enum Save fail!");
}

-(void)testTestObject{
    [AVTest registerSubclass];
    NSError *err = nil;
    AVTest * test = [AVTest object];
    test.tagName = @"tagname";
    [test save:&err];
    XCTAssertNil(err, @"%@", err);
    [self addDeleteObject:test];
    
    AVTest *b=[AVTest objectWithoutDataWithObjectId:test.objectId];
    XCTAssertTrue([b fetch:&err], @"Cant fetch:%@",[err description]);

    XCTAssertEqualObjects([b className], [test className], @"AVUser子类返回错误");
    XCTAssertEqualObjects(test.tagName, b.tagName, @"tagName should equal");
}


- (void)testSubclassBooleanType {
    Armor *armor = [Armor object];
    armor.fireproof = YES;
    id object = [armor objectForKey:@"fireproof"];
    XCTAssertEqualObjects(NSStringFromClass([object class]), @"__NSCFBoolean");
}

- (void)testSubclassBooleanTypeByQuery {
    Armor *armor = [Armor object];
    armor.fireproof = YES;
    XCTAssertTrue([armor save]);
    
    AVQuery *q = [Armor query];
    [q whereKey:@"fireproof" equalTo:@YES];
    [q orderByDescending:@"createdAt"];
    AVObject *armor2 = [q getFirstObject];
    XCTAssertNotNil(armor2);
    XCTAssertEqualObjects(armor2.objectId, armor.objectId);
    
    [self addDeleteObject:armor];
}

- (void)testSubclassUserFieldClass {
    // https://ticket.leancloud.cn/tickets/8322
    
    [self deleteUserWithUsername:NSStringFromSelector(_cmd) password:@"123456"];
    [Armor registerSubclass];
    [UserBar registerSubclass];
    UserBar *userBar = [UserBar user];
    userBar.username = NSStringFromSelector(_cmd);
    userBar.password = @"123456";
    NSError *error;
    [userBar signUp:&error];
    XCTAssertNil(error);
    
    Armor *armor = [Armor object];
    armor.userBar = userBar;
    [armor save:&error];
    XCTAssertNil(error);
    NSDictionary *dict = [armor dictionaryForObject];
   
    Armor *armor2 = [Armor object];
    [armor2 objectFromDictionary:dict];
    XCTAssertEqual([armor2.userBar class], [UserBar class]);
}

@end
