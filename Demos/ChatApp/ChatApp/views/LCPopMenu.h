//
//  LCPopMenu.h
//  ChatApp
//
//  Created by Qihe Bian on 12/29/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LCPopMenuItem.h"

typedef void(^LCPopMenuEventBlock)(NSInteger index, LCPopMenuItem *menuItem);

@interface LCPopMenu : UIView
- (instancetype)initWithMenus:(NSArray *)menus;

- (instancetype)initWithObjects:(id)firstObj, ... NS_REQUIRES_NIL_TERMINATION;

- (void)showMenuAtPoint:(CGPoint)point;

- (void)showMenuOnView:(UIView *)view atPoint:(CGPoint)point;

@property (nonatomic, copy) LCPopMenuEventBlock popMenuSelected;

@property (nonatomic, copy) LCPopMenuEventBlock popMenuDismissed;
@end
