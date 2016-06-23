//
//  NZCircularImageView.m
//  NZCircularImageView
//
//  Created by Bruno Furtado on 10/12/13.
//  Copyright (c) 2013 No Zebra Network. All rights reserved.
//

#import "NZCircularImageView.h"

@interface NZCircularImageView ()

- (void)setImageWithResizeURL:(NSString *)stringUrl
             placeholderImage:(UIImage *)placeholder
                      options:(SDWebImageOptions)options
  usingActivityIndicatorStyle:(UIActivityIndicatorViewStyle)activityStyle;

- (void)addMaskToBounds:(CGRect)bounds;
- (void)setup;

@end



@implementation NZCircularImageView

@synthesize borderWidth = _borderWidth;
@synthesize borderColor = _borderColor;

#pragma mark -
#pragma mark - UIImageView override methods

- (id)init
{
    self = [super init];
    
    if (self) {
        [self setup];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self setup];
    }
    
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        [self setup];
    }
    
    return self;
}

- (id)initWithImage:(UIImage *)image
{
    self = [super initWithImage:image];
    
    if (self) {
        [self setup];
    }
    
    return self;
}

- (void)setBorderWidth:(NSNumber *)borderWidth
{
    _borderWidth    = borderWidth;

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)setBorderColor:(UIColor *)borderColor
{
    _borderColor    = borderColor;

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self addMaskToBounds:self.frame];
}

#pragma mark -
#pragma mark - Public methods

- (void)setImageWithResizeURL:(NSString *)stringUrl
{
    [self setImageWithResizeURL:stringUrl usingActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
}

- (void)setImageWithResizeURL:(NSString *)stringUrl usingActivityIndicatorStyle:(UIActivityIndicatorViewStyle)activityStyle
{
    [self setImageWithResizeURL:stringUrl placeholderImage:nil usingActivityIndicatorStyle:activityStyle];
}

- (void)setImageWithResizeURL:(NSString *)stringUrl placeholderImage:(UIImage *)placeholder usingActivityIndicatorStyle:(UIActivityIndicatorViewStyle)activityStyle
{
    [self setImageWithResizeURL:stringUrl placeholderImage:placeholder options:kNilOptions usingActivityIndicatorStyle:activityStyle];
}

- (void)setImageWithResizeURL:(NSString *)stringUrl placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options usingActivityIndicatorStyle:(UIActivityIndicatorViewStyle)activityStyle
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:stringUrl]];
    
    if (![NSURLConnection canHandleRequest:request]) {
#ifdef NZDEBUG
        NSLog(@"%s\nInvalid url: %@", __PRETTY_FUNCTION__, stringUrl);
#endif
        return;
    }
    
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGFloat width = CGRectGetWidth(self.frame) * scale;
    CGFloat height = CGRectGetHeight(self.frame) * scale;
    
    NSMutableString *mStringUrl = [[NSMutableString alloc] initWithString:stringUrl];
    [mStringUrl appendFormat:@"?width=%.0f", width];
    [mStringUrl appendFormat:@"&height=%.0f", height];
    [mStringUrl appendString:@"&mode=crop"];
    
#ifdef NZDEBUG
    NSLog(@"%s\nDownload image from url: %@", __PRETTY_FUNCTION__, mStringUrl);
#endif
    
    NSURL *url = [NSURL URLWithString:mStringUrl];
    [self setImageWithURL:url placeholderImage:placeholder options:options usingActivityIndicatorStyle:activityStyle];
}

#pragma mark -
#pragma mark - Private methods

- (void)addMaskToBounds:(CGRect)maskBounds
{
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
	
    CGPathRef maskPath = CGPathCreateWithEllipseInRect(maskBounds, NULL);
    maskLayer.bounds = maskBounds;
	maskLayer.path = maskPath;
    maskLayer.fillColor = [UIColor blackColor].CGColor;
    
    CGPoint point = CGPointMake(maskBounds.size.width/2, maskBounds.size.height/2);
    maskLayer.position = point;
    
	[self.layer setMask:maskLayer];

    if ([self.borderWidth integerValue] > 0)
    {
        //
        // And then create the outline layer
        //
        CAShapeLayer*   shape   = [CAShapeLayer layer];
        shape.bounds            = maskBounds;
        shape.path              = maskPath;
        shape.lineWidth         = [self.borderWidth doubleValue] * 2.0f;
        shape.strokeColor       = self.borderColor.CGColor;
        shape.fillColor         = [UIColor clearColor].CGColor;
        shape.position          = point;

        [self.layer addSublayer:shape];
    }

    CGPathRelease(maskPath);
}

- (void)setup
{
    self.contentMode = UIViewContentModeScaleAspectFill;
    self.clipsToBounds = YES;

    self.borderWidth    = @0.0f;
    self.borderColor    = [UIColor whiteColor];
}

@end
