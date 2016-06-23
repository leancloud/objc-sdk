//
//  FirstViewController.m
//  AnalyticsTest
//
//  Created by lzw on 15/11/10.
//  Copyright © 2015年 LeanCloud. All rights reserved.
//

#import "FirstViewController.h"

@interface FirstViewController ()

@property (weak, nonatomic) IBOutlet UILabel *dynamicLabel;

@end

@implementation FirstViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [AVAnalytics setCustomInfo:@{@"userId": @"1234"}];
    // 需要在 Info.plist 中加上字段 NSLocationWhenInUseUsageDescription
    // 请在真机上测试
    [AVGeoPoint geoPointForCurrentLocationInBackground:^(AVGeoPoint *geoPoint, NSError *error) {
        if (!error) {
            [AVAnalytics setLatitude:geoPoint.latitude longitude:geoPoint.longitude];
        }
    }];

#ifdef DEBUG
    // 默认统计开启，可在调试的时候关闭
    // [AVAnalytics setAnalyticsEnabled:NO];
    
    // Default is "App Store"
    [AVAnalytics setChannel:@"Debug"];
#endif
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)simpleEvent:(id)sender {
    [AVAnalytics event:@"简单事件"];
}

- (IBAction)startEvent:(id)sender {
    [AVAnalytics beginEvent:@"录制"];
}

- (IBAction)endEvent:(id)sender {
    [AVAnalytics endEvent:@"录制"];
}

- (IBAction)buyEvent:(id)sender {
    [AVAnalytics event:@"购买" label:@"送货上门"];
}

- (IBAction)playVideoEvent:(id)sender {
    [AVAnalytics event:@"播放视频"];
}

- (IBAction)useEventAcc:(id)sender {
    [AVAnalytics event:@"设定次数" label:nil acc:10];
}

- (IBAction)useCustomAttributes:(id)sender {
    [AVAnalytics event:@"自定义属性" attributes:@{@"城市": @"广州"}];
}

- (IBAction)useEventDuraion:(id)sender {
    NSTimeInterval duraions = 10 * 1000; // 自己统计的时长
    [AVAnalytics event:@"播放音乐" durations:duraions];
}

- (IBAction)crash:(id)sender {
    [self performSelector:@selector(doSomething:) withObject:nil];
}
@end
