//
//  RESTClientTests.m
//  RESTClientTests
//
//  Created by Tang Tianyong on 16/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AVRESTClient.h"

@interface RESTClientTests : XCTestCase

@end

@implementation RESTClientTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testRequest {
    NSString *applicationId  = @"nq0awk3lh1dpmbkziz54377mryii8ny4xvp6njoygle5nlyg";
    NSString *applicationKey = @"6vdnmdkdi4fva9i06lt50s4mcsfhppjpzm3zf5zjc9ty4pdz";

    AVApplicationIdentity *identity = [[AVApplicationIdentity alloc] initWithID:applicationId key:applicationKey region:AVApplicationRegionCN];

    AVApplication *application = [[AVApplication alloc] initWithIdentity:identity configuration:nil];
    AVRESTClient *RESTClient = [[AVRESTClient alloc] initWithApplication:application configuration:nil];

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask *dataTask = [RESTClient sessionDataTaskWithMethod:@"GET"
                                                                  endpoint:@"date"
                                                                parameters:nil
                                              constructingRequestWithBlock:nil
                                                                   success:^(NSHTTPURLResponse *response, id responseObject) {
                                                                       XCTAssertEqualObjects(responseObject[@"__type"], @"Date");
                                                                       dispatch_semaphore_signal(semaphore);
                                                                   }
                                                                   failure:^(NSHTTPURLResponse *response, id responseObject, NSError *error) {
                                                                       XCTFail("Request failed.");
                                                                       dispatch_semaphore_signal(semaphore);
                                                                   }];
    [dataTask resume];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

@end
