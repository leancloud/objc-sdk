//
//  LCContactCell.m
//  ChatApp
//
//  Created by Qihe Bian on 12/24/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCContactCell.h"

const float kLCContactCellHeight = 44;

@interface LCContactCell ()
@property (nonatomic, strong) UIImageView *separatorLineImageView;
@end

@implementation LCContactCell

- (UIImageView *)separatorLineImageView {
    if (!_separatorLineImageView) {
        UIImage *image = [[self class] separatorLineImage];
        _separatorLineImageView = [[UIImageView alloc] initWithImage:image];
        _separatorLineImageView.frame = CGRectMake(0, kLCContactCellHeight - image.size.height/2, self.frame.size.width, image.size.height/2);
    }
    return _separatorLineImageView;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        //        self.selectedBackgroundView = self.menuSelectedBackgroundView;
        [self.contentView addSubview:self.separatorLineImageView];
        NZCircularImageView *imageView = [[NZCircularImageView alloc] initWithFrame:CGRectMake(5, 5, kLCContactCellHeight - 5*2, kLCContactCellHeight - 5*2)];
        [self.contentView addSubview:imageView];
        self.headView = imageView;
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(kLCContactCellHeight + 5, 7, 200, 30)];
        label.font = [UIFont boldSystemFontOfSize:18];
        [self.contentView addSubview:label];
        self.nameLabel = label;
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
