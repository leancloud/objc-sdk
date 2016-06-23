//
//  LCMemberListController.m
//  ChatApp
//
//  Created by Qihe Bian on 1/6/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCMemberListController.h"
#import "LCUser.h"
#import "SVPullToRefresh.h"
#import "LCContactCell.h"
#import "LCContactDetailController.h"
#import "MBProgressHUD.h"
#import "LCMultiSelectController.h"
#import "LCBaseNavigationController.h"
#import "LCCommon.h"
#import "LCIMClient.h"

static NSString *cellIdentifier = @"ContactCell";

@interface LCMemberListController () <LCMultiSelectControllerDelegate>{
//    uint32_t _loadedCount;
//    uint32_t _pageCount;
//    BOOL _refresh;
}
@property (nonatomic, strong) NSMutableArray *users;
@end

@implementation LCMemberListController

- (instancetype)init {
    if ((self = [super init])) {
        _users = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(invite:)];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    __weak LCMemberListController *weakSelf = self;
    
//    // setup pull-to-refresh
    [self.tableView addPullToRefreshWithActionHandler:^{
        [weakSelf refresh];
    }];
//
//    // setup infinite scrolling
//    [self.tableView addInfiniteScrollingWithActionHandler:^{
//        [weakSelf loadMore];
//    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tableView triggerPullToRefresh];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//- (void)loadMore {
//    [self fetchUserList:^(BOOL succeeded, NSError *error) {
//        [self.tableView.infiniteScrollingView stopAnimating];
//    }];
//}

- (void)refresh {
    [self fetchMembersInfo:^(BOOL succeeded, NSError *error) {
        [self.tableView.pullToRefreshView stopAnimating];
    }];
}

- (void)fetchMembersInfo:(AVBooleanResultBlock)callback {
    [LCUser queryUserWithIds:self.conversation.members callback:^(NSArray *objects, NSError *error) {
        if (objects) {
            [_users removeAllObjects];
            for (LCUser *user in objects) {
                [_users addObject:user];
            }
            [self.tableView reloadData];
            callback(YES, nil);
        } else {
            NSLog(@"error:%@", error);
            callback(NO, error);
        }
    }];
}

- (void)fetchUserList:(AVArrayResultBlock)callback {
    [LCUser queryUsersSkip:0 limit:1000 callback:^(NSArray *objects, NSError *error) {
        if (objects) {
            callback(objects, nil);
        } else {
            NSLog(@"error:%@", error);
            callback(nil, error);
        }
    }];
}

- (void)invite:(id)sender {
    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
    [self.navigationController.view addSubview:hud];
    hud.labelText = @"正在获取联系人列表";
    // Regiser for HUD callbacks so we can remove it from the window at the right time
    //    hud.delegate = self;
    [hud show:YES];
    
    [self fetchUserList:^(NSArray *objects, NSError *error) {
        if (!error) {
            [hud hide:YES];
            LCMultiSelectController *controller = [[LCMultiSelectController alloc] init];
            NSMutableArray *users = [objects mutableCopy];
            [users removeObjectsInArray:self.users];
            NSMutableArray *items = [[NSMutableArray alloc] init];
            for (LCUser *user in users) {
                if (![user isEqual:[LCUser currentUser]]) {
                    LCMultiSelectItem *item = [[LCMultiSelectItem alloc] init];
                    item.userId = user.objectId;
                    item.name = user.nickname;
                    item.imageURL = [NSURL URLWithString:user.photoUrl];
                    item.disabled = NO;
                    item.selected = NO;
                    [items addObject:item];
                }
            }
            controller.items = items;
            controller.delegate = self;
            LCBaseNavigationController *nav = [[LCBaseNavigationController alloc] initWithRootViewController:controller];
            [self presentViewController:nav animated:YES completion:^{
                
            }];
        } else {
            hud.labelText = @"获取联系人列表失败";
            [hud hide:YES afterDelay:1];
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

- (void)multiSelectController:(LCMultiSelectController *)controller didSelectItems:(NSArray *)items {
    NSMutableArray *userIds = [[NSMutableArray alloc] init];
    for (LCMultiSelectItem *item in items) {
        [userIds addObject:item.userId];
    }
    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
    [self.navigationController.view addSubview:hud];
    hud.labelText = @"正在添加成员";
    // Regiser for HUD callbacks so we can remove it from the window at the right time
    //    hud.delegate = self;
    [hud show:YES];
    [[LCIMClient sharedInstance] addUserIds:userIds toConversation:self.conversation callback:^(BOOL succeeded, NSError *error) {
        if (!error) {
            [self refresh];
            [hud hide:YES];
        } else {
            hud.labelText = @"添加成员失败";
            [hud hide:YES afterDelay:1];
        }
    }];
}
@end
