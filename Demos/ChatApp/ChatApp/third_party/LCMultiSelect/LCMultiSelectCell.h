//
//  LCMultiSelectCell.h
//  ChatApp
//
//  Created by Qihe Bian on 12/30/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NZCircularImageView.h"

typedef enum : NSUInteger {
    LCMultiSelectStateNoSelected = 0,
    LCMultiSelectStateSelected,
    LCMultiSelectStateDisabled,
} LCMultiSelectState;

@interface LCMultiSelectCell : UITableViewCell
@property (weak, nonatomic) NZCircularImageView *cellImageView;

@property (weak, nonatomic) UILabel *label;

@property (nonatomic, assign) LCMultiSelectState selectState;

@end
