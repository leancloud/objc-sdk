//
//  KAChatCell.m
//  KeepAlive
//
//  Created by yang chaozhong on 5/22/14.
//  Copyright (c) 2014 avoscloud. All rights reserved.
//

#import "KAChatCell.h"

@implementation KAChatCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (CGSize)sizeThatFits:(CGSize)size;
{
    CGSize textViewSize = _textView.bounds.size;
    CGSize fitTextViewSize = CGSizeMake(textViewSize.width, size.height);
    CGSize sizeThatFitsSize = [self.textView sizeThatFits:fitTextViewSize];
    
    CGSize superSize = [super sizeThatFits:size];
    
    sizeThatFitsSize.height = MAX(superSize.height, sizeThatFitsSize.height);
    sizeThatFitsSize.width = superSize.width;
    
    return sizeThatFitsSize;
}

@end
