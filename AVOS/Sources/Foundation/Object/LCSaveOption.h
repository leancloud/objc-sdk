//
//  LCSaveOption.h
//  LeanCloud
//
//  Created by Tang Tianyong on 1/12/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LCQuery;

NS_ASSUME_NONNULL_BEGIN

@interface LCSaveOption : NSObject

@property (nonatomic, assign) BOOL fetchWhenSave;
@property (nonatomic, strong, nullable) LCQuery *query;

@end

NS_ASSUME_NONNULL_END
