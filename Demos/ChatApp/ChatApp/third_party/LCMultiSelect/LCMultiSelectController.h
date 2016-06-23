//
//  LCMultiSelectController.h
//  ChatApp
//
//  Created by Qihe Bian on 12/30/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LCMultiSelectItem.h"

@class LCMultiSelectController;
@protocol LCMultiSelectControllerDelegate <NSObject>
@optional
- (void)multiSelectController:(LCMultiSelectController *)controller didSelectItems:(NSArray *)items;
@end

@interface LCMultiSelectController : UIViewController
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, weak) id<LCMultiSelectControllerDelegate> delegate;
@end
