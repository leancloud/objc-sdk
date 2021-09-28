//
//  LCApplication_Internal.h
//  LeanCloud
//
//  Created by pzheng on 2020/05/29.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

#import "LCApplication.h"

@interface LCApplication ()

@property (nonatomic) NSString *identifier;
@property (nonatomic) NSString *key;

- (NSString *)identifierThrowException;
- (NSString *)keyThrowException;

@end
