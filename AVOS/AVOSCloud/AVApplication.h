//
//  AVApplication.h
//  AVOS
//
//  Created by pzheng on 2020/05/20.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVApplication : NSObject

@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *key;

+ (instancetype)defaultApplication;

- (void)setWithIdentifier:(NSString *)identifier key:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
