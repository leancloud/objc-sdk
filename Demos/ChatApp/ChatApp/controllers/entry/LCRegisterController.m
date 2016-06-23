//
//  LCRegisterController.m
//  LCChatApp
//
//  Created by Qihe Bian on 11/20/14.
//  Copyright (c) 2014 Lean Cloud Inc. All rights reserved.
//

#import "LCRegisterController.h"
#import "LCCommon.h"
#import "LCUser.h"
#import "LCTextField.h"
#import "LCBaseNavigationController.h"
#import "LCAppDelegate.h"
#import "MBProgressHUD.h"

@interface LCRegisterController () <UITextFieldDelegate> {
    CGPoint _originOffset;
}
@property (nonatomic, strong)LCTextField *usernameField;
@property (nonatomic, strong)LCTextField *passwordField;
@property (nonatomic, strong)UIButton *registerButton;

@end

@implementation LCRegisterController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIImage *image = [UIImage imageNamed:@"cancel"];
    UIImage *selectedImage = [UIImage imageNamed:@"cancel_selected"];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    [button setImage:image forState:UIControlStateNormal];
    [button setImage:selectedImage forState:UIControlStateHighlighted];
    [button addTarget:self action:@selector(cancel:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:button];
    self.navigationItem.leftBarButtonItem = item;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeKeyboard:)];
    tap.numberOfTapsRequired = 1;
    tap.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:tap];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(closeKeyboard:)];
    [self.view addGestureRecognizer:pan];
    
    CGFloat originX = 0;
    CGFloat originY = 0;
    CGFloat width = self.view.frame.size.width;
    CGFloat height = self.view.frame.size.height;
    image = [[UIImage imageNamed:@"background"] resizableImageWithCapInsets:UIEdgeInsetsMake(100, 0, 285, 0)];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.frame = CGRectMake(originX, originY, width, height);
    [self.view addSubview:imageView];
    
    originX = 30;
    originY = (SCREEN_HEIGHT<=480)?100:130;
    width = self.view.frame.size.width - originX*2;
    image = [UIImage imageNamed:@"input_bg_top"];
    height = image.size.height;
    LCTextField *textField = [[LCTextField alloc] initWithFrame:CGRectMake(originX, originY, width, height)];
    textField.background = image;
    textField.horizontalPadding = 10;
    textField.verticalPadding = 10;
    textField.placeholder = @"用户名";
    textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    textField.delegate = self;
    textField.returnKeyType = UIReturnKeyNext;
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [self.view addSubview:textField];
    self.usernameField = textField;
    
    originY += height;
    image = [UIImage imageNamed:@"input_bg_bottom"];
    height = image.size.height;
    textField = [[LCTextField alloc] initWithFrame:CGRectMake(originX, originY, width, height)];
    textField.background = image;
    textField.horizontalPadding = 10;
    textField.verticalPadding = 10;
    textField.placeholder = @"密码";
    textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    textField.delegate = self;
    textField.secureTextEntry = YES;
    textField.returnKeyType = UIReturnKeyGo;
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [self.view addSubview:textField];
    self.passwordField = textField;
    
    originY += height + 7;
    image = [[UIImage imageNamed:@"blue_expand_normal"] resizableImageWithCapInsets:UIEdgeInsetsMake(5, 5, 5, 5)];
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(originX, originY, width, height);
    [button setBackgroundImage:image forState:UIControlStateNormal];
    image = [[UIImage imageNamed:@"blue_expand_highlight"] resizableImageWithCapInsets:UIEdgeInsetsMake(5, 5, 5, 5)];
    [button setBackgroundImage:image forState:UIControlStateHighlighted];
    image = [[UIImage imageNamed:@"blue_expand_highlight"] resizableImageWithCapInsets:UIEdgeInsetsMake(5, 5, 5, 5)];
    [button setBackgroundImage:image forState:UIControlStateDisabled];
    button.enabled = NO;
    [button setTitle:@"注册" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    //    button.userInteractionEnabled = YES;
    [button addTarget:self action:@selector(register:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    self.registerButton = button;
    
    
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    //监听键盘高度的变换
    if (SCREEN_HEIGHT <= 480) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeButtonState:) name:UITextFieldTextDidChangeNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    UIScrollView *scrollView = (UIScrollView *)self.view;
    _originOffset = scrollView.contentOffset;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (void)cancel:(id)sender{
    [self dismissViewControllerAnimated:YES completion:^{
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
    }];
}

-(void)register:(id)sender
{
    LCUser *user = [LCUser user];
    user.username = self.usernameField.text;
    user.password = self.passwordField.text;
    user.nickname = self.usernameField.text;
    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
    [self.navigationController.view addSubview:hud];
    //    hud.labelText = @"正在上传";
    // Regiser for HUD callbacks so we can remove it from the window at the right time
    //    hud.delegate = self;
    [hud show:YES];
    [user signUpInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        [hud hide:YES];
        if (!error) {
            //Register success
            NSLog(@"Register success");
//            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:KEY_ISLOGINED];
            [[NSUserDefaults standardUserDefaults] setObject:self.usernameField.text forKey:KEY_USERNAME];
            [self dismissViewControllerAnimated:NO completion:^{
                
            }];
            LCAppDelegate *delegate = (LCAppDelegate *)[UIApplication sharedApplication].delegate;
            [delegate toMain];
        } else {
            //Something bad has ocurred
            NSString *errorString = [[error userInfo] objectForKey:@"error"];
            UIAlertView *errorAlertView = [[UIAlertView alloc] initWithTitle:@"Error" message:errorString delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
            [errorAlertView show];
        }
    }];
    
    
}

- (void)closeKeyboard:(id)sender {
    [self.usernameField resignFirstResponder];
    [self.passwordField resignFirstResponder];
}

- (void)changeButtonState:(NSNotification *)notification{
    UIButton *button = self.registerButton;
    if(self.usernameField.text.length >= USERNAME_MIN_LENGTH && self.passwordField.text.length >= PASSWORD_MIN_LENGTH){
        button.enabled = YES;
    }else {
        button.enabled = NO;
    }
}
#pragma mark - Responding to keyboard events
- (void)keyboardWillShow:(NSNotification *)notification {
    [self performSelector:@selector(moveUpMainView) withObject:nil afterDelay:0.1];
}


- (void)keyboardWillHide:(NSNotification *)notification{
    UIScrollView *scrollView = (UIScrollView *)self.view;
    [scrollView setContentOffset:_originOffset animated:YES];
}

- (void)moveUpMainView{
    UIScrollView *scrollView = (UIScrollView *)self.view;
    [scrollView setContentOffset:CGPointMake(0, 65) animated:YES];
}


@end
