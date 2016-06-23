//
//  LCPopMenuItem.h
//  ChatApp
//
//  Created by Qihe Bian on 12/29/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kLCMenuTableViewWidth 140
#define kLCMenuTableViewSapcing 7

#define kLCMenuItemViewHeight 40
#define kLCMenuItemViewImageSapcing 15
#define kLCSeparatorLineImageViewHeight 0.5

@interface LCPopMenuItem : NSObject
@property (nonatomic, strong) UIImage *image;

@property (nonatomic, strong) NSString *title;

- (instancetype)initWithImage:(UIImage *)image title:(NSString *)title;
@end
