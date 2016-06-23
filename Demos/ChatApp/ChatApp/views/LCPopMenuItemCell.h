//
//  LCPopMenuItemCell.h
//  ChatApp
//
//  Created by Qihe Bian on 12/29/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LCPopMenuItem.h"

@interface LCPopMenuItemCell : UITableViewCell
@property (nonatomic, strong) LCPopMenuItem *popMenuItem;

- (void)setupPopMenuItem:(LCPopMenuItem *)popMenuItem atIndexPath:(NSIndexPath *)indexPath isBottom:(BOOL)isBottom;
@end
