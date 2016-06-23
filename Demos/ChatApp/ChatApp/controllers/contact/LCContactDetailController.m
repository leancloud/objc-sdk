//
//  LCContactDetailController.m
//  ChatApp
//
//  Created by Qihe Bian on 12/24/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCContactDetailController.h"
#import "LCCommon.h"
#import "LCBaseNavigationController.h"
#import "NZCircularImageView.h"
#import "LCChatController.h"
#import "LCIMClient.h"
#import "LCChatListController.h"
#import "MBProgressHUD.h"

@interface LCContactDetailController ()
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) NZCircularImageView *headView;

@end

@implementation LCContactDetailController

- (instancetype)initWithUser:(LCUser *)user {
    if ((self = [super init])) {
        self.user = user;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    CGRect rect = self.view.frame;
//    CGFloat originX = rect.size.width/2 - 70;
//    CGFloat originY = 40;
//    CGFloat width = 140;
//    CGFloat height = 40;
    
    CGRect rect = self.view.frame;
    CGFloat originX = rect.size.width/2 - 65;
    CGFloat originY = 80;
    CGFloat width = 130;
    CGFloat height = 130;
    
    NZCircularImageView *headView = [[NZCircularImageView alloc] initWithFrame:CGRectMake(originX, originY, width, height)];
    [headView sd_setImageWithURL:[NSURL URLWithString:self.user.photoUrl] placeholderImage:[UIImage imageNamed:@"head_default.png"]];
    [self.view addSubview:headView];
    self.headView = headView;
    
    originX = rect.size.width/2 - 150;
    originY += 140;
    width = 300;
    height = 40;
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(originX, originY, width, height)];
    label.font = [UIFont systemFontOfSize:24];
    label.textColor = [UIColor greenColor];
    label.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:label];
    self.nameLabel = label;
    
    originY += 80;
    UIImage *image = [[UIImage imageNamed:@"blue_expand_normal"] resizableImageWithCapInsets:UIEdgeInsetsMake(5, 5, 5, 5)];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(originX, originY, width, height);
    [button setBackgroundImage:image forState:UIControlStateNormal];
    image = [[UIImage imageNamed:@"blue_expand_highlight"] resizableImageWithCapInsets:UIEdgeInsetsMake(5, 5, 5, 5)];
    [button setBackgroundImage:image forState:UIControlStateHighlighted];
    image = [[UIImage imageNamed:@"blue_expand_highlight"] resizableImageWithCapInsets:UIEdgeInsetsMake(5, 5, 5, 5)];
    [button setBackgroundImage:image forState:UIControlStateDisabled];
    [button setTitle:@"开始聊天" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    //    button.userInteractionEnabled = YES;
    [button addTarget:self action:@selector(startChat:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.nameLabel.text = self.user.nickname;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

-(void)startChat:(id)sender {
    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
    [self.navigationController.view addSubview:hud];
    hud.labelText = @"正在创建会话";
    // Regiser for HUD callbacks so we can remove it from the window at the right time
    //    hud.delegate = self;
    [hud show:YES];
    [[LCIMClient sharedInstance] fetchOrCreateConversationWithUserId:self.user.objectId callback:^(AVIMConversation *conversation, NSError *error) {
        if (conversation) {
            [hud hide:YES];
            LCBaseNavigationController *nav = self.tabBarController.childViewControllers.firstObject;
//            LCChatListController *listController = nav.childViewControllers.firstObject;
            LCChatController *controller = [[LCChatController alloc] init];
            controller.conversation = conversation;
            self.tabBarController.selectedIndex = 0;
            [nav popToRootViewControllerAnimated:NO];
            
            [self.tabBarController.childViewControllers.firstObject pushViewController:controller animated:YES];
            [self.navigationController popToRootViewControllerAnimated:NO];
        } else {
            hud.labelText = @"创建会话失败";
            [hud hide:YES afterDelay:1];
        }

    }];
    //    CDChatListController *chatList = nav.childViewControllers.firstObject;
//    CDChatRoomController *controller = [[CDChatRoomController alloc] init];
//    //    AVSession *session = [[AVSession alloc] init];
//    //    session.sessionDelegate = [CDSessionManager sharedInstance];
//    //    session.signatureDelegate = [CDSessionManager sharedInstance];
//    //    [session open:[AVUser currentUser].username withPeerIds:@[self.user.username]];
//    [[CDSessionManager sharedInstance] addChatWithPeerId:self.user.username];
//    //    controller.session = session;
//    controller.otherId = self.user.username;
//    controller.type = CDChatRoomTypeSingle;
//    self.tabBarController.selectedIndex = 0;
//    [nav popToRootViewControllerAnimated:NO];
//    
//    [self.tabBarController.childViewControllers.firstObject pushViewController:controller animated:YES];
//    [self.navigationController popToRootViewControllerAnimated:NO];
    
}


@end
