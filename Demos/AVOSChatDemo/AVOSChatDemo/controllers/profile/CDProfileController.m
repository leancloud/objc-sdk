//
//  CDProfileController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/28/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDProfileController.h"
#import "CDCommon.h"
#import "CDLoginController.h"
#import "CDAppDelegate.h"
#import "CDSessionManager.h"

@interface CDProfileController ()
@property (nonatomic, strong) UILabel *nameLabel;
@end

@implementation CDProfileController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"我";
        self.tabBarItem.image = [UIImage imageNamed:@"profile"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CGRect rect = self.view.frame;
    CGFloat originX = rect.size.width/2 - 150;
    CGFloat originY = 40;
    CGFloat width = 300;
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
    [button setTitle:@"退出登录" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    //    button.userInteractionEnabled = YES;
    [button addTarget:self action:@selector(logout:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    AVUser *user = [AVUser currentUser];
    NSString *username = [user username];
    if ([[AVUser currentUser] mobilePhoneVerified]) {
        username = [NSString stringWithFormat:@"%@(%@)", username, [user mobilePhoneNumber]];
    }
    self.nameLabel.text = username;
//    [[AVUser currentUser] setMobilePhoneNumber:@""];
//    [[AVUser currentUser] save];
//    [AVUser requestPasswordResetWithPhoneNumber:@"" block:^(BOOL succeeded, NSError *error) {
//        
//    }];
//    [AVUser resetPasswordWithSmsCode:@"705784" newPassword:@"123456" block:^(BOOL succeeded, NSError *error) {
//        
//    }];
//    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
//    [dict setObject:@"MyName" forKey:@"username"];
//    [dict setObject:@"MyApplication" forKey:@"appname"];
//    [AVOSCloud requestSmsCodeWithPhoneNumber:@"12312312312" templateName:@"Register_Template" variables:dict callback:^(BOOL succeeded, NSError *error) {
//        if (succeeded) {
//            //do something
//        } else {
//            NSLog(@"%@", error);
//        }
//    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

-(void)logout:(id)sender {
    [AVUser logOut];
    [[CDSessionManager sharedInstance] clearData];
    CDAppDelegate *delegate = (CDAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate toLogin];
}

@end
