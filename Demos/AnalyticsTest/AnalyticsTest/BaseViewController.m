//
//  BaseViewController.m
//  AnalyticsTest
//
//  Created by lzw on 15/11/10.
//  Copyright © 2015年 LeanCloud. All rights reserved.
//

#import "BaseViewController.h"

@interface BaseViewController ()

@end

@implementation BaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [AVAnalytics beginLogPageView:NSStringFromClass([self class])];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [AVAnalytics endLogPageView:NSStringFromClass([self class])];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
