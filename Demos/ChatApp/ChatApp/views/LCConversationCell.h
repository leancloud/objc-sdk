//
//  LCConversationCell.h
//  ChatApp
//
//  Created by Qihe Bian on 12/22/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCTableViewCell.h"
#import "NZCircularImageView.h"

extern const float kLCConversationCellHeight;

@interface LCConversationCell : LCTableViewCell
@property (nonatomic, strong)NZCircularImageView *headView;
@property (nonatomic, strong)UILabel *nameLabel;
@property (nonatomic, strong)UILabel *memberCountLabel;
@property (nonatomic, strong)UILabel *messageLabel;
@property (nonatomic, strong)UILabel *timeLabel;
@end
