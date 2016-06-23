//
//  AVHelpersTest.m
//  paas
//
//  Created by Travis on 13-12-17.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "AVTestBase.h"
#import "AVHelpers.h"
#import "AVPaasClient.h"
#import "AVUtils.h"
@interface AVHelpersTest : AVTestBase {
    __block int done;
}
@property (nonatomic,strong) NSMutableSet *aset;
@end

@implementation AVHelpersTest

-(void)testMD5{
    NSString *org=@"hello world";
    XCTAssertEqualObjects([org AVMD5String], @"5EB63BBBE01EEED093CB22BB8F5ACDC3", @"md5 methord error!");
}

-(void)threadOpt{
    NSString *msg=[AVUtils generateUUID];
    
    AVObject *obj=[AVObject objectWithClassName:NSStringFromClass([self class])];
    [obj setObject:msg forKey:@"msg"];
    
    [obj saveEventually:^(BOOL success, NSError *error) {
        @synchronized (self) {
        done--;
        }
        
        XCTAssertTrue(success, @"save fail:%@",error);
        
        NSLog(@"======= Saved %@",msg);
        
        AVQuery *q=[AVQuery queryWithClassName:NSStringFromClass([self class])];
        [q whereKey:@"msg" equalTo:msg];
        
        NSInteger count=[q countObjects];
        
        XCTAssert(count==1, @"save duplicate");
        
        [self addDeleteObject:obj];
        @synchronized (self) {
        if (done==0) {
            NOTIFY;
        }
        }
    }];
    
    
}

-(void)testHandldRequestTest{
    int count = 5;
    done = count;
    for (int i=0; i < count; i++) {
        [NSThread detachNewThreadSelector:@selector(threadOpt) toTarget:self withObject:nil];
    }
    
    WAIT_FOREVER
}


-(void)testNormalHandleReq{
    
    NSString *msg=[AVUtils generateUUID];
    
    AVObject *obj=[AVObject objectWithClassName:NSStringFromClass([self class])];
    [obj setObject:msg forKey:@"msg"];
    
    [obj saveEventually:^(BOOL success, NSError *error) {
        XCTAssertTrue(success, @"save fail:%@",error);
        
        NSLog(@"======= Saved %@",msg);
        
        AVQuery *q=[AVQuery queryWithClassName:NSStringFromClass([self class])];
        [q whereKey:@"msg" equalTo:msg];
        
        NSInteger count=[q countObjects];
        
        XCTAssert(count==1, @"save duplicate");
        [self addDeleteObject:obj];
        NOTIFY;
    }];
    
    WAIT
}
@end
