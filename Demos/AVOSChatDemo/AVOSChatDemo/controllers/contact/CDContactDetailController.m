//
//  CDContactDetailController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/28/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDContactDetailController.h"
#import "CDChatRoomController.h"
#import "CDBaseNavigationController.h"
#import "CDChatListController.h"
#import "CDSessionManager.h"

@interface CDContactDetailController ()
@property (nonatomic, strong) UILabel *nameLabel;

@end

@implementation CDContactDetailController

- (instancetype)initWithUser:(AVUser *)user {
    if ((self = [super init])) {
        self.user = user;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CGRect rect = self.view.frame;
    CGFloat originX = rect.size.width/2 - 70;
    CGFloat originY = 40;
    CGFloat width = 140;
    CGFloat height = 40;
    
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
    self.nameLabel.text = [self.user username];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

-(void)startChat:(id)sender {
    CDBaseNavigationController *nav = self.tabBarController.childViewControllers.firstObject;
//    CDChatListController *chatList = nav.childViewControllers.firstObject;
    CDChatRoomController *controller = [[CDChatRoomController alloc] init];
//    AVSession *session = [[AVSession alloc] init];
//    session.sessionDelegate = [CDSessionManager sharedInstance];
//    session.signatureDelegate = [CDSessionManager sharedInstance];
//    [session open:[AVUser currentUser].username withPeerIds:@[self.user.username]];
    [[CDSessionManager sharedInstance] addChatWithPeerId:self.user.username];
//    controller.session = session;
    controller.otherId = self.user.username;
    controller.type = CDChatRoomTypeSingle;
    self.tabBarController.selectedIndex = 0;
    [nav popToRootViewControllerAnimated:NO];
    
    [self.tabBarController.childViewControllers.firstObject pushViewController:controller animated:YES];
    [self.navigationController popToRootViewControllerAnimated:NO];

}

@end
