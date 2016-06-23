//
//  LCMultiSelectedPanel.m
//  ChatApp
//
//  Created by Qihe Bian on 12/30/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCMultiSelectedPanel.h"
#import "LCMultiSelectCommon.h"
#import "LCMultiSelectItem.h"
#import "NZCircularImageView.h"

static NSString *cellIdentifier = @"LCMultiSelectedPanelCell";
@interface LCMultiSelectedPanel()<UICollectionViewDataSource, UICollectionViewDelegate>

@property (weak, nonatomic) UIImageView *backgroundImageView;
@property (weak, nonatomic) UIButton *confirmButton;
@property (weak, nonatomic) UICollectionView *collectionView;


@end

@implementation LCMultiSelectedPanel

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

@end
