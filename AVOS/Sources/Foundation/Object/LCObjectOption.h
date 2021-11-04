//
//  LCObjectOption.h
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

/// Option for fetch-method of LCObject.
@interface LCObjectFetchOption : NSObject

/// Selecting which only key-value will be returned.
/// If the key is prefixed with `-`, means which only key-value will NOT be returned.
@property (nonatomic, nullable) NSArray<NSString *> *selectKeys;
/// Selecting which pointer's all value will be returned.
@property (nonatomic, nullable) NSArray<NSString *> *includeKeys;

@end

NS_ASSUME_NONNULL_END
