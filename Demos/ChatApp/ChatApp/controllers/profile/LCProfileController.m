//
//  LCProfileController.m
//  LCChatApp
//
//  Created by Qihe Bian on 11/21/14.
//  Copyright (c) 2014 Lean Cloud Inc. All rights reserved.
//

#import "LCProfileController.h"
#import "LCCommon.h"
#import "LCAppDelegate.h"
#import "LCUser.h"
//#import "GBPathImageView.h"
#import "RSKImageCropper.h"
#import "UIImage+Resize.h"
#import "MBProgressHUD.h"
#import "NZCircularImageView.h"
#import "LCIMClient.h"

@interface LCProfileController () <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, RSKImageCropViewControllerDelegate>
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) NZCircularImageView *headView;
@end

@implementation LCProfileController

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
    CGFloat originX = rect.size.width/2 - 65;
    CGFloat originY = 80;
    CGFloat width = 130;
    CGFloat height = 130;
    LCUser *user = [LCUser currentUser];
    NZCircularImageView *headView = [[NZCircularImageView alloc] initWithFrame:CGRectMake(originX, originY, width, height)];
    [headView sd_setImageWithURL:[NSURL URLWithString:user.photoUrl] placeholderImage:[UIImage imageNamed:@"head_default"]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(editHeadPhoto:)];
    [headView addGestureRecognizer:tap];
    [headView setUserInteractionEnabled:YES];
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
    [button setTitle:@"退出登录" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    //    button.userInteractionEnabled = YES;
    [button addTarget:self action:@selector(logout:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    LCUser *user = [LCUser currentUser];
    NSString *nickname = [user nickname];
//    if ([[AVUser currentUser] mobilePhoneVerified]) {
//        nickname = [NSString stringWithFormat:@"%@(%@)", nickname, [user mobilePhoneNumber]];
//    }
    self.nameLabel.text = nickname;
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
    [LCUser logOut];
    [[LCIMClient sharedInstance] close];
//    [[CDSessionManager sharedInstance] clearData];
    LCAppDelegate *delegate = (LCAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate toLogin];
}

- (void)editHeadPhoto:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:@"取消"
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:@"拍照", @"从相册中选取", nil];
    [actionSheet showInView:self.view];
}

- (void)dismissImagePickerController {
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:YES completion:NULL];
    } else {
        [self.navigationController popToViewController:self animated:YES];
    }
}

#pragma mark UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        // 拍照
        if ([LCUtility isCameraAvailable] && [LCUtility doesCameraSupportTakingPhotos]) {
            UIImagePickerController *controller = [[UIImagePickerController alloc] init];
            controller.sourceType = UIImagePickerControllerSourceTypeCamera;
            if ([LCUtility isFrontCameraAvailable]) {
                controller.cameraDevice = UIImagePickerControllerCameraDeviceFront;
            }
            NSMutableArray *mediaTypes = [[NSMutableArray alloc] init];
            [mediaTypes addObject:(__bridge NSString *)kUTTypeImage];
            controller.mediaTypes = mediaTypes;
            controller.delegate = self;
//            [self.navigationController pushViewController:controller animated:YES];
            [self presentViewController:controller
                               animated:YES
                             completion:^(void){
                                 NSLog(@"Picker View Controller is presented");
                             }];
        }
        
    } else if (buttonIndex == 1) {
        // 从相册中选取
        if ([LCUtility isPhotoLibraryAvailable]) {
            UIImagePickerController *controller = [[UIImagePickerController alloc] init];
            controller.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            NSMutableArray *mediaTypes = [[NSMutableArray alloc] init];
            [mediaTypes addObject:(__bridge NSString *)kUTTypeImage];
            controller.mediaTypes = mediaTypes;
            controller.delegate = self;
//            [self.navigationController pushViewController:controller animated:YES];
            [self presentViewController:controller
                               animated:YES
                             completion:^(void){
                                 NSLog(@"Picker View Controller is presented");
                             }];
        }
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    RSKImageCropViewController *imageCropVC = [[RSKImageCropViewController alloc] initWithImage:image cropMode:RSKImageCropModeCircle cropSize:CGSizeMake(256, 256)];
    imageCropVC.delegate = self;
    [self dismissViewControllerAnimated:NO completion:^{
        [self.navigationController pushViewController:imageCropVC animated:YES];
    }];
}

#pragma mark - RSKImageCropViewControllerDelegate

- (void)imageCropViewControllerDidCancelCrop:(RSKImageCropViewController *)controller
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)imageCropViewController:(RSKImageCropViewController *)controller didCropImage:(UIImage *)croppedImage
{
    UIImage *scaledImage = [croppedImage resizedImageToFitInSize:CGSizeMake(256, 256) scaleIfSmaller:NO];
    [self.headView setImage:scaledImage];
//    [self.headView draw];
    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
    [self.navigationController.view addSubview:hud];
    hud.labelText = @"正在上传";
    // Regiser for HUD callbacks so we can remove it from the window at the right time
//    hud.delegate = self;
    [hud show:YES];
    // Show the HUD while the provided method executes in a new thread
//    [HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
    NSData *data = UIImagePNGRepresentation(scaledImage);
    AVFile *file = [AVFile fileWithName:@"photo.png" data:data];
    [file saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            [LCUser currentUser].photoUrl = file.url;
            [[LCUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                if (succeeded) {
                    [hud hide:YES];
                } else {
                    hud.labelText = @"上传失败";
                    [hud hide:YES afterDelay:1];
                }
            }];
        } else {
            hud.labelText = @"上传失败";
            [hud hide:YES afterDelay:1];
        }
    }];
    [self.navigationController popViewControllerAnimated:YES];
}
@end
