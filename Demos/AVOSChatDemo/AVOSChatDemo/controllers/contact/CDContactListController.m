//
//  CDContactListController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/27/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDContactListController.h"
#import "CDCommon.h"
#import "CDContactDetailController.h"

enum : NSUInteger {
    kTagNameLabel = 10000,
};
@interface CDContactListController ()
@property (nonatomic, strong) NSMutableArray *users;
@end

@implementation CDContactListController
- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"联系人";
        self.tabBarItem.image = [UIImage imageNamed:@"contact"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self startFetchUserList];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)startFetchUserList {
    AVQuery * query = [AVUser query];
    query.cachePolicy = kAVCachePolicyIgnoreCache;
//    
//    //设置缓存有效期
//    query.maxCacheAge = 4 * 3600;
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (objects) {
            NSMutableArray *users = [NSMutableArray array];
            for (AVUser *user in objects) {
                if (![user isEqual:[AVUser currentUser]]) {
                    [users addObject:user];
                }
            }
            self.users = users;
            [self.tableView reloadData];
        } else {
            NSLog(@"error:%@", error);
        }
    }];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 40;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.users.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"ContactCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 100, 30)];
        label.font = [UIFont systemFontOfSize:14];
        label.tag = kTagNameLabel;
        label.textColor = [UIColor redColor];
        [cell.contentView addSubview:label];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    AVUser *user = [self.users objectAtIndex:indexPath.row];
    UILabel *label = (UILabel *)[cell.contentView viewWithTag:kTagNameLabel];
    label.text = user.username;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AVUser *user = [self.users objectAtIndex:indexPath.row];
    CDContactDetailController *controller = [[CDContactDetailController alloc] initWithUser:user];
    [self.navigationController pushViewController:controller animated:YES];
}
@end
