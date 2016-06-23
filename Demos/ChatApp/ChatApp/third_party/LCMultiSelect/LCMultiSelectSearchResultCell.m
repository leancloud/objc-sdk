//
//  LCMultiSelectSearchResultCell.m
//  ChatApp
//
//  Created by Qihe Bian on 12/30/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCMultiSelectSearchResultCell.h"

@implementation LCMultiSelectSearchResultCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 9, 36, 36)];
        [self addSubview:imageView];
        self.cellImageView = imageView;
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(54, 18, 193, 18)];
        label.font = [UIFont boldSystemFontOfSize:15];
        [self addSubview:label];
        self.contentLabel = label;
        
        label = [[UILabel alloc] initWithFrame:CGRectMake(257, 18, 53, 18)];
        label.font = [UIFont boldSystemFontOfSize:15];
        label.textColor = [UIColor lightGrayColor];
        label.hidden = YES;
        label.text = @"已添加";
        [self addSubview:label];
        self.addedTipsLabel = label;
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self reset];
}

- (void)reset
{
    self.contentLabel.textColor = [UIColor blackColor];
    self.cellImageView.image = nil;
    self.contentLabel.text = @" ";
    self.addedTipsLabel.hidden = YES;
}


@end
