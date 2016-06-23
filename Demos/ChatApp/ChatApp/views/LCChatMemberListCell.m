//
//  LCChatMemberListCell.m
//  ChatApp
//
//  Created by Qihe Bian on 1/5/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCChatMemberListCell.h"
#import "NZCircularImageView.h"
#import "LCUser.h"
#import "LCChatDetailForm.h"
#import "LCMemberListController.h"

static NSString *cellIdentifier = @"LCChatMemberListCell";
@interface LCChatMemberListCell()<UICollectionViewDataSource, UICollectionViewDelegate>

@property (weak, nonatomic) UIImageView *backgroundImageView;
@property (weak, nonatomic) UIButton *confirmButton;
@property (weak, nonatomic) UICollectionView *collectionView;


@end

@implementation LCChatMemberListCell
/*
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UIImageView *imageview = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 44.0)];
        imageview.autoresizesSubviews = YES;
        imageview.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:imageview];
        self.backgroundImageView = imageview;
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        button.frame = CGRectMake(252.0, 8.0, 63.0, 28.0);
        button.adjustsImageWhenDisabled = YES;
        button.adjustsImageWhenHighlighted = YES;
        button.autoresizesSubviews = YES;
        button.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
        button.clipsToBounds = NO;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        button.contentMode = UIViewContentModeScaleToFill;
        button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        button.enabled = YES;
        [button setTitleColor:[UIColor colorWithWhite:0.000 alpha:1.000] forState:UIControlStateHighlighted];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button setTitleShadowColor:[UIColor colorWithWhite:0.500 alpha:1.000] forState:UIControlStateNormal];
        [self addSubview:button];
        self.confirmButton = button;
        
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.itemSize = CGSizeMake(40, 36);
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0.0, 5.0, 242, 36) collectionViewLayout:layout];
        collectionView.autoresizesSubviews = YES;
        collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        collectionView.backgroundColor = [UIColor colorWithWhite:1.000 alpha:1.000];
        collectionView.userInteractionEnabled = YES;
        collectionView.showsHorizontalScrollIndicator = NO;
        collectionView.showsVerticalScrollIndicator = NO;
        [self addSubview:collectionView];
        self.collectionView = collectionView;
        [self setUp];
    }
    return self;
}

- (void)setUp
{
    self.autoresizingMask = UIViewAutoresizingNone;
    
    self.backgroundImageView.image = [[UIImage imageNamed:kSrcName(@"MultiSelectedPanelBkg")]resizableImageWithCapInsets:UIEdgeInsetsMake(5, 5, 5, 5)];
    
    //    self.tableView.scrollsToTop = NO;
    //    self.tableView.showsVerticalScrollIndicator = NO;
    //    self.tableView.frame = CGRectMake(0, 5, 36, 242);
    //    self.tableView.transform = CGAffineTransformMakeRotation(M_PI*1.5);
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:cellIdentifier];
    
    [self.confirmButton setTitle:@"确认(0)" forState:UIControlStateNormal];
    self.confirmButton.enabled = NO;
    [self.confirmButton setBackgroundImage:[[UIImage imageNamed:kSrcName(@"MultiSelectedPanelConfirmBtnbKG")] resizableImageWithCapInsets:UIEdgeInsetsMake(8, 8, 8, 8)] forState:UIControlStateNormal];
    [self.confirmButton addTarget:self action:@selector(confirmBtnPressed:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)updateConfirmButton
{
    int count = (int)_selectedItems.count;
    self.confirmButton.enabled = count>0;
    
    [self.confirmButton setTitle:[NSString stringWithFormat:@"确认(%d)",count] forState:UIControlStateNormal];
}

- (void)confirmBtnPressed:(id)sender {
    if (self.delegate&&[self.delegate respondsToSelector:@selector(didConfirmWithMultiSelectedPanel:)]) {
        [self.delegate didConfirmWithMultiSelectedPanel:self];
    }
}

#pragma mark - setter
- (void)setSelectedItems:(NSMutableArray *)selectedItems {
    _selectedItems = selectedItems;
    
    [self.collectionView reloadData];
    
    [self updateConfirmButton];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.selectedItems.count;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    //添加一个imageView
    NZCircularImageView *imageView = (NZCircularImageView *)[cell.contentView viewWithTag:999];
    if (!imageView) {
        imageView = [[NZCircularImageView alloc]initWithFrame:CGRectMake(2.0f, 0.0f, 36.0f, 36.0f)];
        imageView.tag = 999;
        //        imageView.layer.cornerRadius = 4.0f;
        //        imageView.clipsToBounds = YES;
        //        imageView.contentMode = UIViewContentModeScaleAspectFill;
        [cell.contentView addSubview:imageView];
    }
    LCMultiSelectItem *item = self.selectedItems[indexPath.item];
    
    imageView.image = nil;
    [imageView sd_setImageWithURL:item.imageURL placeholderImage:[UIImage imageNamed:@"head_default"]];
    //    [imageView setImageWithURL:item.imageURL];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    
    LCMultiSelectItem *item = self.selectedItems[indexPath.item];
    //删除某元素,实际上是告诉delegate去删除
    if (self.delegate&&[self.delegate respondsToSelector:@selector(willDeleteRowWithItem:withMultiSelectedPanel:)]) {
        [self.delegate willDeleteRowWithItem:item withMultiSelectedPanel:self];
    }
    //确定没了删掉
    if ([self.selectedItems indexOfObject:item]==NSNotFound) {
        [self updateConfirmButton];
        [collectionView deleteItemsAtIndexPaths:@[indexPath]];
    }
}

#pragma mark - out call
- (void)didDeleteSelectedIndex:(NSUInteger)selectedIndex
{
    [self updateConfirmButton];
    //执行删除操作
    [self.collectionView deleteItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:selectedIndex inSection:0]]];
    //    [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:selectedIndex inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
    
}

- (void)didAddSelectedIndex:(NSUInteger)selectedIndex
{
    //找到index
    if (selectedIndex<self.selectedItems.count) {
        [self updateConfirmButton];
        //执行插入操作
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:selectedIndex inSection:0];
        [self.collectionView insertItemsAtIndexPaths:@[indexPath]];
        [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionRight animated:YES];
        //        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        //        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}
*/
- (void)setUp
{
    self.textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    self.textLabel.backgroundColor = [UIColor clearColor];
//    UIImageView *imageview = [[UIImageView alloc] initWithFrame:CGRectMake(100.0, 0.0, 220.0, 44.0)];
//    imageview.autoresizesSubviews = YES;
//    imageview.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
//    [self.contentView addSubview:imageview];
//    self.backgroundImageView = imageview;
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(36, 36);
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(80.0, 5.0, 235, 40) collectionViewLayout:layout];
    collectionView.userInteractionEnabled = NO;
    collectionView.autoresizesSubviews = YES;
    collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    collectionView.backgroundColor = [UIColor colorWithWhite:1.000 alpha:0.000];
    collectionView.showsHorizontalScrollIndicator = NO;
    collectionView.showsVerticalScrollIndicator = NO;
    collectionView.delegate = self;
    collectionView.dataSource = self;
    [collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:cellIdentifier];
    [self.contentView addSubview:collectionView];
    self.collectionView = collectionView;
    
    
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
//    UIImageView *imageView = [[UIImageView alloc] init];
//    imageView.contentMode = UIViewContentModeScaleAspectFill;
//    imageView.clipsToBounds = YES;
//    self.accessoryView = imageView;
    [self setNeedsLayout];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
}

