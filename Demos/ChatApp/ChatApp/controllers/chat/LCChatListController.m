//
//  LCChatListController.m
//  ChatApp
//
//  Created by Qihe Bian on 12/10/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCChatListController.h"
#import "LCIMClient.h"
#import "LCConversationCell.h"
#import "LCUser.h"
#import "LCChatController.h"
#import "SVPullToRefresh.h"
#import "LCPopMenu.h"
#import "ZXingWidgetController.h"
#import "MultiFormatReader.h"
//#import "CDSideBarController.h"
#import "LCMultiSelectController.h"
#import "LCBaseNavigationController.h"
#import "MBProgressHUD.h"

static NSString *cellIdentifier = @"ConversationCell";
@interface LCChatListController () <ZXingDelegate, LCMultiSelectControllerDelegate> {
    LCIMClient *_client;
    int _openStep;
    LCPopMenu *_popMenu;
    NSTimer *_openTimer;
//    CDSideBarController *_sideBar;
}

@end

@implementation LCChatListController

- (void)dealloc {
    [[self class] cancelPreviousPerformRequestsWithTarget:self];
}

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"消息";
        self.tabBarItem.image = [UIImage imageNamed:@"wechat"];
        _openStep = 0;
    }
    return self;
}

- (void)openIMClient {
    [_client openWithCallback:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            ++_openStep;
            if (_openStep >= 2) {
                [self.tableView triggerPullToRefresh];
            }
        } else {
            NSLog(@"%s error:%@", __PRETTY_FUNCTION__, error);
            [_openTimer invalidate];
            _openTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(openIMClient) userInfo:nil repeats:NO];
        }
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
//    NSArray *imageList = @[[UIImage imageNamed:@"menuChat.png"], [UIImage imageNamed:@"menuUsers.png"], [UIImage imageNamed:@"menuMap.png"], [UIImage imageNamed:@"menuClose.png"]];
//    CDSideBarController *sideBar = [[CDSideBarController alloc] initWithImages:imageList];
//    sideBar.delegate = self;
//    _sideBar = sideBar;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showMenuOnView:)];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

//    // setup infinite scrolling
//    [self.tableView addInfiniteScrollingWithActionHandler:^{
//        [weakSelf loadMore];
//    }];
    
    _client = [LCIMClient sharedInstance];
    [self openIMClient];

    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdated:) name:LC_NOTIFICATION_MESSAGE_UPDATED object:nil];

    __weak LCChatListController *weakSelf = self;
    
    // setup pull-to-refresh
    [self.tableView addPullToRefreshWithActionHandler:^{
        [weakSelf refresh];
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    ++_openStep;
    if (_openStep >= 2) {
        [self.tableView triggerPullToRefresh];
    }
//    [_sideBar insertMenuButtonOnView:self.navigationController.view atPosition:CGPointMake(self.view.frame.size.width - 70, 10)];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:LC_NOTIFICATION_MESSAGE_UPDATED object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (LCPopMenu *)popMenu {
    if (!_popMenu) {
        int count = 2;
        NSMutableArray *popMenuItems = [[NSMutableArray alloc] initWithCapacity:count];
        for (int i = 0; i < count; ++i) {
            NSString *imageName = nil;
            NSString *title;
            switch (i) {
                case 0: {
                    imageName = @"menu_add_newmessage";
                    title = @"发起群聊";
                    break;
                }
                case 1: {
                    imageName = @"menu_add_scan";
                    title = @"扫一扫";
                    break;
                }
                default:
                    break;
            }
            UIImage *image = [UIImage imageNamed:imageName];
            LCPopMenuItem *popMenuItem = [[LCPopMenuItem alloc] initWithImage:image title:title];
            [popMenuItems addObject:popMenuItem];
        }
        LCPopMenu *popMenu = [[LCPopMenu alloc] initWithMenus:popMenuItems];
        popMenu.popMenuSelected = ^(NSInteger index, LCPopMenuItem *item) {
            switch (index) {
                case 0:
                    [self addContactForGroup];
                    break;
                case 1:
                    [self addScan];
                    break;
                    
                default:
                    break;
            }
        };
        _popMenu = popMenu;
    }
    return _popMenu;
}

- (void)showMenuOnView:(UIBarButtonItem *)buttonItem {
    [self.popMenu showMenuOnView:self.navigationController.view atPoint:CGPointZero];
}

- (void)fetchUserList:(AVArrayResultBlock)callback {
    [LCUser queryUsersSkip:0 limit:1000 callback:^(NSArray *objects, NSError *error) {
        if (objects) {
            NSMutableArray *items = [[NSMutableArray alloc] init];
            for (LCUser *user in objects) {
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
            callback(items, nil);
        } else {
            NSLog(@"error:%@", error);
            callback(nil, error);
        }
    }];
}

- (void)addContactForGroup {
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
            controller.items = objects;
            controller.delegate = self;
            LCBaseNavigationController *nav = [[LCBaseNavigationController alloc] initWithRootViewController:controller];
            [self presentViewController:nav animated:YES completion:^{
                
            }];
        } else {
            hud.labelText = @"获取联系人列表失败";
            [hud hide:YES afterDelay:1];
        }
    }];
