//
//  LCConversationCell.m
//  ChatApp
//
//  Created by Qihe Bian on 12/22/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCConversationCell.h"

const float kLCConversationCellHeight = 60;

@interface LCConversationCell ()
@property (nonatomic, strong) UIImageView *separatorLineImageView;
@end

@implementation LCConversationCell

- (UIImageView *)separatorLineImageView {
    if (!_separatorLineImageView) {
        UIImage *image = [[self class] separatorLineImage];
        _separatorLineImageView = [[UIImageView alloc] initWithImage:image];
        _separatorLineImageView.frame = CGRectMake(0, kLCConversationCellHeight - image.size.height/2, self.frame.size.width, image.size.height/2);
    }
    return _separatorLineImageView;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
//        self.selectedBackgroundView = self.menuSelectedBackgroundView;
        [self.contentView addSubview:self.separatorLineImageView];
        NZCircularImageView *imageView = [[NZCircularImageView alloc] initWithFrame:CGRectMake(5, 5, kLCConversationCellHeight - 5*2, kLCConversationCellHeight - 5*2)];
        [self.contentView addSubview:imageView];
        self.headView = imageView;
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(kLCConversationCellHeight, 5, 150, 24)];
        label.backgroundColor = [UIColor clearColor];
        label.font = [UIFont boldSystemFontOfSize:16];
        [self.contentView addSubview:label];
        self.nameLabel = label;
        
        label = [[UILabel alloc] initWithFrame:CGRectMake(kLCConversationCellHeight + 140, 5, 60, 24)];
        label.textColor = [UIColor lightGrayColor];
        label.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:label];
        self.memberCountLabel = label;
        
        label = [[UILabel alloc] initWithFrame:CGRectMake(kLCConversationCellHeight, 30, 200, 24)];
        label.textColor = [UIColor lightGrayColor];
        label.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:label];
        self.messageLabel = label;

        label = [[UILabel alloc] initWithFrame:CGRectMake(220, 5, 90, 20)];
        label.textColor = [UIColor lightGrayColor];
        label.font = [UIFont systemFontOfSize:12];
        label.textAlignment = NSTextAlignmentRight;
        label.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:label];
        self.timeLabel = label;
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.memberCountLabel.text = @"";
    self.messageLabel.text = @"";
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