- (void)update {
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    self.textLabel.text = self.field.title;
    LCChatDetailForm *form = (LCChatDetailForm *)self.field.form;
    self.conversation = form.conversation;
    [self.collectionView reloadData];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect labelFrame = self.textLabel.frame;
    labelFrame.size.width = MIN(MAX([self.textLabel sizeThatFits:CGSizeZero].width, 97), 240);
    self.textLabel.frame = labelFrame;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.conversation.members.count > 5 ? 5 : self.conversation.members.count;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    //添加一个imageView
    NZCircularImageView *imageView = (NZCircularImageView *)[cell.contentView viewWithTag:999];
    if (!imageView) {
        imageView = [[NZCircularImageView alloc]initWithFrame:CGRectMake(2.0f, 0.0f, 36.0f, 36.0f)];
        imageView.tag = 999;
        //        imageView.layer.cornerRadius = 4.0f;
        //        imageView.clipsToBounds = YES;
        //        imageView.contentMode = UIViewContentModeScaleAspectFill;
        [cell.contentView addSubview:imageView];
    }
    NSString *userId = [self.conversation.members objectAtIndex:indexPath.item];
    __block LCUser *user = [LCUser userById:userId];
    if (user) {
        NSURL *url = [NSURL URLWithString:user.photoUrl];
        [imageView sd_setImageWithURL:url placeholderImage:[UIImage imageNamed:@"head_default"]];
    } else {
        [LCUser queryUserWithId:userId callback:^(AVObject *object, NSError *error) {
            user = (LCUser *)object;
            NSURL *url = [NSURL URLWithString:user.photoUrl];
            [imageView sd_setImageWithURL:url placeholderImage:[UIImage imageNamed:@"head_default"]];
        }];
    }
    return cell;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0.0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 2.0;
}

