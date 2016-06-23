//
//  LCTableViewCell.m
//  ChatApp
//
//  Created by Qihe Bian on 12/24/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCTableViewCell.h"

//const float kLCSeparatorLineImageViewHeight = 0.5;
static UIImage *separatorLineImage = nil;
@interface LCTableViewCell ()
@end

@implementation LCTableViewCell

+ (UIImage *)separatorLineImage {
    if (!separatorLineImage) {
        CGSize size = CGSizeMake(640.0f, 1.0f);
        UIGraphicsBeginImageContext(size);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
//        CGContextSetStrokeColorWithColor(context, [[UIColor blackColor] CGColor]);
        UIColor *color = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:0.500];
        CGContextSetFillColorWithColor(context, [color CGColor]);
        
        CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 640.0f, 1.0f));
//        color = [UIColor colorWithRed:0.468 green:0.519 blue:0.549 alpha:0.000];
//        CGContextSetFillColorWithColor(context, [color CGColor]);
//        CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 640.0f, 1.0f));
        
//        CGContextSetLineWidth(context, 5.0f);
//        CGContextMoveToPoint(context, 100.0f, 100.0f);
//        CGContextAddLineToPoint(context, 150.0f, 150.0f);
//        CGContextStrokePath(context);
        
        UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        separatorLineImage = result;
    }
    return separatorLineImage;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
