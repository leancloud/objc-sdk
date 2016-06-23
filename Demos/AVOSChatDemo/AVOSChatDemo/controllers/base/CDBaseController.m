//
//  CDBaseController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/24/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDBaseController.h"

//@interface UIViewController ()
//- (CGRect)_defaultInitialViewFrame;
//@end

@implementation CDBaseController

- (void)loadView {
    CGRect rect;
//    if ([self respondsToSelector:@selector(_defaultInitialViewFrame)]) {
//        rect = self._defaultInitialViewFrame;
//    } else {
        [super loadView];
        rect = self.view.frame;
//    }
    UIScrollView *view = [[UIScrollView alloc] initWithFrame:rect];
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
}
@end
