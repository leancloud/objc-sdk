//
//  CDPopMenuItemCell.h
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/30/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CDPopMenuItem.h"

@interface CDPopMenuItemCell : UITableViewCell
@property (nonatomic, strong) CDPopMenuItem *popMenuItem;

- (void)setupPopMenuItem:(CDPopMenuItem *)popMenuItem atIndexPath:(NSIndexPath *)indexPath isBottom:(BOOL)isBottom;

@end
