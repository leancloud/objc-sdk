//
//  CDChatListController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/25/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDChatListController.h"
#import "CDSessionManager.h"
#import "CDChatRoomController.h"
#import "CDPopMenu.h"
#import "ZXingWidgetController.h"
#import "MultiFormatReader.h"
#import "CDChatConfirmController.h"

enum : NSUInteger {
    kTagNameLabel = 10000,
};
@interface CDChatListController () <ZXingDelegate> {
    CDPopMenu *_popMenu;
}

@end

@implementation CDChatListController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"消息";
        self.tabBarItem.image = [UIImage imageNamed:@"wechat"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showMenuOnView:)];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionUpdated:) name:NOTIFICATION_SESSION_UPDATED object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showMenuOnView:(UIBarButtonItem *)buttonItem {
    [self.popMenu showMenuOnView:self.navigationController.view atPoint:CGPointZero];
}

- (void)addContactForGroup {
    CDChatRoomController *controller = [[CDChatRoomController alloc] init];
    [[CDSessionManager sharedInstance] startNewGroup:^(AVGroup *group, NSError *error) {
        controller.type = CDChatRoomTypeGroup;
        controller.group = group;
        [self.navigationController pushViewController:controller animated:YES];
    }];
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 40;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[CDSessionManager sharedInstance] chatRooms] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"ContactCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 300, 30)];
        label.font = [UIFont systemFontOfSize:14];
        label.tag = kTagNameLabel;
        label.textColor = [UIColor redColor];
        [cell.contentView addSubview:label];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *chatRoom = [[[CDSessionManager sharedInstance] chatRooms] objectAtIndex:indexPath.row];
    CDChatRoomType type = [[chatRoom objectForKey:@"type"] integerValue];
    NSString *otherid = [chatRoom objectForKey:@"otherid"];
    NSMutableString *nameString = [[NSMutableString alloc] init];
    if (type == CDChatRoomTypeGroup) {
        [nameString appendFormat:@"group:%@", otherid];
    } else {
        [nameString appendFormat:@"%@", otherid];
    }
    UILabel *label = (UILabel *)[cell.contentView viewWithTag:kTagNameLabel];
    label.text = nameString;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *chatRoom = [[[CDSessionManager sharedInstance] chatRooms] objectAtIndex:indexPath.row];
    CDChatRoomType type = [[chatRoom objectForKey:@"type"] integerValue];
    NSString *otherid = [chatRoom objectForKey:@"otherid"];
    CDChatRoomController *controller = [[CDChatRoomController alloc] init];
    controller.type = type;
    if (type == CDChatRoomTypeGroup) {
        AVGroup *group = [[CDSessionManager sharedInstance] joinGroup:otherid];
        controller.group = group;
        controller.otherId = otherid;
    } else {
        controller.otherId = otherid;
    }
    [self.navigationController pushViewController:controller animated:YES];
}

- (CDPopMenu *)popMenu {
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
            CDPopMenuItem *popMenuItem = [[CDPopMenuItem alloc] initWithImage:image title:title];
            [popMenuItems addObject:popMenuItem];
        }
        CDPopMenu *popMenu = [[CDPopMenu alloc] initWithMenus:popMenuItems];
        popMenu.popMenuSelected = ^(NSInteger index, CDPopMenuItem *item) {
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

#pragma mark - ZXingDelegateMethods

- (void)zxingController:(ZXingWidgetController*)controller didScanResult:(NSString *)result {
    NSLog(@"%s %@", __PRETTY_FUNCTION__, result);
    [self dismissViewControllerAnimated:NO completion:^{
        NSDictionary *dict = nil;
        NSError *error = nil;
        NSData *data = [result dataUsingEncoding:NSUTF8StringEncoding];
        dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        if (dict) {
            CDChatRoomType type = [[dict objectForKey:@"type"] integerValue];
            NSString *otherId = [dict objectForKey:@"id"];
            CDChatConfirmController *controller = [[CDChatConfirmController alloc] init];
            controller.type = type;
            controller.otherId = otherId;
            [self.navigationController pushViewController:controller animated:YES];
        }
        
    }];
    // [self dismissViewControllerAnimated:NO completion:nil];
}

- (void)zxingControllerDidCancel:(ZXingWidgetController*)controller {
    [self dismissViewControllerAnimated:NO completion:^{
        
    }];
    // [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)sessionUpdated:(NSNotification *)notification {
    [self.tableView reloadData];
}
@end
