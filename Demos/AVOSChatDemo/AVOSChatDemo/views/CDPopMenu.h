//
//  CDPopMenu.h
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/30/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CDPopMenuItem.h"

typedef void(^PopMenuEventBlock)(NSInteger index, CDPopMenuItem *menuItem);

@interface CDPopMenu : UIView
- (instancetype)initWithMenus:(NSArray *)menus;

- (instancetype)initWithObjects:(id)firstObj, ... NS_REQUIRES_NIL_TERMINATION;

- (void)showMenuAtPoint:(CGPoint)point;

- (void)showMenuOnView:(UIView *)view atPoint:(CGPoint)point;

@property (nonatomic, copy) PopMenuEventBlock popMenuSelected;

@property (nonatomic, copy) PopMenuEventBlock popMenuDismissed;

@end
