//
//  LCContactCell.h
//  ChatApp
//
//  Created by Qihe Bian on 12/24/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCTableViewCell.h"
#import "NZCircularImageView.h"

extern const float kLCContactCellHeight;
//extern const float kLCSeparatorLineImageViewHeight;

@interface LCContactCell : LCTableViewCell
@property (nonatomic, strong)NZCircularImageView *headView;
@property (nonatomic, strong)UILabel *nameLabel;
@end
