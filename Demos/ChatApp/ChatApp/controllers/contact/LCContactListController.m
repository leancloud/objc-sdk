//
//  LCContactListController.m
//  ChatApp
//
//  Created by Qihe Bian on 12/24/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCContactListController.h"
#import "LCUser.h"
#import "SVPullToRefresh.h"
#import "LCContactCell.h"
#import "LCContactDetailController.h"

static NSString *cellIdentifier = @"ContactCell";

@interface LCContactListController () {
    uint32_t _loadedCount;
    uint32_t _pageCount;
    BOOL _refresh;
}
@property (nonatomic, strong) NSMutableArray *users;
@end

@implementation LCContactListController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"联系人";
        self.tabBarItem.image = [UIImage imageNamed:@"contact"];
        _users = [[NSMutableArray alloc] init];
        _loadedCount = 0;
        _pageCount = 20;
        _refresh = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    __weak LCContactListController *weakSelf = self;
    
    // setup pull-to-refresh
    [self.tableView addPullToRefreshWithActionHandler:^{
        [weakSelf refresh];
    }];
    
    // setup infinite scrolling
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        [weakSelf loadMore];
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tableView triggerPullToRefresh];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadMore {
    [self fetchUserList:^(BOOL succeeded, NSError *error) {
        [self.tableView.infiniteScrollingView stopAnimating];
    }];
}

- (void)refresh {
    _refresh = YES;
    _loadedCount = 0;
    [self fetchUserList:^(BOOL succeeded, NSError *error) {
        [self.tableView.pullToRefreshView stopAnimating];
    }];
}

- (void)fetchUserList:(AVBooleanResultBlock)callback {
    [LCUser queryUsersSkip:_loadedCount limit:_pageCount callback:^(NSArray *objects, NSError *error) {
        BOOL needRefresh = _refresh;
        _refresh = NO;
        if (objects) {
            if (needRefresh) {
                [_users removeAllObjects];
            }
            for (LCUser *user in objects) {
                if (![user isEqual:[LCUser currentUser]]) {
                    [_users addObject:user];
                }
            }
            _loadedCount += _pageCount;
            [self.tableView reloadData];
            callback(YES, nil);
        } else {
            NSLog(@"error:%@", error);
            callback(NO, error);
        }
    }];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kLCContactCellHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.users.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[LCContactCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    LCContactCell *contactCell = (LCContactCell *)cell;
    LCUser *user = [self.users objectAtIndex:indexPath.row];
    contactCell.nameLabel.text = user.nickname;
    [contactCell.headView sd_setImageWithURL:[NSURL URLWithString:user.photoUrl] placeholderImage:[UIImage imageNamed:@"head_default.png"]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    LCUser *user = [self.users objectAtIndex:indexPath.row];
    LCContactDetailController *controller = [[LCContactDetailController alloc] initWithUser:user];
    [self.navigationController pushViewController:controller animated:YES];
}


@end
