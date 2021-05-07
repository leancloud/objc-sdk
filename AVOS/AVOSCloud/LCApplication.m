//
//  LCApplication.m
//  LeanCloud
//
//  Created by pzheng on 2020/05/20.
//  Copyright © 2020 LeanCloud Inc. All rights reserved.
//

#import "LCApplication_Internal.h"

@implementation LCApplication

+ (instancetype)defaultApplication
{
    static LCApplication *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LCApplication alloc] init];
    });
    return instance;
}

- (void)setWithIdentifier:(NSString *)identifier key:(NSString *)key
{
    _identifier = [identifier copy];
    _key = [key copy];
}

- (NSString *)identifierThrowException
{
    if (!self.identifier) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Application identifier not found."];
    }
    return self.identifier;
}

- (NSString *)keyThrowException
{
    if (!self.key) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Application key not found."];
    }
    return self.key;
}

@end