//    LCChatController *controller = [[LCChatController alloc] init];
    
//    [[CDSessionManager sharedInstance] startNewGroup:^(AVGroup *group, NSError *error) {
//        controller.type = CDChatRoomTypeGroup;
//        controller.group = group;
//        [self.navigationController pushViewController:controller animated:YES];
//    }];
    //    AVSession *session = [[AVSession alloc] init];
    //    session.sessionDelegate = [CDSessionManager sharedInstance];
    //    session.signatureDelegate = [CDSessionManager sharedInstance];
    
}

- (void)addScan {
    ZXingWidgetController *widController =
    [[ZXingWidgetController alloc] initWithDelegate:self showCancel:YES OneDMode:NO];
    
    NSMutableSet *readers = [[NSMutableSet alloc ] init];
    
    MultiFormatReader* reader = [[MultiFormatReader alloc] init];
    [readers addObject:reader];
    
    widController.readers = readers;
    
    //    NSBundle *mainBundle = [NSBundle mainBundle];
    //    widController.soundToPlay =
    //    [NSURL fileURLWithPath:[mainBundle pathForResource:@"beep-beep" ofType:@"aiff"] isDirectory:NO];
    
    [self presentViewController:widController animated:YES completion:^{
        
    }];
}

- (NSString *)stringFromDate:(NSDate *)date {
    if (!date) {
        return @"";
    }
    NSDate *currentDate = [NSDate date];
    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDateComponents* components = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:currentDate];
    NSInteger currentYear = [components year];
    NSInteger currentMonth = [components month];
    NSInteger currentDay = [components day];
    
    components = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date];
    NSInteger year = [components year];
    NSInteger month = [components month];
    NSInteger day = [components day];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    if (currentYear == year && currentMonth == month && currentDay == day) {
        formatter.dateFormat = @"HH:mm";
    } else {
        formatter.dateFormat = @"yyyy-MM-dd";
    }
    return [formatter stringFromDate:date];
}

- (void)refresh {
    [_client queryConversationsWithCallback:^(NSArray *objects, NSError *error) {
        [self.tableView reloadData];
        [self.tableView.pullToRefreshView stopAnimating];
    }];
}

