//
//  LCTextField.m
//  LCChatApp
//
//  Created by Qihe Bian on 11/20/14.
//  Copyright (c) 2014 Lean Cloud Inc. All rights reserved.
//

#import "LCTextField.h"

@implementation LCTextField

// placeholder position
- (CGRect)textRectForBounds:(CGRect)bounds {
    return CGRectInset( bounds , _horizontalPadding , _verticalPadding );
}

// text position
- (CGRect)editingRectForBounds:(CGRect)bounds {
    return CGRectInset( bounds , _horizontalPadding , _verticalPadding );
}

@end
