//
//  SecondViewController.m
//  AnalyticsTest
//
//  Created by lzw on 15/11/10.
//  Copyright © 2015年 LeanCloud. All rights reserved.
//

#import "SecondViewController.h"

@interface SecondViewController ()

@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *backgroundColor = [AVAnalytics getConfigParams:@"background_color"];
    if ([[UIColor class] respondsToSelector:NSSelectorFromString(backgroundColor)]) {
        self.view.backgroundColor = [[UIColor class] performSelector:NSSelectorFromString(backgroundColor)];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
