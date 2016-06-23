//
//  CDChatConfirmController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 8/6/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDChatConfirmController.h"

@interface CDChatConfirmController ()
@property (nonatomic, strong) UILabel *nameLabel;
@end

@implementation CDChatConfirmController

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
    [button setTitle:@"确认添加" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    //    button.userInteractionEnabled = YES;
    [button addTarget:self action:@selector(confirm:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSString *name = self.otherId;
    if (self.type == CDChatRoomTypeGroup) {
        name = [NSString stringWithFormat:@"group:%@", name];
    }
    self.nameLabel.text = name;
    //    [[AVUser currentUser] setMobilePhoneNumber:@"18911209919"];
    //    [[AVUser currentUser] save];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

-(void)confirm:(id)sender {
    if (self.type == CDChatRoomTypeGroup) {
        [[CDSessionManager sharedInstance] joinGroup:self.otherId];
    } else if (self.type == CDChatRoomTypeSingle) {
        [[CDSessionManager sharedInstance] addChatWithPeerId:self.otherId];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

@end