// Layout: Set Edges
- (UIEdgeInsets)collectionView:
(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    // return UIEdgeInsetsMake(0,8,0,8);  // top, left, bottom, right
    return UIEdgeInsetsMake(0,2,0,2);  // top, left, bottom, right
}

//- (void)dealloc
//{
//    _imagePickerController.delegate = nil;
//}
//
//- (void)layoutSubviews
//{
//    CGRect frame = self.imagePickerView.bounds;
//    frame.size.height = self.bounds.size.height - 10;
//    UIImage *image = self.imagePickerView.image;
//    frame.size.width = image.size.height? image.size.width * (frame.size.height / image.size.height): 0;
//    self.imagePickerView.bounds = frame;
//    
//    [super layoutSubviews];
//}
//
//- (void)update
//{
//    self.textLabel.text = self.field.title;
//    self.imagePickerView.image = [self imageValue];
//    [self setNeedsLayout];
//}
//
//- (UIImage *)imageValue
//{
//    if (self.field.value)
//    {
//        return self.field.value;
//    }
//    else if (self.field.placeholder)
//    {
//        UIImage *placeholderImage = self.field.placeholder;
//        if ([placeholderImage isKindOfClass:[NSString class]])
//        {
//            placeholderImage = [UIImage imageNamed:self.field.placeholder];
//        }
//        return placeholderImage;
//    }
//    return nil;
//}
//
//- (UIImagePickerController *)imagePickerController
//{
//    if (!_imagePickerController)
//    {
//        _imagePickerController = [[UIImagePickerController alloc] init];
//        _imagePickerController.delegate = self;
//        _imagePickerController.allowsEditing = YES;
//    }
//    return _imagePickerController;
//}
//
//- (UIImageView *)imagePickerView
//{
//    return (UIImageView *)self.accessoryView;
//}
//
- (void)didSelectWithTableView:(UITableView *)tableView controller:(UIViewController *)controller
{
//    [FXFormsFirstResponder(tableView) resignFirstResponder];
    [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:YES];
    LCMemberListController *subcontroller = nil;
if (self.field.viewController && self.field.viewController == [self.field.viewController class])
    {
        subcontroller = [[self.field.viewController alloc] init];
        ((id <FXFormFieldViewController>)subcontroller).field = self.field;
    }
    else if ([self.field.viewController isKindOfClass:[UIViewController class]])
    {
        subcontroller = self.field.viewController;
        ((id <FXFormFieldViewController>)subcontroller).field = self.field;
    }
    if (!subcontroller.title) subcontroller.title = self.field.title;
    subcontroller.conversation = self.conversation;
//    {
        NSAssert(controller.navigationController != nil, @"Attempted to push a sub-viewController from a form that is not embedded inside a UINavigationController. That won't work!");
        [controller.navigationController pushViewController:subcontroller animated:YES];
//    }
//    if (!TARGET_IPHONE_SIMULATOR && ![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
//    {
//        self.imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
//        [controller presentViewController:self.imagePickerController animated:YES completion:nil];
//    }
//    else if ([UIAlertController class])
//    {
//        UIAlertControllerStyle style = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)? UIAlertControllerStyleAlert: UIAlertControllerStyleActionSheet;
//        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:style];
//        
//        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Take Photo", nil) style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
//            [self actionSheet:nil didDismissWithButtonIndex:0];
//        }]];
//        
//        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Photo Library", nil) style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
//            [self actionSheet:nil didDismissWithButtonIndex:1];
//        }]];
//        
//        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:NULL]];
//        
//        self.controller = controller;
//        [controller presentViewController:alert animated:YES completion:NULL];
//    }
//    else
//    {
//        self.controller = controller;
//        [[[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil) destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Take Photo", nil), NSLocalizedString(@"Photo Library", nil), nil] showInView:controller.view];
//    }
}
//
//- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
//{
//    [picker dismissViewControllerAnimated:YES completion:NULL];
//}
//
//- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
//{
//    self.field.value = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
//    [picker dismissViewControllerAnimated:YES completion:NULL];
//    if (self.field.action) self.field.action(self);
//    [self update];
//}
//
//- (void)actionSheet:(__unused UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
//{
//    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
//    switch (buttonIndex)
//    {
//        case 0:
//        {
//            sourceType = UIImagePickerControllerSourceTypeCamera;
//            break;
//        }
//        case 1:
//        {
//            sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
//            break;
//        }
//    }
//    
//    if ([UIImagePickerController isSourceTypeAvailable:sourceType])
//    {
//        self.imagePickerController.sourceType = sourceType;
//        [self.controller presentViewController:self.imagePickerController animated:YES completion:nil];
//    }
//    
//    self.controller = nil;
//}

@end
