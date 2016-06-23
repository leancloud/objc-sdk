//
//  LCMultiSelectedPanel.h
//  ChatApp
//
//  Created by Qihe Bian on 12/30/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class LCMultiSelectedPanel;
@class LCMultiSelectItem;
@protocol LCMultiSelectedPanelDelegate <NSObject>
- (void)willDeleteRowWithItem:(LCMultiSelectItem*)item withMultiSelectedPanel:(LCMultiSelectedPanel*)multiSelectedPanel;
- (void)didConfirmWithMultiSelectedPanel:(LCMultiSelectedPanel*)multiSelectedPanel;
@end

@interface LCMultiSelectedPanel : UIView
@property (nonatomic, strong) NSMutableArray *selectedItems;
@property (nonatomic, weak) id<LCMultiSelectedPanelDelegate> delegate;

//数组有变化之后需要主动激活
- (void)didDeleteSelectedIndex:(NSUInteger)selectedIndex;
- (void)didAddSelectedIndex:(NSUInteger)selectedIndex;
@end
