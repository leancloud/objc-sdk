//
//  KALoginController.m
//  KeepAlive
//
//  Created by Qihe Bian on 7/21/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "KALoginController.h"

@interface KALoginController ()
@property(nonatomic, strong)UITextField *displayNameFiled;
@end

@implementation KALoginController

- (void)loadView {
    [super loadView];
    UIView *view = [[UIScrollView alloc] initWithFrame:self.view.frame];
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    // Do any additional setup after loading the view.
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(self.view.frame.size.width/2 - 100, 40, 200, 40)];
    textField.placeholder = @"Display Name";
    NSString *displayName = [[NSUserDefaults standardUserDefaults] objectForKey:@"DisplayName"];
    if (displayName) {
        textField.text = displayName;
    }
    [self.view addSubview:textField];
    self.displayNameFiled = textField;
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"Login" forState:UIControlStateNormal];
    button.frame = CGRectMake(self.view.frame.size.width/2 - 100, 90, 200, 40);
    [button addTarget:self action:@selector(login:) forControlEvents:UIControlEventTouchUpInside];
    button.backgroundColor = [UIColor blueColor];
    [self.view addSubview:button];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)login:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (self.displayNameFiled.text.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:self.displayNameFiled.text forKey:@"DisplayName"];
        [self dismissMe];
    }
    
//    CATransition* transition = [CATransition animation];
//    transition.duration = 0.3;
//    transition.type = kCATransitionMoveIn;
//    transition.subtype = kCATransitionFromTop;
//    [self.view.window.layer addAnimation:transition forKey:kCATransition];
//    [self dismissViewControllerAnimated:YES completion:^{
//        
//    }];
//    UITabBarController *tab = [[UITabBarController alloc] init];
//    UIViewController *vc = [[UIViewController alloc] init];
//    [tab addChildViewController:vc];
//    [[[UIApplication sharedApplication] keyWindow] setRootViewController:tab];
}

-(void) dismissMe {
//    CATransition *transition = [CATransition animation];
//    transition.duration = 2;
//    transition.timingFunction =
//    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
//    transition.type = kCATransitionPush;
//    transition.subtype = kCATransitionFromTop;
//    
//    // NSLog(@"%s: controller.view.window=%@", _func_, controller.view.window);
//    UIView *containerView = self.view.window;
//    [containerView.layer addAnimation:transition forKey:nil];
    
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}
@end
