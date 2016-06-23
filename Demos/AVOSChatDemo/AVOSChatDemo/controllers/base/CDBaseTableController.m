//
//  CDBaseTableController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/24/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDBaseTableController.h"

@interface CDBaseTableController ()

@end

@implementation CDBaseTableController
- (void)loadView {
    [super loadView];
    if ([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)]) {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:tableView];
    self.tableView = tableView;
}

- (UITableView *)tableView {
    if (!_tableView) {
        [self loadView];
    }
    return  _tableView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)]) {
        // For insetting with a navigation bar
        CGRect rect = self.navigationController.navigationBar.frame;
        UIEdgeInsets insets = UIEdgeInsetsMake(CGRectGetMaxY(rect), 0, CGRectGetHeight(self.tabBarController.tabBar.bounds), 0);
        self.tableView.contentInset = insets;
        self.tableView.scrollIndicatorInsets = insets;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}


@end
