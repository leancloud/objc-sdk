//
//  LCMultiSelectItem.h
//  ChatApp
//
//  Created by Qihe Bian on 12/30/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LCMultiSelectItem : NSObject
@property (nonatomic, strong) NSURL *imageURL; //图片地址
@property (nonatomic, copy) NSString *name; //名字
@property (nonatomic, assign) BOOL disabled; //是否不让选择
@property (nonatomic, assign) BOOL selected; //是否已经被选择
@property (nonatomic, strong) NSString *userId;
@end
