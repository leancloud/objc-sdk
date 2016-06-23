//
//  TestAVSearchSortBuilder.m
//  paas
//
//  Created by yang chaozhong on 6/13/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "AVTestBase.h"
#import "AVPaasClient.h"
#import "AVSearchSortBuilder.h"
#import "AVGeoPoint.h"

@interface AVSearchSortBuilderTest : AVTestBase

@end

@implementation AVSearchSortBuilderTest

- (void)testSortBuilder
{
    AVSearchSortBuilder *sortBuilder = [AVSearchSortBuilder newBuilder];
    [sortBuilder orderByAscending:@"key1"];
    [sortBuilder orderByAscending:@"key2" withMode:@"sum"];
    [sortBuilder orderByAscending:@"key3" withMode:@"avg" andMissing:@"first"];
    [sortBuilder whereNear:@"location" point:[AVGeoPoint geoPointWithLatitude:45.0f longitude:60.0f]];
    
    NSArray *fields = sortBuilder.sortFields;
    NSLog(@"%@", fields);
}

@end
