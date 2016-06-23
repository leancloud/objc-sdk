//
//  LCBaseController.m
//  LCChatApp
//
//  Created by Qihe Bian on 11/20/14.
//  Copyright (c) 2014 Lean Cloud Inc. All rights reserved.
//

#import "LCBaseController.h"

@interface LCBaseController ()

@end

@implementation LCBaseController

- (void)loadView {
    CGRect rect;
    [super loadView];
    rect = self.view.frame;
    UIScrollView *view = [[UIScrollView alloc] initWithFrame:rect];
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