- (void)messageUpdated:(NSNotification *)notification {
    [self.tableView reloadData];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kLCConversationCellHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[_client conversations] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[LCConversationCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    LCConversationCell *conversationCell = (LCConversationCell *)cell;
    AVIMConversation *conversation = [[_client conversations] objectAtIndex:indexPath.row];
    NSDictionary *attributes = conversation.attributes;
    LCConversationType type = [[attributes objectForKey:@"type"] unsignedIntegerValue];
    LCMessageEntity *entity = [_client latestMessageForConversationId:conversation.conversationId];
    NSString *dateString = [self stringFromDate:entity.date];
    if (type == LCConversationTypeSingle) {
        NSArray *members = conversation.members;
        NSString *userId = nil;
        for (NSString *clientId in members) {
            if (![clientId isEqualToString:conversation.imClient.clientId]) {
                userId = clientId;
                break;
            }
        }
        __block LCUser *user = [LCUser userById:userId];
        if (user) {
            NSString *nickname = user.nickname;
            conversationCell.nameLabel.text = nickname;
            NSURL *url = [NSURL URLWithString:user.photoUrl];
            [conversationCell.headView sd_setImageWithURL:url placeholderImage:[UIImage imageNamed:@"head_default"]];
            conversationCell.messageLabel.text = entity.text;
            
            conversationCell.timeLabel.text = dateString;
        } else {
            [LCUser queryUserWithId:userId callback:^(AVObject *object, NSError *error) {
                user = (LCUser *)object;
                NSString *nickname = user.nickname;
                conversationCell.nameLabel.text = nickname;
                NSURL *url = [NSURL URLWithString:user.photoUrl];
                [conversationCell.headView sd_setImageWithURL:url placeholderImage:[UIImage imageNamed:@"head_default"]];
                conversationCell.messageLabel.text = entity.text;
                
                conversationCell.timeLabel.text = dateString;
            }];
        }
    } else {
        __block NSMutableString *nameString = nil;
        if (conversation.name) {
            conversationCell.nameLabel.text = conversation.name;
        } else {
            NSArray *members = conversation.members;
            __block NSMutableArray *names = [[NSMutableArray alloc] init];
            NSMutableArray *dirtyClientIds = [[NSMutableArray alloc] init];
            for (NSString *clientId in members) {
                LCUser *user = [LCUser userById:clientId];
                if (user) {
                    [names addObject:user.nickname];
                } else {
                    [dirtyClientIds addObject:clientId];
                }
            }
            if (dirtyClientIds.count > 0) {
                [LCUser queryUserWithIds:dirtyClientIds callback:^(NSArray *objects, NSError *error) {
                    for (LCUser *user in objects) {
                        [names addObject:user.nickname];
                    }
                    [names sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                        return [obj1 compare:obj2 options:NSCaseInsensitiveSearch];
                    }];
                    for (NSString *name in names) {
                        if (!nameString) {
                            nameString = [[NSMutableString alloc] initWithString:name];
                        } else {
                            [nameString appendFormat:@",%@", name];
                        }
                    }
                    conversationCell.nameLabel.text = nameString;
                    conversationCell.memberCountLabel.text = [NSString stringWithFormat:@"（%d）", names.count];
                }];
            } else {
                [names sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                    return [obj1 compare:obj2 options:NSCaseInsensitiveSearch];
                }];
                for (NSString *name in names) {
                    if (!nameString) {
                        nameString = [[NSMutableString alloc] initWithString:name];
                    } else {
                        [nameString appendFormat:@",%@", name];
                    }
                }
                conversationCell.nameLabel.text = nameString;
                conversationCell.memberCountLabel.text = [NSString stringWithFormat:@"（%d）", names.count];
            }
        }
        if (entity) {
            conversationCell.messageLabel.text = [NSString stringWithFormat:@"%@:%@", entity.sender, entity.text];
        }
        conversationCell.timeLabel.text = dateString;
        NSURL *url = [NSURL URLWithString:[conversation.attributes objectForKey:@"photoUrl"]];
        [conversationCell.headView sd_setImageWithURL:url placeholderImage:[UIImage imageNamed:@"group_default"]];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AVIMConversation *conversation = [_client.conversations objectAtIndex:indexPath.row];
    LCChatController *controller = [[LCChatController alloc] init];
    controller.conversation = conversation;
    [self.navigationController pushViewController:controller animated:YES];
//    NSDictionary *chatRoom = [[[CDSessionManager sharedInstance] chatRooms] objectAtIndex:indexPath.row];
//    CDChatRoomType type = [[chatRoom objectForKey:@"type"] integerValue];
//    NSString *otherid = [chatRoom objectForKey:@"otherid"];
//    CDChatRoomController *controller = [[CDChatRoomController alloc] init];
//    controller.type = type;
//    if (type == CDChatRoomTypeGroup) {
//        AVGroup *group = [[CDSessionManager sharedInstance] joinGroup:otherid];
//        controller.group = group;
//        controller.otherId = otherid;
//    } else {
//        controller.otherId = otherid;
//    }
//    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - ZXingDelegateMethods

- (void)zxingController:(ZXingWidgetController*)controller didScanResult:(NSString *)result {
    NSLog(@"%s %@", __PRETTY_FUNCTION__, result);
    [self dismissViewControllerAnimated:NO completion:^{
        NSDictionary *dict = nil;
        NSError *error = nil;
        NSData *data = [result dataUsingEncoding:NSUTF8StringEncoding];
        dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
//        if (dict) {
//            CDChatRoomType type = [[dict objectForKey:@"type"] integerValue];
//            NSString *otherId = [dict objectForKey:@"id"];
//            CDChatConfirmController *controller = [[CDChatConfirmController alloc] init];
//            controller.type = type;
//            controller.otherId = otherId;
//            [self.navigationController pushViewController:controller animated:YES];
//        }
        
    }];
    // [self dismissViewControllerAnimated:NO completion:nil];
}

- (void)zxingControllerDidCancel:(ZXingWidgetController*)controller {
    [self dismissViewControllerAnimated:NO completion:^{
        
    }];
    // [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -
#pragma mark - CDSideBarController delegate

- (void)menuButtonClicked:(int)index
{
    // Execute what ever you want
}

- (void)multiSelectController:(LCMultiSelectController *)controller didSelectItems:(NSArray *)items {
    NSMutableArray *userIds = [[NSMutableArray alloc] init];
    for (LCMultiSelectItem *item in items) {
        [userIds addObject:item.userId];
    }
    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
    [self.navigationController.view addSubview:hud];
    hud.labelText = @"正在创建会话";
    // Regiser for HUD callbacks so we can remove it from the window at the right time
    //    hud.delegate = self;
    [hud show:YES];
    [_client createConversationWithUserIds:userIds callback:^(AVIMConversation *conversation, NSError *error) {
        if (!error) {
            [hud hide:YES];
            LCChatController *controller = [[LCChatController alloc] init];
            controller.conversation = conversation;
            [self.navigationController pushViewController:controller animated:YES];
        } else {
            hud.labelText = @"创建会话失败";
            [hud hide:YES afterDelay:1];
        }
    }];
}
@end
