//
//  AVSearchQueryTest.m
//  paas
//
//  Created by yang chaozhong on 5/30/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "AVTestBase.h"
#import "AVSearchSortBuilder.h"

@interface AVSearchQueryTest : AVTestBase

@end

@implementation AVSearchQueryTest


-(NSString *) randomStringWithLength: (int) len {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform((int)[letters length]) % [letters length]]];
    }
    
    return randomString;
}

- (void)testSearch
{
    NSString * className = NSStringFromClass([self class]);
    NSError * error = nil;
    int max = 100;
    NSDate *firstDate = nil;
    NSDate *lastDate = nil;
    int maxkey1 = 0;
    int minKey1 = 100;
    int m = 3;
    int n = 3;
    for(int i = 0; i < max; ++i) {
        AVObject * object = [AVObject objectWithClassName:className];
        [object setObject:@((i + 3) % max) forKey:@"score"];
        if (i == 0) {
            firstDate = object.createdAt;
        } else if (i == max - 1) {
            lastDate = object.createdAt;
        }
        int k = arc4random() % 30;
        if (k == 0) {
            [object setObject:@"yyy" forKey:@"name"];
        } else if (k == 1) {
            [object setObject:@"xxxyyy" forKey:@"name"];
        } else if (k == 2) {
            [object setObject:@"aaabbba" forKey:@"name"];
        } else {
            int l = arc4random() % 8 + 7;
            NSString *s = [self randomStringWithLength:l];
            [object setObject:s forKey:@"name"];
        }
        k = arc4random() % 30;
        if (k == 0) {
            [object setObject:@"yyy" forKey:@"content"];
        } else if (k == 1) {
            [object setObject:@"assddd" forKey:@"content"];
        } else {
            int l = arc4random() % 8 + 7;
            NSString *s = [self randomStringWithLength:l];
            [object setObject:s forKey:@"content"];

        }
        k = arc4random() % n;
        if (k < m) {
            int v = arc4random() % 100;
            [object setObject:@(v) forKey:@"key1"];
            if (v > maxkey1) {
                maxkey1 = v;
            }
            if (v < minKey1) {
                minKey1 = v;
            }
        }
        k = arc4random() % n;
        if (k < m) {
            int v = arc4random() % 100;
            [object setObject:@(v) forKey:@"key2"];
        }
        k = arc4random() % n;
        if (k < m) {
            int v = arc4random() % 100;
            [object setObject:@(v) forKey:@"key3"];
        }
        k = arc4random() % n;
        if (k < m) {
            int lat = (arc4random() % 180) - 90;
            int lon = (arc4random() % 360) - 180;
            [object setObject:[AVGeoPoint geoPointWithLatitude:lat longitude:lon] forKey:@"location"];
        }

        if (i == 6) {
            [object setObject:@"xxxyyy" forKey:@"name"];
            [object setObject:@"yyy" forKey:@"content"];
        }
        XCTAssertTrue([object save:&error], @"error %@", error);
        [self addDeleteObject:object];
    }
    
    AVSearchQuery *searchQuery = [AVSearchQuery searchWithQueryString:@"*y*"];
    searchQuery.className =className;
    searchQuery.highlights = @"content,name";
    searchQuery.limit = 10;
    searchQuery.cachePolicy = kAVCachePolicyCacheElseNetwork;
    searchQuery.maxCacheAge = 60;
    searchQuery.fields = @[@"content", @"name"];
    
    AVSearchSortBuilder *sortBuilder = [AVSearchSortBuilder newBuilder];
    [sortBuilder orderByAscending:@"key1"];
    [sortBuilder orderByAscending:@"key2" withMode:@"sum"];
    [sortBuilder orderByAscending:@"key3" withMode:@"avg" andMissing:@"first"];
    [sortBuilder whereNear:@"location" point:[AVGeoPoint geoPointWithLatitude:45.0f longitude:60.0f]];
    
    searchQuery.sortBuilder = sortBuilder;
    
    [searchQuery addDescendingOrder:@"content"];
    
    NSArray *objects = [searchQuery findObjects];
    
    NSLog(@"%@", objects);
    for (AVObject *obj in objects) {
        AVGeoPoint *p = [obj objectForKey:@"location"];
        NSLog(@"name:%@ content:%@ key1:%@ key2:%@ key3:%@ location:(lat:%f,lon:%f)", [obj objectForKey:@"name"], [obj objectForKey:@"content"], [obj objectForKey:@"key1"], [obj objectForKey:@"key2"], [obj objectForKey:@"key3"], p.latitude, p.longitude);
    }
    XCTAssertTrue(objects.count > 0, @"result objects count should larger than 0");
    XCTAssertTrue(maxkey1 >= [[[objects lastObject] objectForKey:@"key1"] intValue], @"last object key1 should be the largest one");
    XCTAssertTrue(minKey1 <= [[[objects firstObject] objectForKey:@"key1"] intValue], @"last object key1 should be the largest one");
}

@end
