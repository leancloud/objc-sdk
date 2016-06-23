//
//  LCMultiSelectCell.m
//  ChatApp
//
//  Created by Qihe Bian on 12/30/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCMultiSelectCell.h"
#import "LCMultiSelectCommon.h"

@interface LCMultiSelectCell()

@property (weak, nonatomic) UIImageView *selectImageView;

@end

@implementation LCMultiSelectCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(7, 12, 30, 30)];
        [self addSubview:imageView];
        self.selectImageView = imageView;
        
        NZCircularImageView *circularImageView = [[NZCircularImageView alloc] initWithFrame:CGRectMake(50, 9, 36, 36)];
        [self addSubview:circularImageView];
        self.cellImageView = circularImageView;
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(94, 18, 206, 18)];
        label.font = [UIFont boldSystemFontOfSize:15];
        [self addSubview:label];
        self.label = label;
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self reset];
}

- (void)reset
{
    self.selectState = LCMultiSelectStateNoSelected;
    self.cellImageView.image = nil;
    self.label.text = @" ";
}

- (void)setSelectState:(LCMultiSelectState)selectState
{
    _selectState = selectState;
    
    switch (selectState) {
        case LCMultiSelectStateNoSelected:
            self.selectImageView.image = [UIImage imageNamed:kSrcName(@"CellNotSelected")];
            break;
        case LCMultiSelectStateSelected:
            self.selectImageView.image = [UIImage imageNamed:kSrcName(@"CellBlueSelected")];
            break;
        case LCMultiSelectStateDisabled:
            self.selectImageView.image = [UIImage imageNamed:kSrcName(@"CellGraySelected")];
            break;
        default:
            break;
    }
}

@end
