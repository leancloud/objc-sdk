//
//  AVQueryBasic.m
//  AVOSDemo
//
//  Created by Travis on 13-12-12.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "AVQueryBasic.h"
//#import "AVObjectUtils.h"

@implementation AVQueryBasic

-(void)demoByClassNameQuery{
    AVQuery *query=[AVQuery queryWithClassName:@"Student"];
    
    //限制查询返回数
    [query setLimit:3];
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (objects) {
            [self log:[NSString stringWithFormat:@"查询结果: \n%@", [objects description]]];
        }else{
            [self log:[NSString stringWithFormat:@"查询出错: \n%@", [error description]]];
        }
    }];
}

-(void)demoByClassNameQuery2{
    AVObject* someObject = [AVObject objectWithClassName:@"SomeClass"];
    [someObject setObject:@"Mike" forKey:@"Title"];
    [someObject setObject:@"Mike" forKey:@"Origin"];
    [someObject setObject:@"Mike" forKey:@"Tag"];
    [someObject saveInBackgroundWithTarget:self selector:@selector(saveFinished::)];
    
    AVQuery *query = [AVQuery queryWithClassName:@"SomeClass"];
    query.cachePolicy = kPFCachePolicyCacheElseNetwork;
    query.maxCacheAge = 48 * 3600;
    query.limit = 10;
    [query orderByDescending:@"createdAt"];
    [query selectKeys:@[@"objectId", @"Title", @"Origin", @"Tag"]];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            NSLog(@"success!");
        }
        else
        {
            NSLog(@"%@",[error localizedDescription]);
        }
        [self log:[NSString stringWithFormat:@"查询结果: \n%@", [objects description]]];
    }];
////    然后进行Query：
//    AVQuery *query = [AVQuery queryWithClassName:@"SomeClass"];
//    NSArray* resultArray = [query findObjects];
//    if (resultArray) {
//        [self log:[NSString stringWithFormat:@"查询结果: \n%@", [resultArray description]]];
//    }
}

//-(void)demoByClassNameQuery3{
//    double old = 3E-312;
//    double new = [[NSString stringWithFormat:@"%.5lf",old]doubleValue];
//    printf("%lf\n", old);
//    NSNumber *num = [NSDecimalNumber decimalNumberWithString:@"4.439049394553e-312"];
//    NSLog(@"%@", num);
//    AVGeoPoint *point = [[AVGeoPoint alloc] init];
//    point.latitude = 3.112344E-324;
//    point.longitude = 3.11111E-400;
//    NSDictionary *dict = [AVObjectUtils dictionaryFromGeoPoint:point];
//    NSLog(@"%@", dict);
//    float a = 3.111E-312;
//    
//    AVObject* someObject = [AVObject objectWithClassName:@"SomeClass"];
//    [someObject setObject:@"Mike" forKey:@"name"];
//    [someObject setObject:@2 forKeyedSubscript:@"cid"];
//    [someObject saveInBackgroundWithTarget:self selector:@selector(saveFinished::)];
//    
//    //    然后进行Query：
//    AVQuery *query = [AVQuery queryWithClassName:@"SomeClass"];
//    [query whereKey:@"cid" equalTo:@2];
//
//    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
//        if (objects) {
//            [self log:[NSString stringWithFormat:@"查询结果: \n%@", [objects description]]];
//        }else{
//            [self log:[NSString stringWithFormat:@"查询出错: \n%@", [error description]]];
//        }
//    }];
//
//}

-(void)demoByGeoQuery{
    AVQuery *query=[AVQuery queryWithClassName:@"Student"];
    
    //我们要找这个点附近的Student
    AVGeoPoint *geo=[AVGeoPoint geoPointWithLatitude:31.9 longitude:114.78];
    
    [query whereKey:@"location" nearGeoPoint:geo];
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (objects) {
            [self log:[NSString stringWithFormat:@"查询结果: \n%@", [objects description]]];
        }else{
            [self log:[NSString stringWithFormat:@"查询出错: \n%@", [error description]]];
        }
    }];
}


-(void)demoOnlyGetQueryResultCount{
    AVQuery *query=[AVQuery queryWithClassName:@"Student"];
    
    [query countObjectsInBackgroundWithBlock:^(NSInteger number, NSError *error) {
        if (error==nil) {
            [self log:[NSString stringWithFormat:@"查询结果: \n%ld个Student", (long)number]];
        }else{
            [self log:[NSString stringWithFormat:@"查询出错: \n%@", [error description]]];
        }
    }];
}

-(void)saveFinished:(id)arg1 :(id)arg2 {
    
}
MakeSourcePath
@end
